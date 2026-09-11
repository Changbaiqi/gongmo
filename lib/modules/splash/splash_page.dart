import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../core/widgets/sakura_petals.dart';
import '../lock/lock_controller.dart';

/// 开屏页：logo 缩放淡入 + 标题上滑淡入 + 底部进度条，结束后进入解锁页或主页
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

  void _next() {
    if (!mounted) return;
    final lock = Get.find<LockController>();
    if (lock.enabled.value && lock.hasPattern.value) {
      Get.offAllNamed(AppRoutes.lock);
    } else {
      Get.offAllNamed(AppRoutes.dashboard);
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
