import 'finance_entry.dart';

class Category {
  final String id;
  String name;
  FinanceType type;
  String icon;
  String color;
  int sortOrder;

  Category({
    required this.id,
    required this.name,
    required this.type,
    this.icon = '',
    this.color = '#2196F3',
    this.sortOrder = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      type: FinanceType.values[json['type'] as int? ?? 0],
      icon: json['icon'] as String? ?? '',
      color: json['color'] as String? ?? '#2196F3',
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'icon': icon,
      'color': color,
      'sortOrder': sortOrder,
    };
  }

  Category copyWith({
    String? name,
    FinanceType? type,
    String? icon,
    String? color,
    int? sortOrder,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  static List<Category> defaultIncomeCategories() {
    return [
      Category(
          id: 'inc_1',
          name: '项目收入',
          type: FinanceType.income,
          icon: 'work',
          color: '#4CAF50',
          sortOrder: 1),
      Category(
          id: 'inc_2',
          name: '咨询收入',
          type: FinanceType.income,
          icon: 'chat',
          color: '#2196F3',
          sortOrder: 2),
      Category(
          id: 'inc_3',
          name: '其他收入',
          type: FinanceType.income,
          icon: 'attach_money',
          color: '#FF9800',
          sortOrder: 3),
    ];
  }

  static List<Category> defaultExpenseCategories() {
    return [
      Category(
          id: 'exp_1',
          name: '餐饮',
          type: FinanceType.expense,
          icon: 'restaurant',
          color: '#FF5722',
          sortOrder: 1),
      Category(
          id: 'exp_2',
          name: '交通',
          type: FinanceType.expense,
          icon: 'directions_car',
          color: '#2196F3',
          sortOrder: 2),
      Category(
          id: 'exp_3',
          name: '办公用品',
          type: FinanceType.expense,
          icon: 'print',
          color: '#9C27B0',
          sortOrder: 3),
      Category(
          id: 'exp_4',
          name: '软件订阅',
          type: FinanceType.expense,
          icon: 'computer',
          color: '#607D8B',
          sortOrder: 4),
      Category(
          id: 'exp_5',
          name: '其他支出',
          type: FinanceType.expense,
          icon: 'more_horiz',
          color: '#795548',
          sortOrder: 5),
    ];
  }
}
