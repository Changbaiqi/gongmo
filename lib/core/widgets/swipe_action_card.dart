// ============================================================
// swipe_action_card.dart（core/widgets · 通用交互组件）
// 职责：左滑露出“修改/删除”按钮的列表卡片容器，供账目、计时等列表复用。
// 关联：纯 UI 组件，不依赖任何控制器；回调由调用方提供。
// ============================================================
import 'package:flutter/material.dart';

/// 左滑操作卡片：内容上盖一层手势层，向左滑动超过阈值露出右侧两个操作按钮。
///
/// 结构为 `Stack`：底层是固定在右侧的按钮排（总宽 [_actionWidth]，修改/删除各
/// 70），上层是随动画左移的内容。用 AnimationController 而非直接拖拽，
/// 手势结束后总是吸附到“全开/全关”两个状态，交互更稳定。
class SwipeActionCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SwipeActionCard({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<SwipeActionCard> createState() => _SwipeActionCardState();
}

class _SwipeActionCardState extends State<SwipeActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _openAnim;

  static const _actionWidth = 140.0;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    // 动画值从“按钮区宽度”过渡到 0，配合下方 translate 负向偏移实现露出
    _openAnim = Tween<double>(begin: _actionWidth, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _open() {
    _ctrl.forward();
    _isOpen = true;
  }

  void _close() {
    _ctrl.reverse();
    _isOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            // 用滑动“速度”而不是位移做阈值判断：轻快左滑（<-200）即打开，
            // 右滑（>200）即关闭，避免慢速拖动后停在半开状态
            if (details.primaryVelocity! < -200 && !_isOpen) {
              _open();
            } else if (details.primaryVelocity! > 200 && _isOpen) {
              _close();
            }
          }
        },
        onTap: () {
          if (_isOpen) _close(); // 点空白处先收起按钮，不触发卡片自身点击
        },
        child: Stack(
          children: [
            Positioned.fill(
              // 右侧按钮区：点按后先收起再回调，避免操作后卡片停在打开状态
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      _close();
                      widget.onEdit();
                    },
                    child: Container(
                      width: 70,
                      color: Colors.blue,
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_outlined,
                              color: Colors.white, size: 20),
                          SizedBox(height: 2),
                          Text('修改',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _close();
                      widget.onDelete();
                    },
                    child: Container(
                      width: 70,
                      color: Colors.red,
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline,
                              color: Colors.white, size: 20),
                          SizedBox(height: 2),
                          Text('删除',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _openAnim,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(-(_actionWidth - _openAnim.value), 0),
                  child: child,
                );
              },
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
