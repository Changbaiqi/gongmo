// ============================================================
// 图案锁组件（core/widgets）
// 职责：3×3 九宫格图案绘制与手势采集（不负责校验，校验在 LockController）
// 关联：解锁页、图案设置页
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 3×3 图案锁：拖动连接圆点，完成时回调选中的点索引序列（0-8，左上到右下）
class PatternLock extends StatefulWidget {
  const PatternLock({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.size = 260,
    this.error = false,
    this.enabled = true,
  });

  final ValueChanged<List<int>> onCompleted;
  final ValueChanged<List<int>>? onChanged;
  final double size;
  final bool error;
  final bool enabled;

  @override
  State<PatternLock> createState() => _PatternLockState();
}

class _PatternLockState extends State<PatternLock>
    with SingleTickerProviderStateMixin {
  final List<int> _selected = [];
  Offset? _cursor;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(covariant PatternLock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error && !oldWidget.error) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Size get _box => Size(widget.size, widget.size);

  Offset _centerOf(int i) {
    final cell = widget.size / 3;
    final r = i ~/ 3, c = i % 3;
    return Offset(cell * c + cell / 2, cell * r + cell / 2);
  }

  int? _hit(Offset p) {
    final cell = widget.size / 3;
    for (var i = 0; i < 9; i++) {
      if ((_centerOf(i) - p).distance <= cell * 0.34) return i;
    }
    return null;
  }

  /// 手指移动时更新选点；经过已选点只移动“光标线”，不重复记录
  void _update(Offset p) {
    if (!widget.enabled) return;
    final hit = _hit(p);
    if (hit != null && !_selected.contains(hit)) {
      setState(() {
        // 跨越中间点时自动补上中间点
        if (_selected.isNotEmpty) {
          final last = _selected.last;
          final lr = last ~/ 3, lc = last % 3;
          final hr = hit ~/ 3, hc = hit % 3;
          if ((lr + hr).isEven && (lc + hc).isEven) {
            final mid = ((lr + hr) ~/ 2) * 3 + ((lc + hc) ~/ 2);
            if (!_selected.contains(mid)) _selected.add(mid);
          }
        }
        _selected.add(hit);
        _cursor = p;
      });
      widget.onChanged?.call(List<int>.of(_selected));
    } else {
      setState(() => _cursor = p);
    }
  }

  /// 抬手/取消时清空轨迹并把结果交给调用方校验
  void _end() {
    if (!widget.enabled || _selected.isEmpty) return;
    final result = List<int>.of(_selected);
    setState(() {
      _selected.clear();
      _cursor = null;
    });
    widget.onCompleted(result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = widget.error ? cs.error : cs.primary;
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, _) {
        final t = _shake.value;
        final dx = t == 0 ? 0.0 : math.sin(t * math.pi * 5) * 9 * (1 - t);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => _update(d.localPosition),
              onPanUpdate: (d) => _update(d.localPosition),
              onPanEnd: (_) => _end(),
              onPanCancel: _end,
              child: CustomPaint(
                size: _box,
                painter: _PatternPainter(
                  selected: _selected,
                  cursor: _cursor,
                  activeColor: activeColor,
                  idleColor: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  size: _box,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 图案绘制器：连线 + 已选点光圈 + 未选点圆点
class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.selected,
    required this.cursor,
    required this.activeColor,
    required this.idleColor,
    required this.size,
  });

  final List<int> selected;
  final Offset? cursor;
  final Color activeColor;
  final Color idleColor;
  final Size size;

  Offset _centerOf(int i) {
    final cell = size.width / 3;
    final r = i ~/ 3, c = i % 3;
    return Offset(cell * c + cell / 2, cell * r + cell / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 3;
    final dotRadius = cell * 0.11;
    final ringRadius = cell * 0.24;

    // 连线
    if (selected.isNotEmpty) {
      final linePaint = Paint()
        ..color = activeColor
        ..strokeWidth = cell * 0.06
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < selected.length - 1; i++) {
        canvas.drawLine(
            _centerOf(selected[i]), _centerOf(selected[i + 1]), linePaint);
      }
      if (cursor != null) {
        canvas.drawLine(
            _centerOf(selected.last), cursor!, linePaint);
      }
    }

    // 圆点
    for (var i = 0; i < 9; i++) {
      final c = _centerOf(i);
      final isSelected = selected.contains(i);
      if (isSelected) {
        canvas.drawCircle(
            c, ringRadius, Paint()..color = activeColor.withValues(alpha: 0.18));
        canvas.drawCircle(
          c,
          ringRadius,
          Paint()
            ..color = activeColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.035,
        );
      }
      canvas.drawCircle(
        c,
        dotRadius,
        Paint()..color = isSelected ? activeColor : idleColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) => true;
}
