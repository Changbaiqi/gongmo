// ============================================================
// splash_page.dart（启动模块 · 开屏页）
// 职责：启动后的第一个页面，播放 logo 缩放淡入/标题上滑/进度条动画，
//       约 1.8 秒后按“应用锁是否启用”分流到解锁页或主页。
// 关联：读取 LockController 决定跳转目标，读取 ThemeController 决定是否显示
//       樱花飘落；路由走 AppRoutes 的 lock / dashboard。
// ============================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/widgets/sakura_petals.dart';
import '../../data/services/screenshot_menu_service.dart';
import '../lock/lock_controller.dart';
import '../ocr/ocr_confirm_dialog.dart';

/// 开屏页：logo 缩放淡入 + 标题上滑淡入 + 底部进度条，结束后进入解锁页或主页
///
/// 动画用一个 1.6s 的 AnimationController 驱动，各元素通过 Interval 错开
/// 时间片；跳转用 [Timer] 独立计时，动画时长与停留时长互不影响。
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1800), _next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  /// 开屏结束后的分流：启用应用锁且已设置图案才进解锁页，否则直接进主页
  /// （若存在待识别的截屏账单，则直接进入确认页）。
  /// 用 offAllNamed 清空路由栈，避免用户返回时又看到开屏页。
  Future<void> _next() async {
    if (!mounted) return;
    final lock = Get.find<LockController>();
    if (lock.enabled.value && lock.hasPattern.value) {
      Get.offAllNamed(AppRoutes.lock);
      return;
    }
    final capture =
        await ScreenshotMenuService.instance.consumePendingCapture();
    if (!mounted) return;
    Get.offAllNamed(AppRoutes.dashboard);
    if (capture != null) {
      // 主页完成首帧后再弹出确认弹窗，避免与路由切换冲突
      WidgetsBinding.instance.addPostFrameCallback((_) {
        OcrConfirmDialog.show(capture);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final logoFade = CurvedAnimation(
        parent: _c, curve: const Interval(0, 0.4, curve: Curves.easeOut));
    final titleFade = CurvedAnimation(
        parent: _c, curve: const Interval(0.35, 0.65, curve: Curves.easeOut));
    final titleSlide = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.35, 0.7, curve: Curves.easeOutCubic));
    final tagFade = CurvedAnimation(
        parent: _c, curve: const Interval(0.55, 0.9, curve: Curves.easeOut));
    final barAnim = CurvedAnimation(
        parent: _c, curve: const Interval(0.1, 0.95, curve: Curves.easeInOut));

    // 仅粉白（樱花）主题下显示花瓣飘落，其余主题保持原样
    final showPetals =
        Get.find<ThemeController>().preset.value == AppThemePreset.sakura;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          if (showPetals) const Positioned.fill(child: SakuraPetals()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      // 扩散光晕
                      Container(
                        width: 120 + 80 * _c.value,
                        height: 120 + 80 * _c.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary
                              .withValues(alpha: 0.07 * (1 - _c.value)),
                        ),
                      ),
                      FadeTransition(
                        opacity: logoFade,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.7, end: 1).animate(
                            CurvedAnimation(
                              parent: _c,
                              curve: const Interval(0, 0.55,
                                  curve: Curves.easeOutBack),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 104,
                              height: 104,
                              cacheWidth: 208,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: titleFade,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(titleSlide),
                    child: const Text(
                      '工墨',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: tagFade,
                  child: Text(
                    '记录时间 · 管理收支',
                    style: TextStyle(
                        fontSize: 12.5,
                        letterSpacing: 2,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(72, 0, 72, 56),
        child: AnimatedBuilder(
          animation: barAnim,
          builder: (context, _) => ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: barAnim.value,
              minHeight: 3,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
        ),
      ),
    );
  }
}
