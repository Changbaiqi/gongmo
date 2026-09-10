import 'dart:async';
import 'package:get/get.dart';
import '../../data/repositories/work_repository.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/models/work_entry.dart';
import '../../data/models/finance_entry.dart';
import '../../data/services/storage_service.dart';

class DashboardController extends GetxController {
  final WorkRepository _workRepo = WorkRepository();
  final FinanceRepository _financeRepo = FinanceRepository();
  final StorageService _storage = StorageService();

  final todayWorkDuration = Duration.zero.obs;
  final todayWorkCount = 0.obs;
  final monthIncome = 0.0.obs;
  final monthExpense = 0.0.obs;
  final hasActiveTimer = false.obs;
  final activeTimerEntry = Rxn<WorkEntry>();
  final recentEntries = <dynamic>[].obs;
  final entryDates = <DateTime>{}.obs;

  /// 分类预算（categoryId -> 每月额度）
  final budgets = RxMap<String, double>();

  /// 本月各分类支出（categoryId -> 金额）
  final categoryExpense = <String, double>{}.obs;

  /// 总预算额度（0 = 未设置，自动等于各分类预算之和）
  final totalBudget = 0.0.obs;

  Timer? _timerTick;

  @override
  void onInit() {
    super.onInit();
    reloadBudgets();
    refreshData();
  }

  /// 从配置重新加载预算（云端合并/恢复后调用）
  void reloadBudgets() {
    budgets.clear();
    final rawBudgets = StorageService().getConfig('budgets');
    if (rawBudgets is Map) {
      for (final e in rawBudgets.entries) {
        final v = double.tryParse('${e.value}');
        if (v != null && v > 0) budgets['${e.key}'] = v;
      }
    }
    final tb = StorageService().getConfig('total_budget');
    totalBudget.value = tb is num ? tb.toDouble() : 0;
  }

  /// 已分配的分类子预算之和
  double get allocatedBudget => budgets.values.fold(0.0, (s, v) => s + v);

  /// 生效的总预算额度：未手动设置时自动等于分类预算之和
  double get totalBudgetAmount =>
      totalBudget.value > 0 ? totalBudget.value : allocatedBudget;

  /// "其他"（未设子预算分类）的可用额度（仅手动设置总预算后有意义）
  double get otherBudgetAmount {
    if (totalBudget.value <= 0) return 0;
    final v = totalBudget.value - allocatedBudget;
    return v > 0 ? v : 0;
  }

  /// "其他"分类的本月支出
  double get otherUsedAmount {
    final budgetedUsed =
        budgets.keys.fold(0.0, (s, id) => s + (categoryExpense[id] ?? 0));
    final v = monthExpense.value - budgetedUsed;
    return v > 0 ? v : 0;
  }

  /// 设置某分类的每月预算（amount <= 0 表示删除该预算）
  void setBudgetFor(String categoryId, double amount) {
    if (amount <= 0) {
      budgets.remove(categoryId);
    } else {
      budgets[categoryId] = amount;
    }
    StorageService().setDataConfig('budgets', Map<String, dynamic>.from(budgets));
  }

  /// 设置总预算（0 表示清除，自动回落为分类预算之和）
  void setTotalBudget(double v) {
    totalBudget.value = v;
    StorageService().setDataConfig('total_budget', v);
  }

  /// 恢复云端备份中的预算配置
  void restoreBudgets(Map<String, double> budgets, double total) {
    this.budgets.assignAll(budgets);
    totalBudget.value = total;
    StorageService()
      ..setDataConfig('total_budget', total)
      ..setDataConfig('budgets', Map<String, dynamic>.from(budgets));
  }

  void refreshData() {
    todayWorkDuration.value = _workRepo.getTodayTotalDuration();
    todayWorkCount.value = _workRepo.getToday().length;
    monthIncome.value = _financeRepo.getMonthIncome();
    monthExpense.value = _financeRepo.getMonthExpense();

    // 本月各分类支出（用于分类预算进度）
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final catExp = <String, double>{};
    for (final e in _financeRepo.getAll()) {
      if (e.type == FinanceType.expense &&
          !e.date.isBefore(monthStart) &&
          e.date.isBefore(nextMonth)) {
        catExp[e.categoryId] = (catExp[e.categoryId] ?? 0) + e.amount;
      }
    }
    categoryExpense
      ..clear()
      ..addAll(catExp);

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
