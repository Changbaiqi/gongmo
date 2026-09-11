import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/date_utils.dart';
import '../../data/models/finance_entry.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/services/ocr_ai_service.dart';
import '../../data/services/ocr_bill_parser.dart';
import '../../data/services/ocr_bookkeeping_service.dart';
import '../../data/services/screenshot_menu_service.dart';
import '../../data/services/storage_service.dart';
import '../dashboard/dashboard_controller.dart';
import '../finance/finance_controller.dart';
import '../finance/widgets/category_manager.dart';

/// 截屏记账确认弹窗：
/// 展示截图与 ML Kit 离线识别结果（金额/收支/商户），用户核对修改后入账。
/// 以「截图作全屏背景的透明浮层」呈现，视觉上就像在账单页上直接弹窗；
/// 关闭后会尝试切回触发截屏前的应用（若截屏时工墨在本后台）。
class OcrConfirmDialog extends StatefulWidget {
  final PendingCapture capture;

  const OcrConfirmDialog({super.key, required this.capture});

  static bool _showing = false;

  static bool get isShowing => _showing;

  /// 打开确认浮层（同一时间只允许一个）
  static void show(PendingCapture capture) {
    if (_showing) return;
    _showing = true;
    Get.to(
      () => OcrConfirmDialog(capture: capture),
      opaque: false,
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 200),
    );
    // 关闭时在 dispose 中复位 _showing，避免 Get.to 返回值为空导致漏复位
  }

  @override
  State<OcrConfirmDialog> createState() => _OcrConfirmDialogState();
}

class _OcrConfirmDialogState extends State<OcrConfirmDialog> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _financeRepo = FinanceRepository();

  String? _imagePath;
  String? _fatalError;
  String? _ocrError;
  String _rawText = '';

  bool _recognizing = true;
  bool _saving = false;
  bool _closing = false;
  bool _cleaned = false;

  FinanceType _type = FinanceType.expense;
  String _categoryId = '';
  DateTime _date = DateTime.now();

  /// 本次识别所用引擎（用于标题旁展示）
  String _engineLabel = '本地识别';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    OcrConfirmDialog._showing = false;
    _cleanup();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  /// 分类选择网格：与「记一笔」共用 [CategoryGridPicker] 和同一份分类数据，
  /// 支持在弹窗内直接进入分类管理新增/编辑，保证与记账功能实时同步。
  Widget _buildCategoryPicker(ColorScheme cs) {
    final fc = Get.isRegistered<FinanceController>()
        ? Get.find<FinanceController>()
        : Get.put(FinanceController());
    return CategoryGridPicker(
      fc: fc,
      cs: cs,
      type: _type,
      getSelectedId: () => _categoryId,
      onSelected: (id) => setState(() {
        _categoryId = id.isEmpty ? _defaultCategoryId(_type) : id;
      }),
    );
  }

  Future<void> _init() async {
    final capture = widget.capture;
    if (!capture.hasImage) {
      setState(() {
        _recognizing = false;
        _fatalError = capture.error == 'accessibility_disabled'
            ? '尚未开启「截屏记账」的无障碍服务'
            : '截屏失败，请返回账单页面后重试';
      });
      return;
    }

    setState(() => _imagePath = capture.path);

    // 识别方式：AI（已启用时）→ 失败自动回退本地离线识别
    var aiFallback = '';
    if (StorageService().getConfig('ocr_engine') == 'ai') {
      try {
        final result = await OcrAiService.instance.recognize(
          imagePath: capture.path!,
          categories: StorageService().categories,
        );
        if (!mounted) return;
        setState(() {
          _recognizing = false;
          _engineLabel = 'AI 识别';
          _rawText = result.rawText;
          _type = result.type;
          if (result.amount != null) {
            _amountCtrl.text = _formatAmountText(result.amount!);
          }
          _descCtrl.text = _joinDescription(result.merchant, result.note);
          _categoryId = result.categoryId ?? _defaultCategoryId(_type);
          if (result.date != null) _date = result.date!;
        });
        return;
      } on AiOcrException catch (e) {
        aiFallback = 'AI 识别失败：${e.message}，已改用本地识别';
      } catch (_) {
        aiFallback = 'AI 识别失败，已改用本地识别';
      }
      if (!mounted) return;
    }

    try {
      final text =
          await OcrBookkeepingService.instance.recognizeImage(capture.path!);
      if (!mounted) return;
      final parsed = OcrBillParser.parse(text);
      setState(() {
        _rawText = text;
        _recognizing = false;
        _engineLabel = '本地识别';
        _ocrError = aiFallback.isEmpty ? null : aiFallback;
        _type = parsed.type ?? FinanceType.expense;
        if (parsed.amount != null) {
          _amountCtrl.text = _formatAmountText(parsed.amount!);
        }
        if (parsed.merchant != null && parsed.merchant!.isNotEmpty) {
          _descCtrl.text = parsed.merchant!;
        }
        _categoryId = _defaultCategoryId(_type);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recognizing = false;
        _engineLabel = '本地识别';
        _ocrError = aiFallback.isEmpty
            ? '文字识别失败，请手动填写金额'
            : '$aiFallback；本地识别也失败，请手动填写';
        _categoryId = _defaultCategoryId(_type);
      });
    }
  }

  /// 商户 + 备注合并到“商户 / 备注”输入框
  String _joinDescription(String? merchant, String? note) {
    final parts = <String>[];
    final m = merchant?.trim() ?? '';
    final n = note?.trim() ?? '';
    if (m.isNotEmpty) parts.add(m);
    if (n.isNotEmpty && n != m) parts.add(n);
    return parts.join(' · ');
  }

  String _defaultCategoryId(FinanceType type) {
    final list =
        StorageService().categories.where((c) => c.type == type).toList();
    if (list.isNotEmpty) return list.first.id;
    return type == FinanceType.income ? 'inc_3' : 'exp_5';
  }

  String _formatAmountText(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _switchType(FinanceType type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _categoryId = _defaultCategoryId(type);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day, _date.hour,
          _date.minute);
    });
  }

  Future<void> _cleanup() async {
    if (_cleaned) return;
    _cleaned = true;
    final path = _imagePath;
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    // 原生通道异常时不阻塞流程
    try {
      await ScreenshotMenuService.instance
          .clearPendingCapture()
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      Get.snackbar('提示', '请输入有效金额');
      return;
    }
    setState(() => _saving = true);
    try {
      final entry = FinanceEntry(
        id: const Uuid().v4(),
        type: _type,
        amount: amount,
        categoryId: _categoryId,
        description: _descCtrl.text.trim(),
        date: _date,
        notificationSrc: 'screenshot',
      );
      _financeRepo.save(entry);
      // 先刷新页面数据（即使随后切回原应用，回来时数据也是新的）
      try {
        Get.find<FinanceController>().loadEntries();
      } catch (_) {}
      try {
        Get.find<DashboardController>(tag: 'dashboard').refreshData();
      } catch (_) {}
      await _close(amount: amount);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 关闭浮层；截屏触发且工墨原在后台时会切回原应用（拍照触发不切换）
  Future<void> _close({double? amount, bool autoReturn = true}) async {
    if (_closing) return;
    _closing = true;
    final shouldReturn =
        autoReturn && _imagePath != null && !widget.capture.fromCamera;
    Get.back(); // 关闭浮层
    var returned = false;
    if (shouldReturn) {
      returned = await ScreenshotMenuService.instance.returnToPreviousApp();
    }
    // 已切回原应用时不再提示；留在工墨内则给出反馈
    if (amount != null && !returned) {
      final label = _type == FinanceType.income ? '收入' : '支出';
      Get.snackbar('已记账', '$label ¥${amount.toStringAsFixed(2)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 截屏时用截图作全屏背景（视觉上停留在原页面）；
            // 拍照时用深色遮罩，卡片内展示照片预览
            if (_imagePath != null && !widget.capture.fromCamera)
              Image.file(
                File(_imagePath!),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF1A1A1A)),
              )
            else
              const ColoredBox(color: Color(0xCC000000)),
            Container(color: Colors.black.withValues(alpha: 0.55)),
            SafeArea(
              child: Center(
                child: Dialog(
                  insetPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 24),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 480, maxHeight: 640),
                    child: _fatalError != null
                        ? _buildFatalError(cs)
                        : _buildContent(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFatalError(ColorScheme cs) {
    final needAccessibility = _fatalError!.contains('无障碍');
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 52, color: cs.error),
          const SizedBox(height: 14),
          Text(
            _fatalError!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          if (needAccessibility)
            FilledButton.icon(
              icon: const Icon(Icons.settings_accessibility_rounded),
              label: const Text('去开启无障碍服务'),
              onPressed: () async {
                await _close();
                await ScreenshotMenuService.instance
                    .openAccessibilitySettings();
              },
            ),
          const SizedBox(height: 6),
          TextButton(onPressed: () => _close(), child: const Text('取消')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题栏
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 8, 4),
          child: Row(
            children: [
              Icon(Icons.document_scanner_outlined,
                  size: 20, color: cs.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('确认账单',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _recognizing ? '识别中' : _engineLabel,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: cs.primary),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _close(),
                icon: const Icon(Icons.close_rounded, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPreview(cs),
                const SizedBox(height: 14),
                if (_ocrError != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 17, color: cs.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _ocrError!,
                            style: TextStyle(
                                fontSize: 12, color: cs.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _buildTypeToggle(cs),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
                  autofocus: _ocrError != null,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: '金额',
                    prefixText: '¥ ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Text('分类',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                _buildCategoryPicker(cs),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  decoration: InputDecoration(
                    labelText: '商户 / 备注',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.event_outlined, size: 20),
                    title: const Text('日期', style: TextStyle(fontSize: 13.5)),
                    subtitle: Text(
                      '${DateHelper.formatDate(_date)} ${DateHelper.formatTime(_date)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: _pickDate,
                  ),
                ),
                if (_rawText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Card(
                    margin: EdgeInsets.zero,
                    child: ExpansionTile(
                      tilePadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      leading: const Icon(Icons.text_snippet_outlined,
                          size: 20),
                      title: const Text('识别原文',
                          style: TextStyle(fontSize: 13.5)),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: SelectableText(
                            _rawText,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: cs.onSurfaceVariant,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_rounded),
                  label: const Text('保存入账'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46)),
                ),
                const SizedBox(height: 8),
                Text(
                  '识别结果由本地模型生成，请核对后保存；截图仅在本机处理，不会上传。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10.5,
                      height: 1.5,
                      color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(ColorScheme cs) {
    final path = _imagePath;
    if (path == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.file(
            File(path),
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 100,
              color: cs.surfaceContainerHighest,
              alignment: Alignment.center,
              child: const Text('截图预览不可用'),
            ),
          ),
          if (_recognizing)
            Container(
              height: 150,
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.45),
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  ),
                  SizedBox(height: 10),
                  Text('正在识别账单...',
                      style: TextStyle(color: Colors.white, fontSize: 12.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle(ColorScheme cs) {
    Widget pill(String label, FinanceType type, Color color) {
      final active = _type == type;
      return Expanded(
        child: GestureDetector(
          onTap: () => _switchType(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color:
                  active ? color.withValues(alpha: 0.13) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? color : cs.outlineVariant,
                width: active ? 1.6 : 1,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? color : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill('支出', FinanceType.expense, const Color(0xFFE53935)),
        const SizedBox(width: 10),
        pill('收入', FinanceType.income, const Color(0xFF43A047)),
      ],
    );
  }
}
