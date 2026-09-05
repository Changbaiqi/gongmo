import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 翻牌时钟：显示 HH:mm:ss，数字变化时播放翻牌动效
class FlipClock extends StatelessWidget {
  final String hours;
  final String minutes;
  final String seconds;
  final double digitWidth;
  final double digitHeight;
  final double fontSize;
  final Color? cardColor;
  final Color? textColor;

  /// 显示某个时刻的翻牌时钟
  FlipClock({
    super.key,
    required DateTime time,
    this.digitWidth = 40,
    this.digitHeight = 60,
    this.fontSize = 34,
    this.cardColor,
    this.textColor,
  })  : hours = time.hour.toString().padLeft(2, '0'),
        minutes = time.minute.toString().padLeft(2, '0'),
        seconds = time.second.toString().padLeft(2, '0');

  /// 正向计时显示（支持超过 24 小时）
  FlipClock.elapsed({
    super.key,
    required Duration elapsed,
    this.digitWidth = 40,
    this.digitHeight = 60,
    this.fontSize = 34,
    this.cardColor,
    this.textColor,
  })  : hours = elapsed.inHours.toString().padLeft(2, '0'),
        minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0'),
        seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

  const FlipClock.fromParts({
    super.key,
    required this.hours,
    required this.minutes,
    required this.seconds,
    this.digitWidth = 40,
    this.digitHeight = 60,
    this.fontSize = 34,
    this.cardColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget digit(String d) => FlipDigit(
          digit: d,
          width: digitWidth,
          height: digitHeight,
          fontSize: fontSize,
          cardColor: cardColor,
          textColor: textColor,
        );

    Widget colon() => SizedBox(
          height: digitHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        digit(hours[0]),
        const SizedBox(width: 3),
        digit(hours[1]),
        colon(),
        digit(minutes[0]),
        const SizedBox(width: 3),
        digit(minutes[1]),
        colon(),
        digit(seconds[0]),
        const SizedBox(width: 3),
        digit(seconds[1]),
      ],
    );
  }
}

/// 单个翻牌数字
class FlipDigit extends StatefulWidget {
  final String digit;
  final double width;
  final double height;
  final double fontSize;
  final Color? cardColor;
  final Color? textColor;

  const FlipDigit({
    super.key,
    required this.digit,
    required this.width,
    required this.height,
    required this.fontSize,
    this.cardColor,
    this.textColor,
  });

  @override
  State<FlipDigit> createState() => _FlipDigitState();
}

class _FlipDigitState extends State<FlipDigit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late String _current;
  String _old = '';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _current = widget.digit;
  }

  @override
  void didUpdateWidget(covariant FlipDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.digit != _current) {
      _old = _current;
      _current = widget.digit;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardColor = widget.cardColor ?? cs.surface;
    final textColor = widget.textColor ?? cs.onSurface;
    final lineColor = cs.outlineVariant.withValues(alpha: 0.6);
    final w = widget.width;
    final h = widget.height;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: lineColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
          child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            // 注意：不能用 t>0 判断翻转中——动画第一帧 t 恰为 0，
            // 会被当成静止态而整面显示新数字，造成"闪一下"的观感。
            // 只要新旧值不同且动画未结束，就处于翻转态。
            final animating = _old.isNotEmpty && _old != _current && t < 1.0;
            final p1 =
                Curves.easeIn.transform((t * 2).clamp(0.0, 1.0));
            final p2 = Curves.easeOut
                .transform(((t - 0.5) * 2).clamp(0.0, 1.0));

            return SizedBox(
              width: w,
              height: h,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    child: _half(true, _current, cardColor, textColor),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: _half(
                        false, animating ? _old : _current, cardColor, textColor),
                  ),
                  if (animating && p1 < 1)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: _shade(
                        Transform(
                          alignment: Alignment.bottomCenter,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateX(p1 * math.pi / 2),
                          child: _half(true, _old, cardColor, textColor),
                        ),
                        p1,
                      ),
                    ),
                  if (animating && p2 > 0)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: _shade(
                        Transform(
                          alignment: Alignment.topCenter,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateX((1 - p2) * math.pi / 2),
                          child: _half(false, _current, cardColor, textColor),
                        ),
                        1 - p2,
                      ),
                    ),
                  Positioned(
                    top: h / 2 - 0.5,
                    left: 0,
                    child: Container(width: w, height: 1, color: lineColor),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 半张牌：显示数字的上半部分或下半部分
  Widget _half(bool top, String digit, Color cardColor, Color textColor) {
    final h = widget.height / 2;
    return Container(
      width: widget.width,
      height: h,
      color: cardColor,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: widget.width,
          maxHeight: widget.height,
          alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Center(
              child: Text(
                digit,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 翻动过程中的明暗遮罩
  Widget _shade(Widget child, double progress) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: progress * 0.4),
          ),
        ),
      ],
    );
  }
}
