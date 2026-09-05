import 'dart:async';
import 'package:get/get.dart';
import '../../data/repositories/work_repository.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/models/work_entry.dart';
import '../../data/models/finance_entry.dart';

class DashboardController extends GetxController {
  final WorkRepository _workRepo = WorkRepository();
  final FinanceRepository _financeRepo = FinanceRepository();

  final todayWorkDuration = Duration.zero.obs;
  final todayWorkCount = 0.obs;
  final monthIncome = 0.0.obs;
  final monthExpense = 0.0.obs;
  final hasActiveTimer = false.obs;
  final activeTimerEntry = Rxn<WorkEntry>();
  final recentEntries = <dynamic>[].obs;
  final entryDates = <DateTime>{}.obs;

  Timer? _timerTick;

  @override
  void onInit() {
    super.onInit();
    refreshData();
  }

  void refreshData() {
    todayWorkDuration.value = _workRepo.getTodayTotalDuration();
    todayWorkCount.value = _workRepo.getToday().length;
    monthIncome.value = _financeRepo.getMonthIncome();
    monthExpense.value = _financeRepo.getMonthExpense();

    final active = _workRepo.getInProgress();
    if (active != null) {
      hasActiveTimer.value = true;
      activeTimerEntry.value = active;
      _startTicking();
    } else {
      hasActiveTimer.value = false;
      activeTimerEntry.value = null;
      _stopTicking();
    }

    _loadRecentEntries();
    _loadEntryDates();
  }

  void _loadRecentEntries() {
    final allWork = _workRepo.getAll();
    final allFinance = _financeRepo.getAll();

    final combined = <dynamic>[...allWork, ...allFinance];
    combined.sort((a, b) {
      final dateA = a is WorkEntry ? a.startTime : (a as FinanceEntry).date;
      final dateB = b is WorkEntry ? b.startTime : (b as FinanceEntry).date;
      return dateB.compareTo(dateA);
    });
    recentEntries.value = combined.take(10).toList();
  }

  void _loadEntryDates() {
    final dates = <DateTime>{};
    for (final w in _workRepo.getAll()) {
      dates.add(DateTime(w.startTime.year, w.startTime.month, w.startTime.day));
    }
    for (final f in _financeRepo.getAll()) {
      dates.add(DateTime(f.date.year, f.date.month, f.date.day));
    }
    entryDates.clear();
    entryDates.addAll(dates);
  }

  void _startTicking() {
    _timerTick?.cancel();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      final e = activeTimerEntry.value;
      if (e != null) {
        todayWorkDuration.value =
            _workRepo.getTodayTotalDuration() + e.liveElapsed;
      }
    });
  }

  void _stopTicking() {
    _timerTick?.cancel();
    _timerTick = null;
  }

  @override
  void onClose() {
    _stopTicking();
    super.onClose();
  }
}
