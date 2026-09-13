// ============================================================
// widgets/duration_bar_chart.dart（时长趋势柱状图）
// 职责：用 CustomPainter 绘制单系列分钟柱状图，点击柱形查看数值
// 关联：数据来自 WorkStatsController.trendBuckets，由 WorkStatsView 使用；
//       并对外提供分钟格式化函数 formatMinutes
// ============================================================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../work_stats_controller.dart';

/// 单系列时长柱状图：点击柱形在其顶部显示时长，再次点击取消选中；
/// horizontal 为 true 时改为横向条形图（每行左侧标签、末端显示数值）
class DurationBarChart extends StatefulWidget {
  final List<WorkTrendBucket> buckets;
  final Color barColor;
  final bool horizontal;

  const DurationBarChart({
    super.key,
    required this.buckets,
    required this.barColor,
    this.horizontal = false,
  });

  @override
  State<DurationBarChart> createState() => _DurationBarChartState();
}

class _DurationBarChartState extends State<DurationBarChart>
    with SingleTickerProviderStateMixin {
  static const _hPad = 8.0; // 左右留白，与 painter 保持一致
  static const _hTopPad = 6.0; // 横向模式顶部留白
  static const _hRowH = 30.0; // 横向模式每行高度
  int? _selected; // 当前选中的柱下标，null 表示未选中

  /// 首次加载 / 数据变化时，柱形从 0 增长到目标值的过渡动画
  late final AnimationController _revealCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _reveal =
      CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    _revealCtrl.forward();
  }

  @override
  void didUpdateWidget(covariant DurationBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 视图每次 build 都会传入新的 list，这里按内容判断数据是否真的变化，
    // 避免无关重建把增长动画打断
    final changed = _signature(oldWidget.buckets) != _signature(widget.buckets);
    if (changed || oldWidget.horizontal != widget.horizontal) {
      _selected = null;
      _revealCtrl.forward(from: 0); // 新数据 / 新方向重播增长动画
    } else if (_selected != null && _selected! >= widget.buckets.length) {
      _selected = null;
    }
  }

  String _signature(List<WorkTrendBucket> buckets) => buckets
      .map((b) => '${b.label}:${b.minutes}')
      .join('|');

  @override
  void dispose() {
    _revealCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chart = LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final n = widget.buckets.length;
            if (n == 0) return;
            int idx;
            if (widget.horizontal) {
              // 横向：按行反算点击下标
              final rowH = (constraints.maxHeight - _hTopPad) / n;
              idx = ((details.localPosition.dy - _hTopPad) / rowH).floor();
            } else {
              // 纵向：按列反算点击位置落在哪根柱的等分区间内
              final bw = (constraints.maxWidth - _hPad * 2) / n;
              idx = ((details.localPosition.dx - _hPad) / bw).floor();
            }
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
              reveal: _reveal,
              horizontal: widget.horizontal,
            ),
          ),
        );
      },
    );

    if (!widget.horizontal) {
      return SizedBox(height: 190, width: double.infinity, child: chart);
    }

    // 横向条形图：行数多时固定视口高度，卡片内部可纵向滚动
    final rows = widget.buckets.isEmpty ? 4 : widget.buckets.length;
    final chartH =
        math.max(140.0, rows * _hRowH + _hTopPad + 6);
    final viewportH = math.min(chartH, 330.0);
    return SizedBox(
      height: viewportH,
      width: double.infinity,
      child: SingleChildScrollView(
        physics: chartH > viewportH
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: SizedBox(height: chartH, width: double.infinity, child: chart),
      ),
    );
  }
}

/// 柱状图绘制：坐标轴、按最大值归一化的柱形、选中态数值与标签
class _DurationBarPainter extends CustomPainter {
  final List<WorkTrendBucket> buckets;
  final Color barColor;
  final Color labelColor;
  final Color axisColor;
  final int? selectedIndex;
  final Animation<double> reveal;
  final bool horizontal;

  _DurationBarPainter({
    required this.buckets,
    required this.barColor,
    required this.labelColor,
    required this.axisColor,
    this.selectedIndex,
    required this.reveal,
    this.horizontal = false,
  }) : super(repaint: reveal);

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    if (horizontal) {
      _paintHorizontal(canvas, size);
      return;
    }
    const topPad = 22.0;
    const bottomPad = 26.0;
    final hPad = _hPadPadding;
    final plotW = size.width - hPad * 2;
    final plotH = size.height - topPad - bottomPad;
    final bw = plotW / buckets.length;

    // 取最大分钟数作为满高基准；全 0 时给 60 分钟兜底，
    // 再乘 1.15 留出顶部显示数值的空间
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

    // 横轴标签最多约 8 个，其余按步长抽稀，避免重叠
    final stride = (buckets.length / 8).ceil();
    final labelIdx = <int>[
      for (var i = 0; i < buckets.length; i++)
        if (i % stride == 0) i,
    ];
    if (labelIdx.last != buckets.length - 1) {
      labelIdx.add(buckets.length - 1);
    }
    // 从右往左去掉与下一个标签间距不足 26px 的标签（首尾保留）
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
      // 选中柱加宽突出，但不超过格子宽度的一半
      final barW = isSel
          ? math.min(normalBarW(bw) * 1.8, bw * 0.5)
          : normalBarW(bw);

      double barTop = topPad + plotH;
      if (b.minutes > 0) {
        // 最小 2px 高度，保证有时长的柱可见；reveal 让柱从 0 长出
        final full = math.max(2.0, b.minutes / maxV * plotH);
        final h = full * reveal.value;
        barTop = topPad + plotH - h;
        if (h > 0.01) {
          final rect = Rect.fromLTWH(cx - barW / 2, barTop, barW, h);
          final rrect = RRect.fromRectAndCorners(
            rect,
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
          );
          canvas.drawRRect(rrect, Paint()..color = barColor);
        }
      }

      if (isSel) {
        _drawAmount(canvas, formatMinutes(b.minutes), cx, barTop, size.width);
      }

      if (labelIdx.contains(i) || isSel) {
        _drawAxisLabel(canvas, b.label, cx, topPad + plotH + 8, bold: isSel);
      }
    }
  }

  /// 横向条形图：左侧标签列 + 向右生长的条形，所有数值显示在条形末端
  void _paintHorizontal(Canvas canvas, Size size) {
    const topPad = 6.0;
    const labelW = 46.0;
    const axisGap = 8.0;
    final plotLeft = labelW + axisGap;
    final plotW = math.max(10.0, size.width - plotLeft - 12);
    final rowH = (size.height - topPad) / buckets.length;

    double maxV = 0;
    for (final b in buckets) {
      maxV = math.max(maxV, b.minutes);
    }
    if (maxV <= 0) maxV = 60;
    maxV *= 1.15;

    // 竖直轴线
    canvas.drawLine(
      Offset(plotLeft, topPad - 2),
      Offset(plotLeft, size.height - 4),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1,
    );

    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final cy = topPad + rowH * i + rowH / 2;
      final isSel = i == selectedIndex;
      final barH = isSel
          ? math.min(normalBarW(rowH) * 1.8, rowH * 0.55)
          : normalBarW(rowH);

      var w = 0.0;
      if (b.minutes > 0) {
        final full = math.max(2.0, b.minutes / maxV * plotW);
        w = full * reveal.value;
        if (w > 0.01) {
          final rect = Rect.fromLTWH(plotLeft + 1, cy - barH / 2, w, barH);
          final rrect = RRect.fromRectAndCorners(
            rect,
            topRight: const Radius.circular(3),
            bottomRight: const Radius.circular(3),
          );
          canvas.drawRRect(rrect, Paint()..color = barColor);
        }
      }

      // 左侧标签（右对齐，贴住轴线）
      _drawLeftAxisLabel(canvas, b.label, labelW, cy, bold: isSel);

      // 所有柱形的数值都显示在条形末端
      _drawEndAmount(
          canvas, formatMinutes(b.minutes), plotLeft + w + 5, cy, size.width);
    }
  }

  void _drawLeftAxisLabel(Canvas canvas, String text, double labelW, double cy,
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
    tp.paint(canvas, Offset(labelW - tp.width - 6, cy - tp.height / 2));
  }

  void _drawEndAmount(
      Canvas canvas, String text, double x, double cy, double chartWidth) {
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
    final lx = math.min(x, math.max(2.0, chartWidth - tp.width - 2));
    tp.paint(canvas, Offset(lx, cy - tp.height / 2));
  }

  /// 常规柱宽：格子宽度的 40%，限制在 2.5~18px
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
    // 数值文字防止超出画布左右边界；柱太矮时贴到顶部显示
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
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.horizontal != horizontal;
}

const _hPadPadding = 8.0; // 与 DurationBarChart._hPad 保持一致的绘制留白

/// 分钟数转可读文本：90 -> "1小时30分"
String formatMinutes(double minutes) {
  final total = minutes.round();
  final h = total ~/ 60;
  final m = total % 60;
  if (h > 0 && m > 0) return '$h小时$m分';
  if (h > 0) return '$h小时';
  return '$m分钟';
}
