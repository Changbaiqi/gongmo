enum WorkStatus { inProgress, completed, settled }

class WorkEntry {
  final String id;
  DateTime startTime;
  DateTime? endTime;
  String projectName;
  String description;
  double hourlyRate;
  double? income;
  String? financeEntryId;
  WorkStatus status;
  DateTime createdAt;
  DateTime updatedAt;

  WorkEntry({
    required this.id,
    required this.startTime,
    this.endTime,
    this.projectName = '',
    this.description = '',
    this.hourlyRate = 0,
    this.income,
    this.financeEntryId,
    this.status = WorkStatus.inProgress,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Duration? get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return null;
  }

  factory WorkEntry.fromJson(Map<String, dynamic> json) {
    return WorkEntry(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      projectName: json['projectName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 0,
      income: (json['income'] as num?)?.toDouble(),
      financeEntryId: json['financeEntryId'] as String?,
      status: WorkStatus.values[json['status'] as int? ?? 0],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'projectName': projectName,
      'description': description,
      'hourlyRate': hourlyRate,
      'income': income,
      'financeEntryId': financeEntryId,
      'status': status.index,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  WorkEntry copyWith({
    DateTime? startTime,
    DateTime? endTime,
    String? projectName,
    String? description,
    double? hourlyRate,
    double? income,
    String? financeEntryId,
    WorkStatus? status,
  }) {
    return WorkEntry(
      id: id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      projectName: projectName ?? this.projectName,
      description: description ?? this.description,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      income: income ?? this.income,
      financeEntryId: financeEntryId ?? this.financeEntryId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
