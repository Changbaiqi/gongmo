// ============================================================
// 支付账户模型（data/models）
// 职责：账户（现金/支付宝等）的数据结构与 JSON 序列化
// 关联：StorageService（accounts.json）、多设备合并（按 updatedAt 取新）
// 说明：当前主要作为默认数据保留，记账表单尚未选择账户
// ============================================================

/// 支付账户
class Account {
  final String id;
  String name;

  /// 初始余额（预留）
  double initialBalance;
  DateTime createdAt;
  DateTime updatedAt;

  Account({
    required this.id,
    required this.name,
    this.initialBalance = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      initialBalance: (json['initialBalance'] as num?)?.toDouble() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
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
      'initialBalance': initialBalance,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 首次启动时写入的默认账户
  static List<Account> defaultAccounts() {
    return [
      Account(id: 'acc_1', name: '现金'),
      Account(id: 'acc_2', name: '支付宝'),
      Account(id: 'acc_3', name: '微信支付'),
      Account(id: 'acc_4', name: '银行卡'),
    ];
  }
}
