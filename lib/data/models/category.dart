// ============================================================
// 收支分类模型（data/models）
// 职责：分类的数据结构、JSON 序列化与首次启动的默认分类
// 关联：FinanceController（分类 CRUD/排序）、StorageService（categories.json）
// ============================================================

import 'finance_entry.dart';

/// 收支分类。
///
/// id 规则：内置分类为 inc_*/exp_*，用户新建为 cus_*；
/// [updatedAt] 参与多设备合并（取较新版本），因此所有修改都应刷新该字段。
class Category {
  final String id;
  String name;
  FinanceType type;

  /// 图标 key（对应 IconUtils.category）
  String icon;

  /// 颜色 "#RRGGBB"（对应 IconUtils.hex）
  String color;

  /// 排序号（同类型内升序显示）
  int sortOrder;
  DateTime updatedAt;

  Category({
    required this.id,
    required this.name,
    required this.type,
    this.icon = '',
    this.color = '#2196F3',
    this.sortOrder = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// 反序列化；缺失/损坏的 updatedAt 回退为 epoch 0，
  /// 使旧数据在合并时被视为“最旧版本”，让新版本优先
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      type: FinanceType.values[json['type'] as int? ?? 0],
      icon: json['icon'] as String? ?? '',
      color: json['color'] as String? ?? '#2196F3',
      sortOrder: json['sortOrder'] as int? ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ??
              DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
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
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Category copyWith({
    String? name,
    FinanceType? type,
    String? icon,
    String? color,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 首次启动时写入的默认收入分类（项目/咨询/其他）
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

  /// 首次启动时写入的默认支出分类（餐饮/交通/办公用品/软件订阅/其他）
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
