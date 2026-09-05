import 'package:flutter/material.dart';

class IconUtils {
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

  static IconData tag(String name) {
    switch (name) {
      case 'work':
        return Icons.work_outline_rounded;
      case 'school':
        return Icons.school_outlined;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'fitness_center':
        return Icons.fitness_center_outlined;
      case 'menu_book':
        return Icons.menu_book_outlined;
      case 'timer':
        return Icons.timer_outlined;
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
