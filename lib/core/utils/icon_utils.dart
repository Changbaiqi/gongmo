import 'package:flutter/material.dart';

class IconUtils {
  /// 标签可选图标集
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

  static IconData tag(String name) =>
      tagIcons[name] ?? Icons.label_outline_rounded;

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
      case 'more_horiz':
        return Icons.more_horiz_rounded;
      default:
        return Icons.label_outline_rounded;
    }
  }

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
