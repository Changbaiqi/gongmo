import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../work_stats_controller.dart';

/// 单系列时长柱状图：点击柱形在其顶部显示时长，再次点击恢复
class DurationBarChart extends StatefulWidget {
  final List<WorkTrendBucket> buckets;
  final Color barColor;

  const DurationBarChart({
    super.key,
    required this.buckets,
    required this.barColor,
  });

  @override
  State<DurationBarChart> createState() => _DurationBarChartState();
}

class _DurationBarChartState extends State<DurationBarChart> {
  static const _hPad = 8.0;
  int? _selected;

  @override
  void didUpdateWidget(covariant DurationBarChart oldWidget) {
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
      height: 190,
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
              painter: _DurationBarPainter(
                buckets: widget.buckets,
                barColor: widget.barColor,
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

class _DurationBarPainter extends CustomPainter {
  final List<WorkTrendBucket> buckets;
  final Color barColor;
  final Color labelColor;
  final Color axisColor;
  final int? selectedIndex;

  _DurationBarPainter({
    required this.buckets,
    required this.barColor,
    required this.labelColor,
    required this.axisColor,
    this.selectedIndex,
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
      maxV = math.max(maxV, b.minutes);
    }
    if (maxV <= 0) maxV = 60;
    maxV *= 1.15;

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(hPad, topPad + plotH),
      Offset(size.width - hPad, topPad + plotH),
      axisPaint,
    );

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
          ? math.min(normalBarW(bw) * 1.8, bw * 0.5)
          : normalBarW(bw);

      double barTop = topPad + plotH;
      if (b.minutes > 0) {
        final h = math.max(2.0, b.minutes / maxV * plotH);
        barTop = topPad + plotH - h;
        final rect = Rect.fromLTWH(cx - barW / 2, barTop, barW, h);
        final rrect = RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(rrect, Paint()..color = barColor);
      }

      if (isSel) {
        _drawAmount(canvas, formatMinutes(b.minutes), cx, barTop, size.width);
      }

      if (labelIdx.contains(i) || isSel) {
        _drawAxisLabel(canvas, b.label, cx, topPad + plotH + 8, bold: isSel);
      }
    }
  }

  double normalBarW(double bw) => math.max(2.5, math.min(18.0, bw * 0.4));

  void _drawAmount(
      Canvas canvas, String text, double cx, double barTop, double chartWidth) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: barColor,
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

  @override
  bool shouldRepaint(covariant _DurationBarPainter oldDelegate) =>
      oldDelegate.buckets != buckets ||
      oldDelegate.selectedIndex != selectedIndex;
}

const _hPadPadding = 8.0;

/// 分钟数转可读文本：90 -> "1小时30分"
String formatMinutes(double minutes) {
  final total = minutes.round();
  final h = total ~/ 60;
  final m = total % 60;
  if (h > 0 && m > 0) return '$h小时$m分';
  if (h > 0) return '$h小时';
  return '$m分钟';
}
