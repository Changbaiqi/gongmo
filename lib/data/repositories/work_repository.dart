// ============================================================
// 工时仓储（data/repositories）
// 职责：对 StorageService 的内存列表做查询封装（按范围/日期/进行中聚合）
// 关联：WorkController、WorkStatsController；写入仍委托 StorageService 落盘
// ============================================================

import '../services/storage_service.dart';
import '../models/work_entry.dart';

/// 工时记录查询入口；无独立缓存，直接读取 StorageService 内存数据
class WorkRepository {
  final StorageService _storage = StorageService();

  List<WorkEntry> getAll() => List<WorkEntry>.from(_storage.workEntries);

  WorkEntry? getById(String id) {
    try {
      return _storage.workEntries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 按开始时间取 [start, end) 区间记录；
  /// 起点回退 1 秒做容错，避免毫秒误差把恰好在起点的记录排除
  List<WorkEntry> getByDateRange(DateTime start, DateTime end) {
    return _storage.workEntries.where((e) {
      return e.startTime.isAfter(start.subtract(const Duration(seconds: 1))) &&
          e.startTime.isBefore(end);
    }).toList();
  }

  List<WorkEntry> getToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return getByDateRange(start, end);
  }

  List<WorkEntry> getThisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return getByDateRange(start, end);
  }

  /// 当前进行中的记录（设计上同时最多一条），没有则返回 null
  WorkEntry? getInProgress() {
    try {
      return _storage.workEntries.firstWhere(
        (e) => e.status == WorkStatus.inProgress,
      );
    } catch (_) {
      return null;
    }
  }

  /// 今日完成记录的总时长（不含进行中记录；打卡记录也计入）
  Duration getTodayTotalDuration() {
    final entries = getToday().where((e) => e.status == WorkStatus.completed);
    return entries.fold(Duration.zero, (sum, e) {
      final d = e.duration;
      return sum + (d ?? Duration.zero);
    });
  }

  /// 本月完成记录的总时长
  Duration getMonthTotalDuration() {
    final entries =
        getThisMonth().where((e) => e.status == WorkStatus.completed);
    return entries.fold(Duration.zero, (sum, e) {
      final d = e.duration;
      return sum + (d ?? Duration.zero);
    });
  }

  /// 本月工时结算收入合计
  double getMonthTotalIncome() {
    final entries =
        getThisMonth().where((e) => e.status == WorkStatus.completed);
    return entries.fold(0.0, (sum, e) => sum + (e.income ?? 0));
  }

  /// 保存记录：已存在则更新，否则新增（内部落盘并触发自动同步）
  void save(WorkEntry entry) {
    final existing = getById(entry.id);
    if (existing != null) {
      _storage.updateWorkEntry(entry);
    } else {
      _storage.addWorkEntry(entry);
    }
  }

  void delete(String id) {
    _storage.removeWorkEntry(id);
  }
}
