// ============================================================
// tap_scale.dart（core/widgets · 通用交互组件）
// 职责：给任意子组件包一层“按下缩小、松开回弹”的触感反馈。
// 关联：纯 UI 组件，常用来包装自定义按钮；不依赖控制器。
// ============================================================
import 'package:flutter/material.dart';

/// 按钮按下的缩放反馈包装。
///
/// 用 GestureDetector 的按下/抬起/取消三个回调驱动 AnimatedScale；
/// onTap 为 null 时视为禁用，不响应任何手势。
class TapScale extends StatefulWidget {
  const TapScale({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    // onTap 为空表示禁用，所有手势回调一并置空，避免出现“按了没反应”的假反馈
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled
          ? (_) {
              // 先回弹再触发点击，保证动画与业务回调互不阻塞
              setState(() => _down = false);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
