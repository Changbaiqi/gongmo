// ============================================================
// 计时标签模型（data/models）
// 职责：计时标签的数据结构、4 种收入模式定义与 JSON 序列化
// 关联：WorkController（标签 CRUD/排序/结算）、StorageService（timer_tags.json）
// ============================================================

/// 计时标签：正计时开始时选择一个标签，停止时按 [incomeType] 结算收入。
///
/// 收入模式：
/// - none   纯计时，不产生账目
/// - hourly 按时薪结算：时长(小时) × hourlyRate
/// - manual 停止时弹窗让用户输入本次所得
/// - fixed  结束即按 fixedSalary 固定金额结算
class TimerTag {
  final String id;
  String name;

  /// 图标 key（对应 IconUtils.tagIcons）
  String icon;

  /// 颜色 "#RRGGBB"（界面主色与图表占比色）
  String color;

  /// 是否工作标签（与 incomeType 联动：incomeType != none）
  bool isWork;

  /// 收入模式：none=普通标签 hourly=时薪 manual=自统计 fixed=固定薪资
  String incomeType;
  double hourlyRate;
  double fixedSalary;
  int sortOrder;
  DateTime updatedAt;

  static const incomeNone = 'none';
  static const incomeHourly = 'hourly';
  static const incomeManual = 'manual';
  static const incomeFixed = 'fixed';

  TimerTag({
    required this.id,
    required this.name,
    this.icon = 'timer',
    this.color = '#2196F3',
    this.isWork = false,
    this.incomeType = incomeNone,
    this.hourlyRate = 0,
    this.fixedSalary = 0,
    this.sortOrder = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory TimerTag.fromJson(Map<String, dynamic> json) {
    final isWork = json['isWork'] as bool? ?? false;
    return TimerTag(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? 'timer',
      color: json['color'] as String? ?? '#2196F3',
      isWork: isWork,
      incomeType: json['incomeType'] as String? ??
          (isWork ? incomeHourly : incomeNone),
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 0,
      fixedSalary: (json['fixedSalary'] as num?)?.toDouble() ?? 0,
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
      'icon': icon,
      'color': color,
      'isWork': isWork,
      'incomeType': incomeType,
      'hourlyRate': hourlyRate,
      'fixedSalary': fixedSalary,
      'sortOrder': sortOrder,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 首次启动时写入的默认标签（均为纯计时，收入模式可在标签编辑中修改）
  static List<TimerTag> defaults() {
    return [
      TimerTag(
          id: 'tag_work',
          name: '工作',
          icon: 'work',
          color: '#4CAF50',
          sortOrder: 1),
      TimerTag(
          id: 'tag_rest',
          name: '休息',
          icon: 'self_improvement',
          color: '#FF9800',
          sortOrder: 2),
      TimerTag(
          id: 'tag_study',
          name: '学习',
          icon: 'school',
          color: '#2196F3',
          sortOrder: 3),
      TimerTag(
          id: 'tag_exercise',
          name: '运动',
          icon: 'fitness_center',
          color: '#E91E63',
          sortOrder: 4),
    ];
  }
}
