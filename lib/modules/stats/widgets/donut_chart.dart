import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../stats_controller.dart';

class DonutChart extends StatefulWidget {
  final List<CategorySlice> slices;
  final double total;
  final String centerLabel;

  /// 自定义数值格式化（默认人民币金额），用于时长等场景
  final String Function(double amount)? formatAmount;

  const DonutChart({
    super.key,
    required this.slices,
    required this.total,
    this.centerLabel = '总支出',
    this.formatAmount,
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _reveal.forward();
  }

  @override
  void didUpdateWidget(covariant DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slices != widget.slices || oldWidget.total != widget.total) {
      _reveal.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      widget.formatAmount?.call(v) ?? '¥${_formatAmount(v)}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final slices = widget.slices;
    final total = widget.total;
    return Column(
      children: [
        SizedBox(
          width: 170,
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(170, 170),
                painter: _DonutPainter(
                  slices: slices,
                  total: total,
                  reveal: _reveal,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.centerLabel,
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
                  const SizedBox(height: 2),
                  Text(
                    _fmt(total),
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...slices.take(6).map((s) {
          final pct = total > 0 ? s.amount / total * 100 : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: s.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(s.name,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                  '${_fmt(s.amount)}  ${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          );
        }),
        if (slices.length > 6)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '其余 ${slices.length - 6} 个分类合计 ${_fmt(_restAmount(slices))}',
              style: TextStyle(
                  fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
            ),
          ),
      ],
    );
  }

  double _restAmount(List<CategorySlice> slices) {
    var sum = 0.0;
    for (var i = 6; i < slices.length; i++) {
      sum += slices[i].amount;
    }
    return sum;
  }

  String _formatAmount(double v) {
    if (v.abs() >= 10000) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}

class _DonutPainter extends CustomPainter {
  final List<CategorySlice> slices;
  final double total;
  final Animation<double> reveal;

  _DonutPainter({
    required this.slices,
    required this.total,
    required this.reveal,
  }) : super(repaint: reveal);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 24.0;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height)
        .deflate(stroke / 2 + 4);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    if (total <= 0 || slices.isEmpty) {
      paint.color = const Color(0xFFE0E0E0);
      canvas.drawCircle(size.center(Offset.zero), rect.width / 2, paint);
      return;
    }

    // 按进度从起始角顺时针逐渐展开
    final revealAngle = reveal.value * 2 * math.pi;
    var start = -math.pi / 2;
    var consumed = 0.0;
    final gap = slices.length > 1 ? 0.02 : 0.0;
    for (final s in slices) {
      final full = s.amount / total * 2 * math.pi;
      final segSweep = math.max(0.01, full - gap);
      final visible = (revealAngle - consumed).clamp(0.0, segSweep);
      if (visible > 0) {
        paint.color = s.color;
        canvas.drawArc(rect, start, visible, false, paint);
      }
      start += full;
      consumed += full;
      if (consumed >= revealAngle) break;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices ||
      oldDelegate.total != total ||
      oldDelegate.reveal.value != reveal.value;
}
