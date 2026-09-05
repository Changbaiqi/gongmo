import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../stats_controller.dart';

class TrendChart extends StatefulWidget {
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
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  static const _hPad = 8.0;
  int? _selected;

  @override
  void didUpdateWidget(covariant TrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buckets != widget.buckets) {
      _selected = null;
    } else if (_selected != null && _selected! >= widget.buckets.length) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final n = widget.buckets.length;
              if (n == 0) return;
              final bw = (constraints.maxWidth - _hPad * 2) / n;
              final idx =
                  ((details.localPosition.dx - _hPad) / bw).floor();
              if (idx < 0 || idx >= n) return;
              HapticFeedback.selectionClick();
              setState(() => _selected = _selected == idx ? null : idx);
            },
            child: CustomPaint(
              painter: _TrendPainter(
                buckets: widget.buckets,
                incomeColor: widget.incomeColor,
                expenseColor: widget.expenseColor,
                labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                axisColor: Theme.of(context).colorScheme.outlineVariant,
                selectedIndex: _selected,
              ),
            ),
          );
        },
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
  final int? selectedIndex;

  _TrendPainter({
    required this.buckets,
    required this.incomeColor,
    required this.expenseColor,
    required this.labelColor,
    required this.axisColor,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    const topPad = 22.0;
    const bottomPad = 26.0;
    const hPad = _hPadPadding;
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

    final hasSelection = selectedIndex != null && selectedIndex! >= 0;
    final normalBarW = math.max(2.5, math.min(16.0, bw * 0.3));
    const gap = 3.0;

    final stride = (buckets.length / 8).ceil();

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
      final isSel = i == selectedIndex;
      final barW = isSel
          ? math.min(normalBarW * 1.6, bw * 0.42)
          : normalBarW;
      final groupW = barW * 2 + gap;
      final x0 = cx - groupW / 2;
      final alpha = hasSelection && !isSel ? 0.4 : 1.0;

      final incomeTop = _drawBar(canvas, x0, barW, b.income, maxV, topPad,
          plotH, incomeColor.withValues(alpha: alpha));
      final expenseTop = _drawBar(canvas, x0 + barW + gap, barW, b.expense,
          maxV, topPad, plotH, expenseColor.withValues(alpha: alpha));

      if (isSel) {
        if (b.income > 0) {
          _drawAmount(canvas, _fmt(b.income),
              x0 + barW / 2, incomeTop, incomeColor, size.width);
        }
        if (b.expense > 0) {
          _drawAmount(canvas, _fmt(b.expense),
              x0 + barW + gap + barW / 2, expenseTop, expenseColor,
              size.width);
        }
      }

      final showLabel = labelIdx.contains(i);
      if (showLabel || isSel) {
        _drawAxisLabel(
          canvas,
          b.label,
          cx,
          topPad + plotH + 8,
          bold: isSel,
        );
      }
    }
  }

  double _drawBar(Canvas canvas, double x, double w, double v, double maxV,
      double top, double plotH, Color color) {
    if (v <= 0) return top + plotH;
    final h = math.max(2.0, v / maxV * plotH);
    final rect = Rect.fromLTWH(x, top + plotH - h, w, h);
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
    );
    canvas.drawRRect(rrect, Paint()..color = color);
    return top + plotH - h;
  }

  void _drawAmount(
      Canvas canvas, String text, double cx, double barTop, Color color,
      double chartWidth) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var lx = cx - tp.width / 2;
    lx = lx.clamp(2.0, math.max(2.0, chartWidth - tp.width - 2));
    final ly = math.max(2.0, barTop - tp.height - 4);
    tp.paint(canvas, Offset(lx, ly));
  }

  void _drawAxisLabel(Canvas canvas, String text, double cx, double y,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          color: labelColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, y));
  }

  String _fmt(double v) {
    final s = v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return '¥${s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')}';
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.buckets != buckets ||
      oldDelegate.selectedIndex != selectedIndex;
}

const _hPadPadding = 8.0;
