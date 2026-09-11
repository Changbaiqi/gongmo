// ============================================================
// sakura_petals.dart（core/widgets · 通用视觉组件）
// 职责：整屏樱花花瓣飘落的背景动画（纯 CustomPainter 绘制，无第三方依赖）。
// 关联：由开屏页在“粉白樱花”主题下启用；不依赖控制器，也不接收触摸事件。
// ============================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 樱花花瓣飘落动画，用作开屏页背景装饰。
/// 纯 CustomPainter 实现，无第三方依赖，开销可忽略。
class SakuraPetals extends StatefulWidget {
  const SakuraPetals({super.key, this.petalCount = 14});

  /// 同时飘落的花瓣数量
  final int petalCount;

  @override
  State<SakuraPetals> createState() => _SakuraPetalsState();
}

/// 单片花瓣的所有随机参数：位置、速度、摇摆、自转、颜色等。
/// 数值在构造时一次性随机生成，之后只随动画进度求值，不再变化。
class _Petal {
  _Petal(math.Random r)
      : x = r.nextDouble(),
        size = 6 + r.nextDouble() * 8,
        speed = 0.6 + r.nextDouble() * 0.8,
        offset = r.nextDouble(),
        swayAmp = 16 + r.nextDouble() * 26,
        swayFreq = 1 + r.nextDouble() * 2,
        phase = r.nextDouble() * math.pi * 2,
        rotSpeed = (r.nextDouble() - 0.5) * 3,
        white = r.nextDouble() < 0.35,
        alpha = 0.55 + r.nextDouble() * 0.35;

  /// 水平起点（0~1 比例）
  final double x;

  /// 花瓣尺寸
  final double size;

  /// 下落速度系数
  final double speed;

  /// 初始进度偏移（错开下落节奏）
  final double offset;

  /// 左右摇摆幅度
  final double swayAmp;

  /// 摇摆频率
  final double swayFreq;

  /// 摇摆与自转的初始相位
  final double phase;

  /// 自转速度
  final double rotSpeed;

  /// 白色花瓣（其余为粉色）
  final bool white;

  /// 不透明度
  final double alpha;
}

/// 动画状态：一个 7 秒循环的控制器驱动全部花瓣，
/// 花瓣参数只在初始化时随机一次，保证每片轨迹稳定不闪烁。
class _SakuraPetalsState extends State<SakuraPetals>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  late final List<_Petal> _petals =
      List.generate(widget.petalCount, (_) => _Petal(math.Random()));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _PetalPainter(
            progress: _c.value,
            petals: _petals,
            pink: cs.primaryContainer,
          ),
        ),
      ),
    );
  }
}

/// 花瓣绘制器：把每片花瓣的进度映射为屏幕坐标、摇摆与旋转后逐个绘制。
class _PetalPainter extends CustomPainter {
  _PetalPainter({
    required this.progress,
    required this.petals,
    required this.pink,
  });

  final double progress;
  final List<_Petal> petals;
  final Color pink;

  final Paint _paint = Paint()..style = PaintingStyle.fill;

  /// 单瓣樱花：尖顶圆底的花瓣轮廓
  static Path _petalPath(double s) {
    return Path()
      ..moveTo(0, -s)
      ..quadraticBezierTo(s * 0.9, -s * 0.5, s * 0.62, s * 0.42)
      ..quadraticBezierTo(s * 0.32, s * 0.95, 0, s)
      ..quadraticBezierTo(-s * 0.32, s * 0.95, -s * 0.62, s * 0.42)
      ..quadraticBezierTo(-s * 0.9, -s * 0.5, 0, -s)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final pt in petals) {
      // 每片花瓣按各自速度推进并取小数部分循环，offset 错开起始时刻
      final t = (progress * pt.speed + pt.offset) % 1.0;
      // 纵向留出 30px 缓冲：从屏幕上方进入、下方离开，避免边缘突然出现/消失
      final y = t * (size.height + 60) - 30;
      final x = pt.x * size.width +
          math.sin(t * pt.swayFreq * 2 * math.pi + pt.phase) * pt.swayAmp;
      final angle = pt.phase + t * pt.rotSpeed * 2 * math.pi;

      _paint.color =
          (pt.white ? Colors.white : pink).withValues(alpha: pt.alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawPath(_petalPath(pt.size), _paint);
      canvas.restore();
    }
  }

  /// 只有动画进度变化才需要重绘；花瓣列表本身不会变
  @override
  bool shouldRepaint(_PetalPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
