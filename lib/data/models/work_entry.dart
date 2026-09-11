// ============================================================
// 工时记录模型（data/models）
// 职责：正计时/打卡记录的数据结构、JSON 序列化与时长计算
// 关联：StorageService（按年分片持久化 work_entries_{年}.json）、
//       WorkController（创建/更新）、WorkStatsController（统计）
// ============================================================

/// 记录状态。
/// inProgress=进行中（设计上同时最多一条）；completed=已完成；
/// settled=已结算（预留历史状态，当前流程结束时直接置 completed）
enum WorkStatus { inProgress, completed, settled }

/// 一条工时/打卡记录。
///
/// 计时采用“分段累计”以支持暂停：暂停时把已计时长累加进
/// [accumulatedSeconds]，继续时重置 [startTime]，因此总时长
/// 始终 = accumulatedSeconds + (endTime - startTime)。
class WorkEntry {
  final String id;
  DateTime startTime;
  DateTime? endTime;

  /// 标签名；打卡记录为打卡时选中的标签名，缺省 "打卡"
  String projectName;

  /// 备注
  String description;

  /// 计时时使用的标签时薪（结算/展示用）
  double hourlyRate;

  /// 结算后的收入；null 表示不计薪或尚未结算
  double? income;

  /// 关联的收入账目 id（停止计时并生成账目后回填）
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

  /// 反序列化；旧数据没有 mode 字段时，按名称是否为 "打卡" 推断
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

  /// 复制并修改字段；[clearPausedAt] 用于显式清除暂停态
  /// （普通可空参数传 null 时会保留原值，无法表达“置空”）
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
