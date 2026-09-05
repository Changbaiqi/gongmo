import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../stats_controller.dart';

class TrendChart extends StatelessWidget {
  final List<TrendBucket> buckets;
  final Color incomeColor;
  final Color expenseColor;

  const TrendChart({
    super.key,
    required this.buckets,
    this.incomeColor = const Color(0xFF4CAF50),
    this.expenseColor = const Color(0xFFEF5350),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      width: double.infinity,
      child: CustomPaint(
        painter: _TrendPainter(
          buckets: buckets,
          incomeColor: incomeColor,
          expenseColor: expenseColor,
          labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          axisColor: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<TrendBucket> buckets;
  final Color incomeColor;
  final Color expenseColor;
  final Color labelColor;
  final Color axisColor;

  _TrendPainter({
    required this.buckets,
    required this.incomeColor,
    required this.expenseColor,
    required this.labelColor,
    required this.axisColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    const topPad = 12.0;
    const bottomPad = 26.0;
    const hPad = 8.0;
    final plotW = size.width - hPad * 2;
    final plotH = size.height - topPad - bottomPad;
    final bw = plotW / buckets.length;

    double maxV = 0;
    for (final b in buckets) {
      maxV = math.max(maxV, b.income);
      maxV = math.max(maxV, b.expense);
    }
    if (maxV <= 0) maxV = 100;
    maxV *= 1.15;

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(hPad, topPad + plotH),
      Offset(size.width - hPad, topPad + plotH),
      axisPaint,
    );

    final barW = math.max(2.5, math.min(16.0, bw * 0.3));
    const gap = 3.0;
    final groupW = barW * 2 + gap;

    final stride = (buckets.length / 8).ceil();

    // 计算需要绘制的刻度：stride 间隔 + 末位，并保证相邻标签间距足够
    final labelIdx = <int>[
      for (var i = 0; i < buckets.length; i++)
        if (i % stride == 0) i,
    ];
    if (labelIdx.last != buckets.length - 1) {
      labelIdx.add(buckets.length - 1);
    }
    const minGap = 26.0;
    for (var j = labelIdx.length - 2; j > 0; j--) {
      final cxLast = hPad + bw * labelIdx[j + 1] + bw / 2;
      final cxCur = hPad + bw * labelIdx[j] + bw / 2;
      if (cxLast - cxCur < minGap) {
        labelIdx.removeAt(j);
      }
    }

    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final cx = hPad + bw * i + bw / 2;
      final x0 = cx - groupW / 2;

      _drawBar(canvas, x0, barW, b.income, maxV, topPad, plotH, incomeColor);
      _drawBar(
          canvas, x0 + barW + gap, barW, b.expense, maxV, topPad, plotH, expenseColor);

      if (labelIdx.contains(i)) {
        _drawLabel(canvas, b.label, cx, topPad + plotH + 8);
      }
    }
  }

  void _drawBar(Canvas canvas, double x, double w, double v, double maxV,
      double top, double plotH, Color color) {
    if (v <= 0) return;
    final h = math.max(2.0, v / maxV * plotH);
    final rect = Rect.fromLTWH(x, top + plotH - h, w, h);
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
    );
    canvas.drawRRect(rrect, Paint()..color = color);
  }

  void _drawLabel(Canvas canvas, String text, double cx, double y) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 10, color: labelColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, y));
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.buckets != buckets;
}
