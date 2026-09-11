// ============================================================
// fade_slide_in.dart（core/widgets · 通用动画组件）
// 职责：子组件首次挂载时播放“上滑 + 淡入”入场动画，可按 index 交错延迟。
// 关联：纯 UI 组件；settings/sync 等页面用它包装列表项做瀑布式出现效果。
// ============================================================
import 'package:flutter/material.dart';

/// 首次出现的上滑淡入（按 index 交错延迟）。
///
/// 只在 `initState` 里延迟一次并置为已显示，之后重建不会重播；
/// index 会 clamp 到 8，防止长列表中靠后的元素等待时间线性增长。
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;

  /// 第几个出现，用于计算交错延迟（每级 45ms）
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(
        Duration(milliseconds: 45 * widget.index.clamp(0, 8)), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, 0.06),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: widget.child,
      ),
    );
  }
}
