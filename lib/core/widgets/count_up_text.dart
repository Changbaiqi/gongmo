// ============================================================
// 数字滚动文本组件（core/widgets）
// 职责：金额等数字变化时播放 0→目标值（或当前值→目标值）的滚动动画
// 关联：结余卡、统计汇总卡等
// ============================================================

import 'package:flutter/material.dart';

/// 数字滚动动效文本：数值变化时从当前值平滑过渡；
/// [restartKey] 变化时（如切回页面）从 0 重新滚动，形成加载动效
class CountUpText extends StatefulWidget {
  final double value;
  final int restartKey;
  final TextStyle style;
  final Duration duration;
  final String Function(double value) formatter;
  final int? maxLines;
  final TextOverflow? overflow;

  const CountUpText({
    super.key,
    required this.value,
    required this.formatter,
    this.restartKey = 0,
    this.style = const TextStyle(),
    this.duration = const Duration(milliseconds: 650),
    this.maxLines,
    this.overflow,
  });

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _anim =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  late Tween<double> _tween = Tween(begin: 0, end: widget.value);
  double _current = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  /// 值变化时以“当前显示值”为起点继续滚动；
  /// restartKey 变化（如切回页面）则从 0 重播加载动画
  @override
  void didUpdateWidget(covariant CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restartKey != widget.restartKey) {
      // 切回页面：从 0 重新滚动
      _tween = Tween(begin: 0, end: widget.value);
      _current = 0;
      _ctrl.forward(from: 0);
    } else if (oldWidget.value != widget.value) {
      // 页面内数据变化：从当前显示值过渡
      _tween = Tween(begin: _current, end: widget.value);
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
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        _current = _tween.begin! +
            (_tween.end! - _tween.begin!) * _anim.value;
        return Text(
          widget.formatter(_current),
          style: widget.style,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        );
      },
    );
  }
}
