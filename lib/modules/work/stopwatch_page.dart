import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/widgets/tap_scale.dart';

/// 秒表：正计时、计次（分段用时）与复位
class StopwatchPage extends StatefulWidget {
  const StopwatchPage({super.key});

  @override
  State<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<StopwatchPage>
    with TickerProviderStateMixin {
  final Stopwatch _sw = Stopwatch();
  Timer? _ticker;
  int _lapSeq = 0;
  final List<(int, Duration)> _laps = []; // (计次 id, 累计用时)

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  bool get _running => _sw.isRunning;
  bool get _hasTime => _sw.elapsed > Duration.zero;

  /// 保持屏幕常亮（失败或测试环境下忽略）
  void _wakelock(bool on) {
    try {
      if (on) {
        WakelockPlus.enable().catchError((_) {});
      } else {
        WakelockPlus.disable().catchError((_) {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    _pop.dispose();
    _wakelock(false);
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    if (_sw.isRunning) {
      _sw.stop();
      _ticker?.cancel();
      _ticker = null;
      _pulse.animateBack(0, duration: const Duration(milliseconds: 260));
      _wakelock(false);
    } else {
      _sw.start();
      _ticker = Timer.periodic(
          const Duration(milliseconds: 30), (_) {
        if (mounted) setState(() {});
      });
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
      _wakelock(true);
    }
    setState(() {});
  }

  void _lap() {
    if (!_sw.isRunning) return;
    HapticFeedback.selectionClick();
    _lapSeq++;
    setState(() => _laps.insert(0, (_lapSeq, _sw.elapsed)));
    _pop.forward(from: 0);
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    _sw.stop();
    _sw.reset();
    _ticker?.cancel();
    _ticker = null;
    _pulse.animateBack(0, duration: const Duration(milliseconds: 260));
    _wakelock(false);
    setState(() => _laps.clear());
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final centis = (d.inMilliseconds ~/ 10) % 100;
    final base = '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}.'
        '${centis.toString().padLeft(2, '0')}';
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$base' : base;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('秒表'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            _buildDial(cs),
            const SizedBox(height: 22),
            _buildButtons(),
            const SizedBox(height: 14),
            Expanded(child: _buildLapList(cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildDial(ColorScheme cs) {
    final elapsed = _sw.elapsed;
    // 当前分钟内秒的进度：0..1
    final progress = (elapsed.inMilliseconds % 60000) / 60000.0;
    final color = _running
        ? cs.primary
        : (_hasTime ? cs.tertiary : cs.primary);

    return Center(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final pulse = _running ? _pulse.value : 0.0;
          return SizedBox(
            width: 272,
            height: 272,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 运行中的呼吸光晕
                Container(
                  width: 232 + 30 * pulse,
                  height: 232 + 30 * pulse,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(
                        alpha: 0.04 + 0.07 * (1 - pulse)),
                  ),
                ),
                CustomPaint(
                  size: const Size(252, 252),
                  painter: _DialPainter(
                    progress: progress,
                    color: color,
                    trackColor:
                        cs.surfaceContainerHighest.withValues(alpha: 0.65),
                    tickColor:
                        cs.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
                ),
                _buildTimeText(cs, color),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeText(ColorScheme cs, Color color) {
    return AnimatedBuilder(
      animation: _pop,
      builder: (context, child) {
        final scale = 1 + 0.07 * math.sin(_pop.value * math.pi);
        return Transform.scale(scale: scale, child: child);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _fmt(_sw.elapsed),
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: a, child: c),
            ),
            child: Text(
              _running ? '计时中' : (_hasTime ? '已暂停' : '就绪'),
              key: ValueKey(_running ? 'run' : (_hasTime ? 'pause' : 'idle')),
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circleButton(
          label: _running ? '计次' : '复位',
          icon: _running ? Icons.flag_rounded : Icons.refresh_rounded,
          color: Theme.of(context).colorScheme.tertiary,
          enabled: _running || _hasTime,
          onTap: _running ? _lap : _reset,
        ),
        const SizedBox(width: 40),
        _circleButton(
          label: _running ? '暂停' : (_hasTime ? '继续' : '开始'),
          icon:
              _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: _running
              ? const Color(0xFFEF5350)
              : const Color(0xFF43A047),
          enabled: true,
          primary: true,
          onTap: _toggle,
        ),
      ],
    );
  }

  Widget _circleButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final size = primary ? 84.0 : 66.0;
    final dark = Color.lerp(color, Colors.black, 0.18)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TapScale(
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, dark],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(scale: a, child: c),
                  ),
                  child: Icon(icon,
                      key: ValueKey(icon),
                      color: Colors.white,
                      size: primary ? 34 : 26),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(label,
              key: ValueKey(label),
              style:
                  TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ),
      ],
    );
  }

  Widget _buildLapList(ColorScheme cs) {
    if (_laps.isEmpty) {
      return Center(
        child: AnimatedOpacity(
          opacity: 1,
          duration: const Duration(milliseconds: 300),
          child: Text(
            '点击「计次」记录分段用时',
            style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _laps.length,
      itemBuilder: (context, i) {
        final (id, total) = _laps[i];
        final prev =
            (i + 1 < _laps.length) ? _laps[i + 1].$2 : Duration.zero;
        final split = total - prev;
        final index = _laps.length - i;
        final newest = i == 0;
        return _LapEntrance(
          key: ValueKey(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: newest
                  ? cs.primary.withValues(alpha: 0.09)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text('计次 $index',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              newest ? FontWeight.w600 : FontWeight.normal,
                          color: newest ? cs.primary : cs.onSurfaceVariant)),
                ),
                Expanded(
                  child: Text('+${_fmt(split)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: newest ? cs.primary : cs.onSurface,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ])),
                ),
                SizedBox(
                  width: 100,
                  child: Text(_fmt(total),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ])),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 表盘：刻度 + 轨道 + 当前分钟进度弧 + 端点光点
class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.tickColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 14;

    // 秒刻度（每 5 秒加长）
    for (var i = 0; i < 60; i++) {
      final major = i % 5 == 0;
      final a = i / 60 * 2 * math.pi - math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      final p = Paint()
        ..color = tickColor.withValues(alpha: major ? 0.9 : 0.45)
        ..strokeWidth = major ? 2 : 1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          center + dir * (radius + 6),
          center + dir * (radius + 6 + (major ? 7 : 3.5)),
          p);
    }

    // 轨道
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = trackColor,
    );

    // 进度弧
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        progress * 2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
      final a = -math.pi / 2 + progress * 2 * math.pi;
      final dot = center + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.drawCircle(dot, 7, Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawCircle(dot, 3.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.tickColor != tickColor;
}

/// 计次条目入场：自上滑入 + 淡入
class _LapEntrance extends StatefulWidget {
  const _LapEntrance({super.key, required this.child});

  final Widget child;

  @override
  State<_LapEntrance> createState() => _LapEntranceState();
}

class _LapEntranceState extends State<_LapEntrance> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, -0.35),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        child: widget.child,
      ),
    );
  }
}
