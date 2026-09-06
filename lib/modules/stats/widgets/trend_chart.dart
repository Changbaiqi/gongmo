import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../stats_controller.dart';

/// 收支趋势折线图：收入/支出双折线，点击查看某时段数值
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

class _TrendChartState extends State<TrendChart>
    with SingleTickerProviderStateMixin {
  static const _hPad = 12.0;
  int? _selected;
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void initState() {
    super.initState();
    _reveal.forward();
  }

  @override
  void didUpdateWidget(covariant TrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buckets != widget.buckets) {
      _selected = null;
      _reveal.forward(from: 0);
    } else if (_selected != null && _selected! >= widget.buckets.length) {
      _selected = null;
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
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
              painter: _TrendLinePainter(
                buckets: widget.buckets,
                incomeColor: widget.incomeColor,
                expenseColor: widget.expenseColor,
                labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                axisColor: Theme.of(context).colorScheme.outlineVariant,
                selectedIndex: _selected,
                reveal: _reveal,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  final List<TrendBucket> buckets;
  final Color incomeColor;
  final Color expenseColor;
  final Color labelColor;
  final Color axisColor;
  final int? selectedIndex;
  final Animation<double> reveal;

  static const _hPadPadding = 12.0;

  _TrendLinePainter({
    required this.buckets,
    required this.incomeColor,
    required this.expenseColor,
    required this.labelColor,
    required this.axisColor,
    this.selectedIndex,
    required this.reveal,
  }) : super(repaint: reveal);

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    const topPad = 24.0;
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
    maxV *= 1.2;

    double yOf(double v) => topPad + plotH - (v / maxV * plotH);
    double cxOf(int i) => hPad + bw * i + bw / 2;

    // 横向辅助网格线
    final gridPaint = Paint()
      ..color = axisColor.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (final f in [1 / 3.0, 2 / 3.0]) {
      final y = topPad + plotH * f;
      canvas.drawLine(Offset(hPad, y), Offset(size.width - hPad, y), gridPaint);
    }
    // 底部轴线
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(hPad, topPad + plotH),
      Offset(size.width - hPad, topPad + plotH),
      axisPaint,
    );

    // 选中桶的高亮底色
    if (selectedIndex != null && selectedIndex! >= 0) {
      final i = selectedIndex!;
      final rect = Rect.fromLTWH(hPad + bw * i, topPad - 6, bw, plotH + 6);
      canvas.drawRect(
          rect, Paint()..color = labelColor.withValues(alpha: 0.06));
    }

    // 折线主体（从左到右揭示动画）
    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(0, 0, size.width * reveal.value, size.height));

    for (final series in [
      (color: incomeColor, isIncome: true),
      (color: expenseColor, isIncome: false),
    ]) {
      final path = Path();
      var started = false;
      for (var i = 0; i < buckets.length; i++) {
        final v = series.isIncome ? buckets[i].income : buckets[i].expense;
        final p = Offset(cxOf(i), yOf(v));
        if (!started) {
          path.moveTo(p.dx, p.dy);
          started = true;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = series.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      // 数据点
      for (var i = 0; i < buckets.length; i++) {
        final v = series.isIncome ? buckets[i].income : buckets[i].expense;
        canvas.drawCircle(
          Offset(cxOf(i), yOf(v)),
          i == selectedIndex ? 4.5 : 3,
          Paint()..color = series.color,
        );
      }
    }
    canvas.restore();

    // x 轴刻度标签
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
      final cxLast = cxOf(labelIdx[j + 1]);
      final cxCur = cxOf(labelIdx[j]);
      if (cxLast - cxCur < minGap) {
        labelIdx.removeAt(j);
      }
    }
    for (var i = 0; i < buckets.length; i++) {
      if (labelIdx.contains(i) || i == selectedIndex) {
        _drawText(canvas, buckets[i].label, cxOf(i), topPad + plotH + 8,
            color: labelColor,
            bold: i == selectedIndex,
            center: true);
      }
    }

    // 选中：竖向参考线 + 数值标签（纵向堆叠防重叠）
    if (selectedIndex != null && selectedIndex! >= 0) {
      final i = selectedIndex!;
      final b = buckets[i];
      final cx = cxOf(i);
      final iy = yOf(b.income);
      final ey = yOf(b.expense);

      final guide = Paint()
        ..color = labelColor.withValues(alpha: 0.4)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(cx, topPad - 4), Offset(cx, topPad + plotH), guide);

      final labels = <(Color, String)>[
        if (b.income > 0) (incomeColor, '收 ${_fmt(b.income)}'),
        if (b.expense > 0) (expenseColor, '支 ${_fmt(b.expense)}'),
      ];
      if (labels.isEmpty) {
        _drawText(canvas, '¥0', cx, math.min(iy, ey) - 18,
            color: labelColor, center: true);
      } else {
        final top = math.min(iy, ey) - 6 - labels.length * 13;
        for (var k = 0; k < labels.length; k++) {
          _drawText(canvas, labels[k].$2, cx, math.max(2.0, top + k * 13),
              color: labels[k].$1, bold: true, center: true);
        }
      }
    }
  }

  void _drawText(Canvas canvas, String text, double cx, double y,
      {required Color color, bool bold = false, bool center = true}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var x = center ? cx - tp.width / 2 : cx;
    x = x.clamp(2.0, math.max(2.0, 9999.0));
    tp.paint(canvas, Offset(x, y));
  }

  String _fmt(double v) {
    final s = v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return '¥${s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')}';
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) =>
      oldDelegate.buckets != buckets ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.reveal.value != reveal.value;
}
