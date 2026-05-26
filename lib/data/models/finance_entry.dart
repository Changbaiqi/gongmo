enum FinanceType { income, expense, transfer }

class FinanceEntry {
  final String id;
  FinanceType type;
  double amount;
  String categoryId;
  String description;
  String? workEntryId;
  String? accountId;
  String? notificationSrc;
  DateTime date;
  DateTime createdAt;
  DateTime updatedAt;
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
