class Account {
  final String id;
  String name;
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

  static List<Account> defaultAccounts() {
    return [
      Account(id: 'acc_1', name: '现金'),
      Account(id: 'acc_2', name: '支付宝'),
      Account(id: 'acc_3', name: '微信支付'),
      Account(id: 'acc_4', name: '银行卡'),
    ];
  }
}
