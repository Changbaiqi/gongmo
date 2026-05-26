import '../services/storage_service.dart';
import '../models/work_entry.dart';

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

  WorkEntry? getInProgress() {
    try {
      return _storage.workEntries.firstWhere(
        (e) => e.status == WorkStatus.inProgress,
      );
    } catch (_) {
      return null;
    }
  }

  Duration getTodayTotalDuration() {
    final entries = getToday().where((e) => e.status == WorkStatus.completed);
    return entries.fold(Duration.zero, (sum, e) {
      final d = e.duration;
      return sum + (d ?? Duration.zero);
    });
  }

  Duration getMonthTotalDuration() {
    final entries =
        getThisMonth().where((e) => e.status == WorkStatus.completed);
    return entries.fold(Duration.zero, (sum, e) {
      final d = e.duration;
      return sum + (d ?? Duration.zero);
    });
  }

  double getMonthTotalIncome() {
    final entries =
        getThisMonth().where((e) => e.status == WorkStatus.completed);
    return entries.fold(0.0, (sum, e) => sum + (e.income ?? 0));
  }

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
