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

  /// 选中的柱形：桶下标 + 是否为收入柱（左半区=收入，右半区=支出）
  int? _selIdx;
  bool _selIncome = true;

  @override
  void didUpdateWidget(covariant TrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buckets != widget.buckets) {
      _selIdx = null;
    } else if (_selIdx != null && _selIdx! >= widget.buckets.length) {
      _selIdx = null;
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
              final dx = details.localPosition.dx - _hPad;
              var idx = (dx / bw).floor();
              if (idx < 0 || idx >= n) return;
              // 每个桶左半边为收入柱、右半边为支出柱的点击区
              final isIncome = dx < (idx + 0.5) * bw;
              HapticFeedback.selectionClick();
              setState(() {
                if (_selIdx == idx && _selIncome == isIncome) {
                  _selIdx = null;
                } else {
                  _selIdx = idx;
                  _selIncome = isIncome;
                }
              });
            },
            child: CustomPaint(
              painter: _TrendPainter(
                buckets: widget.buckets,
                incomeColor: widget.incomeColor,
                expenseColor: widget.expenseColor,
                labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                axisColor: Theme.of(context).colorScheme.outlineVariant,
                selectedIndex: _selIdx,
                selectedIncome: _selIncome,
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
  final bool selectedIncome;

  _TrendPainter({
    required this.buckets,
    required this.incomeColor,
    required this.expenseColor,
    required this.labelColor,
    required this.axisColor,
    this.selectedIndex,
    this.selectedIncome = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    const topPad = 22.0;
    const bottomPad = 26.0;
    final hPad = _hPadPadding;
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
      final isSelBucket = i == selectedIndex;
      final x0 = cx - (normalBarW * 2 + gap) / 2;

      // 选中柱加粗：以原柱中心为轴向两侧加宽，另一根柱保持原样
      final incomeW = isSelBucket && selectedIncome
          ? math.min(normalBarW * 1.8, bw * 0.46)
          : normalBarW;
      final expenseW = isSelBucket && !selectedIncome
          ? math.min(normalBarW * 1.8, bw * 0.46)
          : normalBarW;
      final incomeGrow = incomeW - normalBarW;
      final expenseGrow = expenseW - normalBarW;
      final incomeX = x0 - incomeGrow / 2;
      final expenseX = x0 + normalBarW + gap - expenseGrow / 2;

      final incomeTop = _drawBar(canvas, incomeX, incomeW, b.income, maxV,
          topPad, plotH, incomeColor);
      final expenseTop = _drawBar(canvas, expenseX, expenseW, b.expense,
          maxV, topPad, plotH, expenseColor);

      if (isSelBucket) {
        final value = selectedIncome ? b.income : b.expense;
        final color = selectedIncome ? incomeColor : expenseColor;
        final barTop = selectedIncome ? incomeTop : expenseTop;
        final barCx = selectedIncome
            ? incomeX + incomeW / 2
            : expenseX + expenseW / 2;
        _drawAmount(
            canvas, _fmt(value), barCx, barTop, color, size.width);
      }

      if (labelIdx.contains(i) || isSelBucket) {
        _drawAxisLabel(canvas, b.label, cx, topPad + plotH + 8, bold: isSelBucket);
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
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.selectedIncome != selectedIncome;
}

const _hPadPadding = 8.0;
