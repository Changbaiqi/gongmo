import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/widgets/flip_clock.dart';
import '../work_controller.dart';

/// 横向全屏沉浸式计时牌
/// - 点击页面显示/隐藏控制层（类似视频播放器）
/// - 控制层：左上角退出按钮；底部暂停/结束/屏幕常亮开关
/// - 结束需二次确认，确认后结束计时并退出全屏
class FullscreenTimerPage extends StatefulWidget {
  const FullscreenTimerPage({super.key});

  @override
  State<FullscreenTimerPage> createState() => _FullscreenTimerPageState();
}

class _FullscreenTimerPageState extends State<FullscreenTimerPage> {
  final WorkController _ctrl = Get.find<WorkController>();
  bool _controlsVisible = true;
  bool _keepAwake = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.enable();
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    HapticFeedback.selectionClick();
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Obx(() {
                final paused = _ctrl.isPaused.value;
                return Opacity(
                  opacity: paused ? 0.45 : 1,
                  child: FlipClock.elapsed(
                    elapsed: Duration(seconds: _ctrl.elapsedSeconds.value),
                    digitWidth: 76,
                    digitHeight: 108,
                    fontSize: 66,
                    cardColor: const Color(0xFF1C1C1E),
                    textColor: Colors.white,
                  ),
                );
              }),
            ),
            if (_controlsVisible) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white70),
                        onPressed: () => Get.back(),
                      ),
                      const Text('计时中',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(() {
                        final tag = _ctrl.currentTimerTag.value;
                        return Text(
                          tag?.name ?? '计时中',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12),
                        );
                      }),
                      const SizedBox(height: 10),
                      Obx(() {
                        final paused = _ctrl.isPaused.value;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _fsButton(
                              icon: paused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              label: paused ? '继续' : '暂停',
                              onTap: () => paused
                                  ? _ctrl.resumeTimer()
                                  : _ctrl.pauseTimer(),
                            ),
                            const SizedBox(width: 24),
                            _fsButton(
                              icon: Icons.stop_rounded,
                              label: '结束',
                              color: Colors.red.shade900.withValues(alpha: 0.9),
                              onTap: _confirmStop,
                            ),
                            const SizedBox(width: 24),
                            _fsButton(
                              icon: Icons.bolt_rounded,
                              label: _keepAwake ? '常亮开' : '常亮关',
                              color: _keepAwake
                                  ? Colors.amber.shade800
                                      .withValues(alpha: 0.9)
                                  : const Color(0xFF262626),
                              onTap: _toggleKeepAwake,
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fsButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF262626),
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, size: 24, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  void _toggleKeepAwake() {
    setState(() => _keepAwake = !_keepAwake);
    if (_keepAwake) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  void _confirmStop() {
    Get.dialog(
      AlertDialog(
        title: const Text('结束计时'),
        content: const Text('确定结束本次计时吗？结束后将退出全屏。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Get.back(); // 关闭确认框
              Get.back(); // 退出全屏
              _ctrl.stopTimer();
            },
            child: const Text('确认结束', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
