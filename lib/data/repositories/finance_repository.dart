import '../services/storage_service.dart';
import '../models/finance_entry.dart';

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

  double getMonthIncome() {
    final entries = getThisMonth().where((e) => e.type == FinanceType.income);
    return entries.fold(0.0, (sum, e) => sum + e.amount);
  }

  double getMonthExpense() {
    final entries = getThisMonth().where((e) => e.type == FinanceType.expense);
    return entries.fold(0.0, (sum, e) => sum + e.amount);
  }

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
