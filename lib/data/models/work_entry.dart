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

  /// 暂停前已累计的秒数（不含当前进行中的分段）
  int accumulatedSeconds;

  /// 非空表示当前处于暂停状态，值为暂停时刻
  DateTime? pausedAt;

  /// 会话模式：timer=正计时 clock=打卡（旧数据按名称推断）
  String mode;

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
    this.accumulatedSeconds = 0,
    this.pausedAt,
    this.mode = 'timer',
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 已结束记录的总时长（含暂停前累计）
  Duration? get duration {
    if (endTime != null) {
      return Duration(seconds: accumulatedSeconds) +
          endTime!.difference(startTime);
    }
    return null;
  }

  /// 进行中记录的实时时长（暂停时冻结）
  Duration get liveElapsed {
    final base = Duration(seconds: accumulatedSeconds);
    if (pausedAt != null) return base;
    return base + DateTime.now().difference(startTime);
  }

  factory WorkEntry.fromJson(Map<String, dynamic> json) {
    final name = json['projectName'] as String? ?? '';
    return WorkEntry(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      projectName: name,
      description: json['description'] as String? ?? '',
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 0,
      income: (json['income'] as num?)?.toDouble(),
      financeEntryId: json['financeEntryId'] as String?,
      status: WorkStatus.values[json['status'] as int? ?? 0],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      accumulatedSeconds: (json['accumulatedSeconds'] as num?)?.toInt() ?? 0,
      pausedAt: json['pausedAt'] != null
          ? DateTime.parse(json['pausedAt'] as String)
          : null,
      mode: json['mode'] as String? ?? (name == '打卡' ? 'clock' : 'timer'),
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
      'accumulatedSeconds': accumulatedSeconds,
      'pausedAt': pausedAt?.toIso8601String(),
      'mode': mode,
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
    int? accumulatedSeconds,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    String? mode,
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
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      mode: mode ?? this.mode,
    );
  }
}
