class Account {
  final String id;
  String name;
  double initialBalance;
  DateTime createdAt;

  Account({
    required this.id,
    required this.name,
    this.initialBalance = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      initialBalance: (json['initialBalance'] as num?)?.toDouble() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'initialBalance': initialBalance,
      'createdAt': createdAt.toIso8601String(),
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
