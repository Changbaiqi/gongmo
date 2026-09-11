// ============================================================
// 账目仓储（data/repositories）
// 职责：对 StorageService 的内存列表做查询封装（按日期/类型/月度汇总）
// 关联：FinanceController、自动记账（AutoBookkeepingService.processQueue）
// ============================================================

import '../services/storage_service.dart';
import '../models/finance_entry.dart';

/// 账目查询入口；写入仍委托 StorageService 落盘
class FinanceRepository {
  final StorageService _storage = StorageService();

  List<FinanceEntry> getAll() =>
      List<FinanceEntry>.from(_storage.financeEntries);

  FinanceEntry? getById(String id) {
    try {
      return _storage.financeEntries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 按发生时间取 [start, end) 区间账目；起点回退 1 秒容错
  List<FinanceEntry> getByDateRange(DateTime start, DateTime end) {
    return _storage.financeEntries.where((e) {
      return e.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          e.date.isBefore(end);
    }).toList();
  }

  List<FinanceEntry> getByType(FinanceType type) {
    return _storage.financeEntries.where((e) => e.type == type).toList();
  }

  List<FinanceEntry> getThisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return getByDateRange(start, end);
  }

  /// 本月收入合计（仅 income 类型）
  double getMonthIncome() {
    final entries = getThisMonth().where((e) => e.type == FinanceType.income);
    return entries.fold(0.0, (sum, e) => sum + e.amount);
  }

  /// 本月支出合计（仅 expense 类型）
  double getMonthExpense() {
    final entries = getThisMonth().where((e) => e.type == FinanceType.expense);
    return entries.fold(0.0, (sum, e) => sum + e.amount);
  }

  /// 保存账目：已存在则更新，否则新增（内部落盘并触发自动同步）
  void save(FinanceEntry entry) {
    final existing = getById(entry.id);
    if (existing != null) {
      _storage.updateFinanceEntry(entry);
    } else {
      _storage.addFinanceEntry(entry);
    }
  }

  void delete(String id) {
    _storage.removeFinanceEntry(id);
  }
}
