import 'package:flutter/material.dart';

import '../../data/services/storage_service.dart';

/// 一步引导：高亮目标控件 + 旁边显示提示
class SpotlightStep {
  const SpotlightStep({
    required this.targetKey,
    required this.title,
    required this.text,
  });

  final GlobalKey targetKey;
  final String title;
  final String text;
}

/// 交互式新手引导：首次进入页面时依次框出关键控件并显示提示。
/// 每个 guideId 只会展示一次（看过或跳过后记录标记）。
Future<void> showSpotlightGuide(
  BuildContext context, {
  required String guideId,
  required List<SpotlightStep> steps,
}) async {
  if (steps.isEmpty) return;
  if (StorageService().getConfig('guide_$guideId') == true) return;
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: '新手引导',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, animation, __) =>
        _SpotlightGuide(guideId: guideId, steps: steps),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: child,
    ),
  );
}

class _SpotlightGuide extends StatefulWidget {
  const _SpotlightGuide({required this.guideId, required this.steps});

  final String guideId;
  final List<SpotlightStep> steps;

  @override
  State<_SpotlightGuide> createState() => _SpotlightGuideState();
}

class _SpotlightGuideState extends State<_SpotlightGuide> {
  int _index = 0;

  SpotlightStep get _step => widget.steps[_index];
  bool get _isLast => _index == widget.steps.length - 1;

  Rect? _targetRect() {
    final ctx = _step.targetKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      setState(() => _index++);
    }
  }

  Future<void> _finish() async {
    await StorageService().setConfig('guide_${widget.guideId}', true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rect = _targetRect();
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _SpotlightPainter(rect: rect)),
            ),
            if (rect != null)
              _buildTip(context, rect, size)
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(BuildContext context, Rect rect, Size screen) {
    final cs = Theme.of(context).colorScheme;
    const tipWidth = 300.0;
    const gap = 14.0;

    final showBelow = rect.bottom + 170 < screen.height;
    final left = (rect.center.dx - tipWidth / 2)
        .clamp(16.0, (screen.width - tipWidth - 16).clamp(16.0, 9999.0));

    final card = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(_index),
        width: tipWidth,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${_index + 1}/${widget.steps.length}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.primary)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_step.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(_step.text,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton(
                  onPressed: _finish,
                  child: Text('跳过',
                      style: TextStyle(
                          fontSize: 12.5, color: cs.onSurfaceVariant)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _next,
                  child: Text(_isLast ? '知道了' : '下一步',
                      style: const TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: left,
      width: tipWidth,
      top: showBelow ? rect.bottom + gap : null,
      bottom: showBelow ? null : screen.height - rect.top + gap,
      child: card,
    );
  }
}

/// 遮罩：整屏半透明黑 + 目标控件位置挖空并描边
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.rect});

  final Rect? rect;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.68);
    final full = Offset.zero & size;
    final r = rect;
    if (r == null) {
      canvas.drawRect(full, scrim);
      return;
    }
    final hole = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        (r.left - 6).clamp(0.0, size.width),
        (r.top - 6).clamp(0.0, size.height),
        r.width + 12,
        r.height + 12,
      ),
      const Radius.circular(14),
    );
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(full),
      Path()..addRRect(hole),
    );
    canvas.drawPath(path, scrim);
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.rect != rect;
}
