// ============================================================
// 账目模型（data/models）
// 职责：一笔收入/支出的数据结构、JSON 序列化
// 关联：StorageService（按年分片持久化 finance_entries_{年}.json）、
//       FinanceController（增删改）、StatsController（统计）
// ============================================================

/// 账目类型；transfer=转账（预留，当前 UI 仅支持收入/支出）
enum FinanceType { income, expense, transfer }

/// 一条账目。
///
/// 与工时记录的关联：计时结算生成收入账目时会回填 [workEntryId]；
/// 自动记账生成账目时会回填 [notificationSrc]。
class FinanceEntry {
  final String id;
  FinanceType type;
  double amount;

  /// 分类 id（内置 inc_*/exp_* 或自定义 cus_*）
  String categoryId;

  /// 备注；为空时界面回退显示分类名
  String description;

  /// 关联的工时记录 id（计时结算生成时回填）
  String? workEntryId;

  /// 关联账户 id（字段预留，当前记账表单未使用）
  String? accountId;

  /// 自动记账来源（alipay/wechat/cmb），非空表示「自动」条目
  String? notificationSrc;

  /// 账目发生时间（按此字段归属年月与统计）
  DateTime date;
  DateTime createdAt;
  DateTime updatedAt;

  /// 预留标签列表
  List<String> tags;

  FinanceEntry({
    required this.id,
    required this.type,
    required this.amount,
    this.categoryId = '',
    this.description = '',
    this.workEntryId,
    this.accountId,
    this.notificationSrc,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
  })  : date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        tags = tags ?? [];

  factory FinanceEntry.fromJson(Map<String, dynamic> json) {
    return FinanceEntry(
      id: json['id'] as String,
      type: FinanceType.values[json['type'] as int? ?? 0],
      amount: (json['amount'] as num).toDouble(),
      categoryId: json['categoryId'] as String? ?? '',
      description: json['description'] as String? ?? '',
      workEntryId: json['workEntryId'] as String?,
      accountId: json['accountId'] as String?,
      notificationSrc: json['notificationSrc'] as String?,
      date: DateTime.parse(json['date'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'amount': amount,
      'categoryId': categoryId,
      'description': description,
      'workEntryId': workEntryId,
      'accountId': accountId,
      'notificationSrc': notificationSrc,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': tags,
    };
  }

  FinanceEntry copyWith({
    FinanceType? type,
    double? amount,
    String? categoryId,
    String? description,
    String? workEntryId,
    String? accountId,
    String? notificationSrc,
    DateTime? date,
    List<String>? tags,
  }) {
    return FinanceEntry(
      id: id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      workEntryId: workEntryId ?? this.workEntryId,
      accountId: accountId ?? this.accountId,
      notificationSrc: notificationSrc ?? this.notificationSrc,
      date: date ?? this.date,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      tags: tags ?? this.tags,
    );
  }
}
