import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/utils/icon_utils.dart';
import '../../../data/models/category.dart';
import '../../../data/models/finance_entry.dart';
import '../finance_controller.dart';
import 'attachment_viewer.dart';

/// 账目详情弹窗（只读，发票/小票样式，底部锯齿边）
///
/// 过渡动画：整体自上而下轻微滑入 + 缩放 + 淡入，内部区块依次浮现，
/// 像一张小票被“抽出”展开。
Future<void> showFinanceDetailDialog(
    BuildContext context, FinanceController fc, FinanceEntry entry) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '账目详情',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _FinanceDetailDialog(fc: fc, entry: entry, animation: animation),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.7, curve: Curves.easeOut),
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

class _FinanceDetailDialog extends StatelessWidget {
  const _FinanceDetailDialog({
    required this.fc,
    required this.entry,
    required this.animation,
  });

  final FinanceController fc;
  final FinanceEntry entry;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 分类与颜色
    Category? cat;
    for (final c in fc.categories) {
      if (c.id == entry.categoryId) {
        cat = c;
        break;
      }
    }
    final isIncome = entry.type == FinanceType.income;
    final amountColor = isIncome ? Colors.green.shade600 : cs.error;
    final catColor = IconUtils.hex(cat?.color,
        isIncome ? Colors.green.shade600 : Colors.orange.shade600);
    final catName = cat?.name ?? fc.getCategoryName(entry.categoryId);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 26, vertical: 48),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: PhysicalShape(
          clipper: _TicketClipper(),
          color: cs.surface,
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Reveal(
                  animation: animation,
                  begin: 0.0,
                  end: 0.55,
                  child: _buildHeader(context, cs, cat, catColor, catName,
                      isIncome, amountColor),
                ),
                _Reveal(
                  animation: animation,
                  begin: 0.08,
                  end: 0.62,
                  child: Column(
                    children: [
                      _dashedDivider(cs),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                        child: Column(
                          children: [
                            _row(cs, '类型', isIncome ? '收入' : '支出'),
                            if (entry.description.trim().isNotEmpty)
                              _row(cs, '备注', entry.description.trim()),
                            _row(cs, '分类', catName),
                            _row(cs, '时间',
                                DateHelper.formatDisplay(entry.date)),
                            _row(cs, '来源', _sourceLabel(entry)),
                            if (entry.workEntryId != null)
                              _row(cs, '关联', '计时记录结算'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.attachmentPaths.isNotEmpty)
                  _Reveal(
                    animation: animation,
                    begin: 0.16,
                    end: 0.72,
                    child: Column(
                      children: [
                        _dashedDivider(cs),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('附件（${entry.attachmentPaths.length}）',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurfaceVariant)),
                              const SizedBox(height: 6),
                              for (final rel in entry.attachmentPaths)
                                _attachmentTile(context, cs, rel),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                _Reveal(
                  animation: animation,
                  begin: 0.24,
                  end: 0.82,
                  child: Column(
                    children: [
                      _dashedDivider(cs),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                        child: Text('查看详情 · 如需修改请左滑账目卡片',
                            style: TextStyle(
                                fontSize: 10.5,
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.7))),
                      ),
                    ],
                  ),
                ),
                // 底部锯齿留白
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 发票抬头：分类图标 + 名称 + 金额
  Widget _buildHeader(
    BuildContext context,
    ColorScheme cs,
    Category? cat,
    Color catColor,
    String catName,
    bool isIncome,
    Color amountColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            catColor.withValues(alpha: 0.16),
            catColor.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(IconUtils.category(cat?.icon ?? ''),
                color: catColor, size: 22),
          ),
          const SizedBox(height: 10),
          Text(catName,
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.85))),
          const SizedBox(height: 6),
          Text(
            '${isIncome ? '+' : '-'}¥${entry.amount.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: amountColor,
                fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isIncome ? '收入' : '支出',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: amountColor)),
          ),
        ],
      ),
    );
  }

  Widget _row(ColorScheme cs, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.85))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _attachmentTile(BuildContext context, ColorScheme cs, String rel) {
    final name = rel.split('/').last;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => openAttachment(rel),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              _iconOf(name),
              size: 18,
              color: cs.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(name,
                  style: const TextStyle(fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  IconData _iconOf(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (n.endsWith('.txt') || n.endsWith('.md') || n.endsWith('.log')) {
      return Icons.description_outlined;
    }
    if (n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.gif') ||
        n.endsWith('.webp')) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _sourceLabel(FinanceEntry e) {
    final src = e.notificationSrc;
    if (src == null || src.isEmpty) return '手动记账';
    switch (src) {
      case 'alipay':
        return '自动记账 · 支付宝';
      case 'wechat':
        return '自动记账 · 微信';
      case 'cmb':
        return '自动记账 · 招商银行';
      case 'screenshot':
        return '识图记账 · 截屏';
      case 'camera':
        return '识图记账 · 拍照';
      default:
        return '自动记账 · $src';
    }
  }

  Widget _dashedDivider(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SizedBox(
        height: 1,
        width: double.infinity,
        child: CustomPaint(
          painter: _DashedLinePainter(
            color: cs.outlineVariant.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}

/// 内容分段的浮现动画：随时间区间淡入并轻微上移
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.begin,
    required this.end,
    required this.child,
  });

  final Animation<double> animation;
  final double begin;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
      reverseCurve: Interval(begin, end, curve: Curves.easeIn),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// 虚线分隔（发票上的撕线）
class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + dash, size.width), 0),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 小票样式裁剪：顶部圆角 + 底部锯齿
class _TicketClipper extends CustomClipper<Path> {
  static const double _radius = 18;
  static const double _toothHeight = 9;
  static const double _toothWidth = 13;

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(0, _radius);
    path.quadraticBezierTo(0, 0, _radius, 0);
    path.lineTo(w - _radius, 0);
    path.quadraticBezierTo(w, 0, w, _radius);

    // 右侧下滑到锯齿起点
    path.lineTo(w, h - _toothHeight);

    // 底部锯齿：从右往左交替上下
    final count = math.max(1, (w / _toothWidth).floor());
    final step = w / count;
    for (var i = 0; i < count; i++) {
      final xStart = w - step * i;
      final xMid = xStart - step / 2;
      final xEnd = xStart - step;
      path.lineTo(xMid, h);
      path.lineTo(xEnd, h - _toothHeight);
    }

    path.lineTo(0, _radius);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_TicketClipper oldClipper) => false;
}
