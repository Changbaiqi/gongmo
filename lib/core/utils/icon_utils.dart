// ============================================================
// 图标与颜色解析工具（core/utils）
// 职责：把数据模型中以字符串保存的图标 key / 颜色值转换为 Flutter 对象
// 关联：TimerTag.icon、Category.icon/color；各标签栏、分类网格使用
// ============================================================

import 'package:flutter/material.dart';

/// 图标 key → IconData、颜色字符串 → Color 的统一转换入口。
/// 图标 key 随数据持久化，因此所有映射必须保持稳定，未知 key 回退默认图标。
class IconUtils {
  /// 计时标签可选图标集（key 持久化在 TimerTag.icon）
  static const Map<String, IconData> tagIcons = {
    'work': Icons.work_outline_rounded,
    'school': Icons.school_outlined,
    'menu_book': Icons.menu_book_outlined,
    'code': Icons.code_rounded,
    'brush': Icons.brush_outlined,
    'music_note': Icons.music_note_outlined,
    'self_improvement': Icons.self_improvement,
    'fitness_center': Icons.fitness_center_outlined,
    'favorite': Icons.favorite_outline_rounded,
    'timer': Icons.timer_outlined,
    'flight': Icons.flight_takeoff_rounded,
    'directions_car': Icons.directions_car_rounded,
    'local_cafe': Icons.local_cafe_outlined,
    'restaurant': Icons.restaurant_rounded,
    'shopping_cart': Icons.shopping_cart_outlined,
    'sports_esports': Icons.sports_esports_outlined,
    'savings': Icons.savings_outlined,
    'home': Icons.home_outlined,
    'groups': Icons.groups_outlined,
    'label': Icons.label_outline_rounded,
  };

  /// 按 key 取标签图标，未知 key 回退为默认标签图标
  static IconData tag(String name) =>
      tagIcons[name] ?? Icons.label_outline_rounded;

  /// 记账分类可选图标 key 列表（供分类编辑页选择）
  static const List<String> categoryIconKeys = [
    'restaurant', 'directions_car', 'print', 'computer', 'work', 'chat',
    'attach_money', 'more_horiz', 'school', 'favorite', 'sports_esports',
    'savings', 'home', 'flight', 'local_cafe', 'music_note',
  ];

  /// 按 key 取分类图标，未知 key 回退为默认标签图标
  static IconData category(String name) {
    switch (name) {
      case 'work':
        return Icons.work_outline_rounded;
      case 'chat':
        return Icons.chat_bubble_outline_rounded;
      case 'attach_money':
        return Icons.attach_money_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'print':
        return Icons.print_outlined;
      case 'computer':
        return Icons.computer_outlined;
      case 'school':
        return Icons.school_outlined;
      case 'favorite':
        return Icons.favorite_outline_rounded;
      case 'sports_esports':
        return Icons.sports_esports_outlined;
      case 'savings':
        return Icons.savings_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'flight':
        return Icons.flight_takeoff_rounded;
      case 'local_cafe':
        return Icons.local_cafe_outlined;
      case 'music_note':
        return Icons.music_note_outlined;
      case 'more_horiz':
        return Icons.more_horiz_rounded;
      default:
        return Icons.label_outline_rounded;
    }
  }

  /// 解析 "#RRGGBB" 颜色字符串（补全不透明 Alpha），非法值返回 [fallback]
  static Color hex(String? hex, [Color fallback = Colors.grey]) {
    if (hex == null) return fallback;
    final value = hex.replaceFirst('#', '');
    if (value.length == 6) {
      final parsed = int.tryParse('FF$value', radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return fallback;
  }
}
