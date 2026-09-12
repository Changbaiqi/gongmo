// ============================================================
// settings_page.dart（设置模块 · 页面）
// 职责：设置页 UI，按“外观 / 自动记账 / 记账提醒 / GitHub 连接 / 安全 /
//       关于”分组展示配置项，把交互委托给对应的 Controller/Service。
// 关联：SettingsController（GitHub 与自动记账状态）、ThemeController（配色/
//       背景图）、LockController（应用锁）、ReminderService（每日提醒）、
//       KeepAliveService（后台保活）；由 AppRoutes 的 /settings 路由进入。
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../data/services/auto_bookkeeping_service.dart';
import '../../data/services/github_sync_service.dart';
import '../../data/services/keep_alive_service.dart';
import '../../data/services/reminder_service.dart';
import '../lock/lock_controller.dart';
import '../lock/pattern_setup_page.dart';
import 'settings_controller.dart';

/// 设置页：整页为 ListView，每个分组标题与卡片用 [_Entrance] 包装做交错入场动画。
///
/// 无状态页面，全部可变状态存放在各 Controller/Service 中，通过 `Obx` 订阅；
/// 每项配置修改后立即持久化，无需“保存”按钮。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController ctrl = Get.put(SettingsController());
    final ThemeController tc = Get.put(ThemeController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Entrance(index: 0, child: _buildSectionTitle('外观')),
          _Entrance(index: 1, child: _buildAppearanceCard(context, tc)),
          const SizedBox(height: 24),
          _Entrance(index: 2, child: _buildSectionTitle('自动记账')),
          _Entrance(index: 3, child: _AutoAccountingCard(ctrl: ctrl)),
          const SizedBox(height: 24),
          _Entrance(index: 4, child: _buildSectionTitle('截屏记账')),
          _Entrance(index: 5, child: _ScreenshotBookkeepingCard(ctrl: ctrl)),
          const SizedBox(height: 24),
          _Entrance(index: 6, child: _buildSectionTitle('识图记账')),
          _Entrance(index: 7, child: _OcrRecognitionCard(ctrl: ctrl)),
          const SizedBox(height: 24),
          _Entrance(index: 8, child: _buildSectionTitle('记账提醒')),
          _Entrance(index: 9, child: const _ReminderCard()),
          const SizedBox(height: 24),
          _Entrance(index: 10, child: _buildSectionTitle('GitHub 连接')),
          _Entrance(
              index: 11,
              child: Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('仓库地址'),
                  subtitle: Obx(() => Text(
                        ctrl.githubRepoUrl.value.isEmpty
                            ? '未绑定'
                            : ctrl.githubRepoUrl.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showGithubConfig(ctrl),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_sync),
                  title: const Text('同步设置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Get.toNamed('/sync'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded,
                      color: Colors.red.shade600),
                  title: Text('清空所有云端备份',
                      style: TextStyle(
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '危险操作：将永久删除仓库中的全部分备份文件',
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.red.shade400),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: Colors.red),
                  onTap: () => _confirmClearCloudBackups(ctrl),
                ),
              ],
            ),
          )),
          const SizedBox(height: 24),
          _Entrance(index: 12, child: _buildSectionTitle('安全')),
          _Entrance(index: 13, child: _buildSecurityCard(context)),
          const SizedBox(height: 24),
          _Entrance(index: 14, child: _buildSectionTitle('关于')),
          _Entrance(
              index: 15,
              child: Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('版本'),
                  trailing: Text('v1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('开源仓库地址'),
                  subtitle: const Text('github.com/Changbaiqi/gongmo'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse('https://github.com/Changbaiqi/gongmo'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('开源协议'),
                  trailing: const Text('MIT'),
                  onTap: () {},
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  /// 安全分组卡片：应用锁总开关 + 生物识别开关 + 修改图案入口。
  ///
  /// 状态来自 [LockController]（secure storage 持久化）。开启应用锁时：
  /// 未设图案先跳转图案设置页，设置成功后若设备支持生物识别则默认一并开启，
  /// 减少用户二次操作。
  Widget _buildSecurityCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lock = Get.find<LockController>();
    return Card(
      child: Obx(() => Column(
            children: [
              SwitchListTile(
                secondary:
                    Icon(Icons.lock_outline_rounded, color: cs.primary),
                title: const Text('应用锁'),
                subtitle: Text(
                  lock.hasPattern.value
                      ? '启动或回到应用时需验证身份'
                      : '开启前需先设置解锁图案',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
                value: lock.enabled.value,
                onChanged: (v) async {
                  if (v) {
                    if (!lock.hasPattern.value) {
                      final ok =
                          await Get.to(() => const PatternSetupPage());
                      if (ok != true) return;
                    }
                    await lock.setEnabled(true);
                    // 设备支持时默认同时开启指纹解锁
                    if (lock.biometricAvailable.value &&
                        !lock.biometricEnabled.value) {
                      await lock.setBiometricEnabled(true);
                    }
                    Get.snackbar(
                        '已开启应用锁',
                        lock.biometricEnabled.value
                            ? '下次启动或回到应用时可用指纹快速解锁'
                            : '下次启动或回到应用时需解锁');
                  } else {
                    await lock.setEnabled(false);
                  }
                },
              ),
              if (lock.enabled.value && lock.biometricAvailable.value) ...[
                const Divider(height: 1),
                SwitchListTile(
                  secondary:
                      Icon(Icons.fingerprint_rounded, color: cs.primary),
                  title: const Text('指纹/生物识别解锁'),
                  subtitle: Text('使用系统指纹或面容快速解锁',
                      style: TextStyle(
                          fontSize: 11.5,
                          color:
                              cs.onSurfaceVariant.withValues(alpha: 0.8))),
                  value: lock.biometricEnabled.value,
                  onChanged: (v) => lock.setBiometricEnabled(v),
                ),
              ],
              if (lock.hasPattern.value) ...[
                const Divider(height: 1),
                ListTile(
                  leading:
                      Icon(Icons.grid_view_rounded, color: cs.primary),
                  title: const Text('修改解锁图案'),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => Get.to(() => const PatternSetupPage()),
                ),
              ],
            ],
          )),
    );
  }

  /// 清空云端备份：弹出“输入关键字”二次确认框，输入“自愿清空仓库”后才允许执行。
  ///
  /// 对话框内用 `canConfirm` 响应式控制“确认清空”按钮可用性，确认后调用
  /// [SettingsController.clearCloudBackups] 删除仓库中的全部备份文件。
  void _confirmClearCloudBackups(SettingsController ctrl) {
    final confirmCtrl = TextEditingController();
    final canConfirm = false.obs;
    const keyword = '自愿清空仓库';

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('清空所有云端备份'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                '将永久删除仓库中的全部分备份文件（含所有年份的计时与账目备份），删除后无法恢复！',
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: Colors.red.shade700),
              ),
            ),
            const SizedBox(height: 12),
            const Text('如确认执行，请输入「自愿清空仓库」：',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: confirmCtrl,
              autofocus: true,
              onChanged: (v) => canConfirm.value = v.trim() == keyword,
              decoration: const InputDecoration(
                hintText: '自愿清空仓库',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          Obx(() => TextButton(
                onPressed: canConfirm.value
                    ? () {
                        Get.back();
                        ctrl.clearCloudBackups();
                      }
                    : null,
                child: Text('确认清空',
                    style: TextStyle(
                        color:
                            canConfirm.value ? Colors.red.shade600 : null)),
              )),
        ],
      ),
    );
  }

  /// 外观分组卡片：深色模式三选一、8 套主题配色横向选择、自定义背景图。
  /// 所有修改立即写入 config.json 并全局生效（ThemeController 驱动）。
  Widget _buildAppearanceCard(BuildContext context, ThemeController tc) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('深色模式',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _modePill(context, tc, '跟随系统', ThemeMode.system),
                    const SizedBox(width: 8),
                    _modePill(context, tc, '浅色', ThemeMode.light),
                    const SizedBox(width: 8),
                    _modePill(context, tc, '深色', ThemeMode.dark),
                  ],
                ),
                const SizedBox(height: 18),
                Text('主题配色',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    itemCount: AppThemePreset.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) =>
                        _presetTile(context, tc, AppThemePreset.values[index]),
                  ),
                ),
                const SizedBox(height: 18),
                Text('自定义背景',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (tc.hasBackground) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(tc.backgroundPath.value),
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) =>
                              Container(width: 52, height: 52, color:
                                  cs.surfaceContainerHighest),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickBackgroundImage(tc),
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: Text(tc.hasBackground ? '更换背景' : '选择背景图片'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: cs.surface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    if (tc.hasBackground) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          tc.clearBackground();
                          Get.snackbar('已清除', '已恢复默认背景');
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: '清除背景',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tc.hasBackground
                      ? '背景图会铺在所有页面下方，卡片保持不透明'
                      : '从相册选择图片作为应用背景',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                ),
              ],
            )),
      ),
    );
  }

  Widget _modePill(
      BuildContext context, ThemeController tc, String label, ThemeMode mode) {
    final cs = Theme.of(context).colorScheme;
    final selected = tc.mode.value == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => tc.setMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected
                      ? cs.primary
                      : cs.onSurfaceVariant.withValues(alpha: 0.8),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                )),
          ),
        ),
      ),
    );
  }

  /// 单个主题配色方块：展示预设色板 + 名称，选中时放大并高亮描边
  Widget _presetTile(
      BuildContext context, ThemeController tc, AppThemePreset preset) {
    final cs = Theme.of(context).colorScheme;
    final selected = tc.preset.value == preset;
    return GestureDetector(
      onTap: () => tc.setPreset(preset),
      child: AnimatedScale(
        scale: selected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.1)
              : cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.5),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final c in preset.swatches) ...[
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  if (c != preset.swatches.last) const SizedBox(width: 4),
                ],
              ],
            ),
            const SizedBox(height: 7),
            Text(preset.label,
                style: TextStyle(
                  fontSize: 12,
                  color: selected
                      ? cs.primary
                      : cs.onSurfaceVariant.withValues(alpha: 0.8),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
        ),
      ),
    );
  }

  /// 从相册选择背景图并复制到应用私有目录（gongmo_data/background.jpg）。
  ///
  /// 不能直接引用相册返回的临时路径：该路径可能被系统清理或失效，
  /// 所以先压缩（最大宽 1920、质量 85）另存一份固定文件，再交给 ThemeController。
  Future<void> _pickBackgroundImage(ThemeController tc) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;
      final docs = await getApplicationDocumentsDirectory();
      final bgDir = Directory('${docs.path}/gongmo_data');
      if (!await bgDir.exists()) {
        await bgDir.create(recursive: true);
      }
      final dest = File('${bgDir.path}/background.jpg');
      if (await dest.exists()) {
        await dest.delete();
      }
      await picked.saveTo(dest.path);
      tc.setBackgroundImage(dest.path);
      Get.snackbar('已设置', '自定义背景已更新');
    } catch (e) {
      Get.snackbar('设置失败', '选择背景图片失败，请重试');
    }
  }

  /// GitHub 配置对话框：填写仓库地址与 Token，保存后立即调用
  /// `testConnection` 做一次真实校验；Token 仅在本地与请求头中使用，不上传别处。
  void _showGithubConfig(SettingsController ctrl) {
    final urlCtrl = TextEditingController(text: ctrl.githubRepoUrl.value);
    final tokenCtrl = TextEditingController(text: ctrl.githubToken.value);

    Get.dialog(
      AlertDialog(
        title: const Text('GitHub 配置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: '仓库 URL',
                hintText: 'https://github.com/user/repo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tokenCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Personal Access Token',
                hintText: 'ghp_xxxx',
                helperText: '需要 Contents 读写权限',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              TextButton(
                onPressed: () {
                  ctrl.disconnectGithub();
                  Get.back();
                },
                child: const Text('断开连接', style: TextStyle(color: Colors.red)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final url = urlCtrl.text.trim();
                  final token = tokenCtrl.text.trim();
                  if (url.isNotEmpty &&
                      GithubSyncService.normalizeRepo(url) == null) {
                    Get.snackbar('格式错误',
                        '仓库地址不正确，示例：https://github.com/user/repo');
                    return;
                  }
                  if (token.isNotEmpty &&
                      !GithubSyncService.isValidTokenFormat(token)) {
                    Get.snackbar(
                        'Token 格式可疑',
                        'Token 通常以 ghp_ 或 github_pat_ 开头，'
                        '请检查是否复制完整或混入了空格');
                    return;
                  }
                  await ctrl.setGithubRepo(url);
                  await ctrl.setGithubToken(token);
                  Get.back();
                  if (url.isEmpty || token.isEmpty) {
                    Get.snackbar('已保存', 'GitHub 配置已更新');
                    return;
                  }
                  Get.snackbar('正在检测', '正在验证仓库与 Token...',
                      duration: const Duration(seconds: 2));
                  try {
                    await GithubSyncService.instance.testConnection();
                    Get.snackbar('连接成功', '仓库与 Token 验证通过，可以同步了');
                  } on GithubSyncException catch (e) {
                    Get.snackbar('连接失败', e.message);
                  } catch (_) {
                    Get.snackbar('连接失败', '网络异常，请检查网络');
                  }
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 截屏记账卡片：常驻通知菜单开关 + 无障碍服务授权状态
class _ScreenshotBookkeepingCard extends StatefulWidget {
  final SettingsController ctrl;

  const _ScreenshotBookkeepingCard({required this.ctrl});

  @override
  State<_ScreenshotBookkeepingCard> createState() =>
      _ScreenshotBookkeepingCardState();
}

class _ScreenshotBookkeepingCardState
    extends State<_ScreenshotBookkeepingCard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.ctrl.refreshScreenshotMenuStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统无障碍设置返回后刷新授权状态
    if (state == AppLifecycleState.resumed) {
      widget.ctrl.refreshScreenshotMenuStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          Obx(() => SwitchListTile(
                secondary: Icon(
                  Icons.document_scanner_outlined,
                  color: cs.primary,
                ),
                title: const Text('常驻通知菜单',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  widget.ctrl.screenshotMenu.value
                      ? (widget.ctrl.screenshotMenuRunning.value
                          ? '通知栏已常驻，点卡片内「截图记账」按钮截屏'
                          : '通知服务启动中...')
                      : '通知栏常驻卡片，内嵌「截图记账」按钮',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
                value: widget.ctrl.screenshotMenu.value,
                onChanged: (v) => widget.ctrl.setScreenshotMenu(v),
              )),
          Obx(() => AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !widget.ctrl.screenshotMenu.value
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        children: [
                          const Divider(height: 1),
                          ListTile(
                            dense: true,
                            leading: Icon(
                              widget.ctrl.accessibilityEnabled.value
                                  ? Icons.verified_user_outlined
                                  : Icons.key_rounded,
                              size: 20,
                              color: widget.ctrl.accessibilityEnabled.value
                                  ? Colors.green.shade600
                                  : Colors.orange.shade700,
                            ),
                            title: const Text('无障碍服务',
                                style: TextStyle(fontSize: 13.5)),
                            subtitle: Text(
                              widget.ctrl.accessibilityEnabled.value
                                  ? '已开启，可截取当前页面并识别'
                                  : '未开启，点击前往系统设置开启',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.8)),
                            ),
                            trailing:
                                const Icon(Icons.chevron_right, size: 18),
                            onTap: () async {
                              await widget.ctrl.openAccessibilitySettings();
                              if (mounted) {
                                widget.ctrl.refreshScreenshotMenuStatus();
                              }
                            },
                          ),
                          ListTile(
                            dense: true,
                            leading: Icon(Icons.tips_and_updates_outlined,
                                color: cs.primary, size: 20),
                            title: const Text('使用方式',
                                style: TextStyle(fontSize: 13.5)),
                            subtitle: Text(
                              '在支付宝/微信等账单页下拉通知栏，点通知卡片里的'
                              '「截图记账」按钮即截屏识别；识别结果以弹窗确认金额后入账'
                              '（需 Android 11 及以上）',
                              style: TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.8)),
                            ),
                          ),
                        ],
                      ),
              )),
        ],
      ),
    );
  }

}

/// 识图记账卡片：识别方式（本地离线 / AI 视觉）、AI 接口配置、
/// 长按「记一笔」拍照记账开关。识别方式对截屏记账与拍照记账共用。
class _OcrRecognitionCard extends StatelessWidget {
  final SettingsController ctrl;

  const _OcrRecognitionCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('识别方式',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                      Text('截屏与拍照共用；默认本地离线识别',
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant
                                  .withValues(alpha: 0.8))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Obx(() => Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'local',
                        label: Text('本地识别'),
                        icon:
                            Icon(Icons.phone_android_rounded, size: 15)),
                    ButtonSegment(
                        value: 'ai',
                        label: Text('AI 识别'),
                        icon: Icon(Icons.auto_awesome_rounded, size: 15)),
                  ],
                  selected: {ctrl.ocrEngine.value},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => ctrl.setOcrEngine(s.first),
                ),
              )),
          Obx(() {
            if (ctrl.ocrEngine.value != 'ai') {
              return const SizedBox(width: double.infinity);
            }
            final configured = ctrl.aiConfigured;
            return ListTile(
              dense: true,
              leading: Icon(
                configured
                    ? Icons.cloud_done_outlined
                    : Icons.warning_amber_rounded,
                size: 20,
                color: configured
                    ? Colors.green.shade600
                    : Colors.orange.shade700,
              ),
              title: const Text('AI 接口设置',
                  style: TextStyle(fontSize: 13.5)),
              subtitle: Text(
                configured
                    ? '${ctrl.aiApiUrl.value}\n模型：${ctrl.aiApiModel.value.isEmpty ? '默认' : ctrl.aiApiModel.value}'
                    : '未配置 API 地址或 Key，点击填写',
                style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _showAiConfigDialog(context),
            );
          }),
          const Divider(height: 1),
          Obx(() => SwitchListTile(
                secondary: Icon(Icons.add_a_photo_outlined,
                    size: 20, color: cs.primary),
                title: const Text('长按拍照记账',
                    style: TextStyle(fontSize: 13.5)),
                subtitle: Text(
                  '长按记账页右下角 + 按钮，拍照识别账单并自动填入',
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
                value: ctrl.photoBookkeeping.value,
                onChanged: (v) => ctrl.setPhotoBookkeeping(v),
              )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Obx(() => Text(
                  ctrl.ocrEngine.value == 'ai'
                      ? 'AI 识别会把截图/照片发送到你配置的接口服务用于识别，请注意隐私；'
                          '识别结果仍需在确认弹窗中核对后保存。'
                      : '识别在本机通过离线模型完成，不会上传网络；识别结果会先进入确认弹窗，'
                          '核对无误后再保存为账目。',
                  style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                )),
          ),
        ],
      ),
    );
  }

  /// AI 接口配置弹窗：地址 / 模型 / API Key
  void _showAiConfigDialog(BuildContext context) {
    final urlCtrl = TextEditingController(text: ctrl.aiApiUrl.value);
    final modelCtrl = TextEditingController(text: ctrl.aiApiModel.value);
    final keyCtrl = TextEditingController(text: ctrl.aiApiKey.value);
    final obscure = true.obs;

    Get.dialog(AlertDialog(
      title: const Text('AI 接口设置'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: urlCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'API 地址',
                  hintText: 'https://api.deepseek.com（可只填基础地址）',
                  hintStyle: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(
                  labelText: '模型名',
                  hintText: '如 deepseek-v4-flash-vision-exp / qwen-vl-plus',
                  hintStyle: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              Obx(() => TextField(
                    controller: keyCtrl,
                    obscureText: obscure.value,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure.value
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                        onPressed: () => obscure.value = !obscure.value,
                      ),
                    ),
                  )),
              const SizedBox(height: 10),
              Text(
                '支持 OpenAI 兼容的视觉接口（如 DeepSeek、通义千问 VL、智谱 GLM-4V、GPT-4o 等）。'
                '地址可只填基础域名，会自动补全 /v1/chat/completions；'
                'Key 仅保存在本机安全存储中。',
                style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '记账类软件数据为个人敏感数据，推荐接口使用官方接口。'
                        '若使用非官方的中转站接口会有泄露个人信息风险，请谨慎使用。',
                        style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('取消')),
        ElevatedButton(
          onPressed: () async {
            final url = urlCtrl.text.trim();
            if (url.isNotEmpty &&
                !url.startsWith('http://') &&
                !url.startsWith('https://')) {
              Get.snackbar('提示', 'API 地址需以 http:// 或 https:// 开头');
              return;
            }
            await ctrl.saveAiConfig(
              url: url,
              model: modelCtrl.text,
              key: keyCtrl.text,
            );
            Get.back();
            Get.snackbar('已保存', 'AI 接口配置已更新');
          },
          child: const Text('保存'),
        ),
      ],
    ));
  }
}

/// 自动记账卡片：总开关 + 分应用开关（随总开关展开）+ 退款开关 + 权限入口。
///
/// 需要用 StatefulWidget 是因为要监听 App 生命周期：用户去系统设置授予
/// “通知使用权”后返回，需要刷新权限状态并补启动监听服务。
class _AutoAccountingCard extends StatefulWidget {
  final SettingsController ctrl;

  const _AutoAccountingCard({required this.ctrl});

  @override
  State<_AutoAccountingCard> createState() => _AutoAccountingCardState();
}

class _AutoAccountingCardState extends State<_AutoAccountingCard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.ctrl.refreshAutoAccountingStatus();
  }

  @override
  void didUpdateWidget(covariant _AutoAccountingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.ctrl.refreshAutoAccountingStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统设置授权返回后刷新状态；若权限已到手则自动补启动监听服务，
    // 用户无需回到页面再手动拨一次开关
    if (state == AppLifecycleState.resumed) {
      widget.ctrl.refreshAutoAccountingStatus();
      if (widget.ctrl.autoAccounting.value &&
          widget.ctrl.autoAccountingHasPermission.value) {
        AutoBookkeepingService.instance.start();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          Obx(() => SwitchListTile(
                secondary: _PulseIcon(
                  icon: Icons.notifications_active_outlined,
                  color: cs.primary,
                  active: widget.ctrl.autoAccountingRunning.value,
                ),
                title: const Text('自动记账',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  widget.ctrl.autoAccounting.value
                      ? (widget.ctrl.autoAccountingRunning.value
                          ? '监听服务运行中，已自动记录收支'
                          : '监听服务启动中...')
                      : '读取支付宝/招商银行通知，自动入账',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
                value: widget.ctrl.autoAccounting.value,
                onChanged: (v) async {
                  await widget.ctrl.setAutoAccounting(v);
                  // 开启时顺带提示常驻设置（非强制，且已设置过则不再打扰）
                  if (v && mounted) {
                    final ignoring = await KeepAliveService.instance
                        .isIgnoringBatteryOptimizations();
                    if (mounted && !ignoring) showKeepAliveGuide();
                  }
                },
              )),
          Obx(() => AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !widget.ctrl.autoAccounting.value
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        children: [
                          const Divider(height: 1),
                          for (final app
                              in AutoBookkeepingService.supportedApps)
                            SwitchListTile(
                              secondary: Icon(
                                app.key == 'alipay'
                                    ? Icons.currency_yuan_rounded
                                    : app.key == 'wechat'
                                        ? Icons.wechat
                                        : app.key == 'meituan'
                                            ? Icons.delivery_dining_rounded
                                            : Icons.account_balance_rounded,
                                color: cs.primary.withValues(alpha: 0.8),
                                size: 20,
                              ),
                              dense: true,
                              title: Text(app.name,
                                  style: const TextStyle(fontSize: 13.5)),
                              subtitle: Text(
                                switch (app.key) {
                                  'cmb' => '入账/支出短信通知自动入账',
                                  'wechat' => '微信支付/收款通知自动入账',
                                  'meituan' => '美团支付/月付/退款通知自动入账',
                                  _ => '支出/收入通知自动入账',
                                },
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.8)),
                              ),
                              value: widget.ctrl.autoApps[app.key] ?? true,
                              onChanged: (v) =>
                                  widget.ctrl.setAutoApp(app.key, v),
                            ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: Icon(
                                Icons.assignment_return_outlined,
                                color: cs.primary,
                                size: 20),
                            dense: true,
                            title: const Text('自动记录退款',
                                style: TextStyle(fontSize: 13.5)),
                            subtitle: Text('识别到退款通知时自动记为收入',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.8))),
                            value: widget.ctrl.autoRefund.value,
                            onChanged: (v) =>
                                widget.ctrl.setAutoRefund(v),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            dense: true,
                            leading: Icon(Icons.battery_saver_rounded,
                                color: cs.primary, size: 20),
                            title: const Text('后台常驻设置',
                                style: TextStyle(fontSize: 13.5)),
                            subtitle: Text('忽略电池优化 / 自启动，避免后台被清理',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.8))),
                            trailing:
                                const Icon(Icons.chevron_right, size: 18),
                            onTap: showKeepAliveGuide,
                          ),
                        ],
                      ),
              )),
          const Divider(height: 1),
          Obx(() => ListTile(
                dense: true,
                leading: Icon(
                  widget.ctrl.autoAccountingHasPermission.value
                      ? Icons.verified_user_outlined
                      : Icons.key_rounded,
                  size: 20,
                  color: widget.ctrl.autoAccountingHasPermission.value
                      ? Colors.green.shade600
                      : Colors.orange.shade700,
                ),
                title: const Text('通知使用权限',
                    style: TextStyle(fontSize: 13.5)),
                subtitle: Text(
                  widget.ctrl.autoAccountingHasPermission.value
                      ? '已授权'
                      : '未授权，点击前往系统设置开启',
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () async {
                  await NotificationsListener.openPermissionSettings();
                  if (context.mounted) {
                    widget.ctrl.refreshAutoAccountingStatus();
                  }
                },
              )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Text(
              '开启后监听支付宝等通知（如"你有一笔200.00元的支出"）并自动入账，'
              '自动记账的条目会在账目列表中标记为"自动"。'
              '部分手机需在系统设置中允许本应用后台运行。',
              style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 页面元素首次出现时上滑淡入（按 index 交错延迟）
///
/// 通过 `Future.delayed` 让第 N 个元素晚 45ms×N 出现，形成瀑布式入场；
/// index 会被 clamp 到 8，避免长列表末尾元素等待过久。
class _Entrance extends StatefulWidget {
  const _Entrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 45 * widget.index.clamp(0, 8));
    Future.delayed(delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, 0.06),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 图标在 active 时轻微脉冲缩放
class _PulseIcon extends StatefulWidget {
  const _PulseIcon({
    required this.icon,
    required this.color,
    required this.active,
  });

  final IconData icon;
  final Color color;
  final bool active;

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.active && _ctrl.isAnimating) {
      _ctrl.animateBack(0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.18).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Icon(widget.icon, color: widget.color),
    );
  }
}

/// 每日记账提醒卡片：开关（需通知权限）+ 提醒时间选择，状态存在 [ReminderService]。
class _ReminderCard extends StatefulWidget {
  const _ReminderCard();

  @override
  State<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<_ReminderCard> {
  final ReminderService _reminder = ReminderService.instance;
  bool _enabled = false;
  int _hour = ReminderService.defaultHour;
  int _minute = ReminderService.defaultMinute;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _enabled = _reminder.enabled;
    _hour = _reminder.hour;
    _minute = _reminder.minute;
  }

  String get _timeText =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  Future<void> _toggle(bool v) async {
    if (_busy) return; // 防止连点导致重复请求权限/重复排期
    setState(() => _busy = true);
    try {
      if (v) {
        // 开启前必须拿到系统通知权限，否则定时任务无法展示提醒
        final ok = await _reminder.requestPermission();
        if (!ok) {
          Get.snackbar('无法开启', '请在系统设置中允许「工墨」发送通知');
          return;
        }
      }
      await _reminder.setEnabled(v);
      if (mounted) setState(() => _enabled = v);
      Get.snackbar(v ? '已开启记账提醒' : '已关闭记账提醒',
          v ? '每天 $_timeText 提醒你记账' : '将不再发送记账提醒');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (t == null) return;
    await _reminder.setTime(t.hour, t.minute);
    if (!mounted) return;
    setState(() {
      _hour = t.hour;
      _minute = t.minute;
    });
    if (_enabled) {
      Get.snackbar('提醒时间已更新', '每天 $_timeText 提醒你记账');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(Icons.alarm_rounded, color: cs.primary),
            title: const Text('每日记账提醒'),
            subtitle: Text(
              _enabled ? '每天 $_timeText 提醒你记账' : '开启后每天定时提醒记账',
              style: TextStyle(
                  fontSize: 11.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
            ),
            value: _enabled,
            onChanged: _toggle,
          ),
          if (_enabled) ...[
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.schedule_rounded, color: cs.primary),
              title: const Text('提醒时间'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_timeText,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ])),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              onTap: _pickTime,
            ),
          ],
        ],
      ),
    );
  }
}

/// 后台常驻设置指引（非强制）：弹出系统授权与厂商自启动设置的操作步骤
void showKeepAliveGuide() {
  Get.dialog(const _KeepAliveDialog());
}

/// 后台保活指引对话框：展示电池优化授权状态并提供一键跳转。
///
/// 会监听生命周期，从系统设置返回后自动刷新授权状态；
/// 部分 ROM 不弹“忽略电池优化”系统框，则兜底打开电池设置列表让用户手动设置。
class _KeepAliveDialog extends StatefulWidget {
  const _KeepAliveDialog();

  @override
  State<_KeepAliveDialog> createState() => _KeepAliveDialogState();
}

class _KeepAliveDialogState extends State<_KeepAliveDialog>
    with WidgetsBindingObserver {
  bool _ignoring = false;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统设置返回后刷新授权状态
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final v = await KeepAliveService.instance
        .isIgnoringBatteryOptimizations();
    if (mounted) {
      setState(() {
        _ignoring = v;
        _loaded = true;
      });
    }
  }

  Future<void> _request() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await KeepAliveService.instance
        .requestIgnoreBatteryOptimizations();
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Get.snackbar('已忽略电池优化', '应用在后台会更稳定');
    } else {
      Get.snackbar('未能自动设置',
          '部分手机不会弹出系统对话框，已为你打开电池设置，请手动允许「不限制 / 忽略优化」');
      // 兜底：系统对话框被 ROM 拦截时，直接跳到电池优化设置列表
      await KeepAliveService.instance.openBatterySettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.battery_charging_full_rounded, color: cs.primary),
          const SizedBox(width: 8),
          const Text('保持后台运行'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '自动记账依赖通知监听。部分手机在后台会清理应用，'
              '下面的设置为可选，建议开启以免漏记：',
              style: TextStyle(
                  fontSize: 12.5, height: 1.5, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _ignoring
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  size: 16,
                  color: _ignoring
                      ? Colors.green.shade600
                      : Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  _loaded
                      ? (_ignoring ? '电池优化：已忽略（推荐）' : '电池优化：未设置')
                      : '电池优化：检测中...',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _step(cs, '1', '点击「忽略电池优化」，在系统弹窗中选择「允许」'),
            _step(cs, '2', '进入「应用设置」，将省电策略设为「无限制」'),
            _step(cs, '3', '在「自启动管理」中允许「工墨」自启动'),
            _step(cs, '4', '在最近任务界面锁定工墨，避免被一键清理'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('知道了')),
        if (!_ignoring)
          TextButton(
            onPressed: _busy ? null : _request,
            child: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('忽略电池优化'),
          ),
        ElevatedButton(
          onPressed: () async {
            final ok =
                await KeepAliveService.instance.openSystemAppSettings();
            if (!ok && mounted) {
              Get.snackbar('无法打开设置',
                  '请手动进入系统设置 → 应用管理 → 工墨，开启自启动与后台运行');
            }
          },
          child: const Text('打开应用设置'),
        ),
      ],
    );
  }

  Widget _step(ColorScheme cs, String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(n,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cs.primary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12, height: 1.4, color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}