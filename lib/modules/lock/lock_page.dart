// ============================================================
// lock_page.dart（锁屏模块 · 解锁页）
// 职责：应用锁的解锁界面——绘制图案验证或使用指纹；解锁成功后返回原页面
//       或进入主页；拦截返回键避免绕过锁屏。
// 关联：LockController（校验图案/生物识别、markUnlocked）；由启动分流或
//       前后台切换时的重锁逻辑进入，路由为 AppRoutes.lock。
// ============================================================
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/widgets/pattern_lock.dart';
import '../../data/services/screenshot_menu_service.dart';
import '../ocr/ocr_confirm_dialog.dart';
import '../ocr/photo_bookkeeping.dart';
import 'lock_controller.dart';

/// 应用解锁页：图案密码或指纹验证。
///
/// 本地状态只有错误提示、指纹忙碌标记与已解锁标记；真正的校验逻辑都在
/// [LockController]，页面只负责展示与导航。
class LockPage extends StatefulWidget {
  const LockPage({super.key});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  final LockController _ctrl = Get.find<LockController>();

  bool _error = false;
  String _message = '';
  bool _biometricBusy = false;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    // 稍作延迟，等 Activity 完全就绪后再唤起指纹（部分机型过早调用会失败）
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _tryBiometric();
    });
  }

  /// 尝试生物识别解锁：未开启或无进行中任务时才调起；
  /// 失败时把 [LockController.biometricError] 显示在图案下方（如指纹被锁定）。
  Future<void> _tryBiometric() async {
    if (_unlocked || _biometricBusy) return;
    if (!_ctrl.biometricEnabled.value) return;
    setState(() => _biometricBusy = true);
    final ok = await _ctrl.authenticateBiometric();
    if (!mounted) return;
    setState(() {
      _biometricBusy = false;
      if (!ok && _ctrl.biometricError.value.isNotEmpty) {
        _error = true;
        _message = _ctrl.biometricError.value;
      }
    });
    if (ok) _unlock();
  }

  Future<void> _unlock() async {
    if (_unlocked) return;
    _unlocked = true;
    _ctrl.markUnlocked();
    // 解锁前不读取截图，避免锁定期间泄露屏幕内容
    final capture =
        await ScreenshotMenuService.instance.consumePendingCapture();
    final menuAction =
        await ScreenshotMenuService.instance.consumeMenuAction();
    if (!mounted) return;
    // 若是从后台返回时弹出的锁屏，直接返回原页面；冷启动则进入主页
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      Get.offAllNamed(AppRoutes.dashboard);
    }
    if (capture != null) {
      // 页面就绪后再弹出确认弹窗
      WidgetsBinding.instance.addPostFrameCallback((_) {
        OcrConfirmDialog.show(capture);
      });
    }
    if (menuAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        runMenuAction(menuAction);
      });
    }
  }

  /// 图案绘制完成后的校验：少于 4 点直接提示；校验通过解锁，失败抖动提示
  Future<void> _onPattern(List<int> pattern) async {
    if (_unlocked) return;
    if (pattern.length < 4) {
      setState(() {
        _error = true;
        _message = '请至少连接 4 个点';
      });
      return;
    }
    final ok = await _ctrl.verifyPattern(pattern);
    if (!mounted) return;
    if (ok) {
      _unlock();
    } else {
      setState(() {
        _error = true;
        _message = '图案不正确，请重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false, // 禁用返回键/返回手势，防止绕过锁屏
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 88,
                      height: 88,
                      cacheWidth: 176,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('工墨已锁定',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('绘制解锁图案以继续',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.8))),
                  const SizedBox(height: 28),
                  PatternLock(
                    size: 260,
                    error: _error,
                    onChanged: (p) {
                      if (_error && p.isNotEmpty) {
                        setState(() {
                          _error = false;
                          _message = '';
                        });
                      }
                    },
                    onCompleted: _onPattern,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 22,
                    child: AnimatedOpacity(
                      opacity: _message.isEmpty ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _message,
                        style: TextStyle(fontSize: 12.5, color: cs.error),
                      ),
                    ),
                  ),
                  if (_ctrl.biometricEnabled.value) ...[
                    const SizedBox(height: 18),
                    TextButton.icon(
                      onPressed: _biometricBusy ? null : _tryBiometric,
                      icon: _biometricBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fingerprint_rounded),
                      label: const Text('使用指纹解锁'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
