import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/date_utils.dart';
import '../../data/repositories/work_repository.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/services/storage_service.dart';
import '../../data/models/work_entry.dart';
import '../../data/models/finance_entry.dart';
import '../../data/models/timer_tag.dart';
import '../dashboard/dashboard_controller.dart';
import '../finance/finance_controller.dart';

class WorkController extends GetxController {
  final WorkRepository _workRepo = WorkRepository();
  final FinanceRepository _financeRepo = FinanceRepository();
  final StorageService _storage = StorageService();
  final _uuid = const Uuid();

  final entries = <WorkEntry>[].obs;
  final isTimerRunning = false.obs;
  final isPaused = false.obs;
  final currentTimerTag = Rxn<TimerTag>();
  final currentTimerEntry = Rxn<WorkEntry>();
  final elapsedSeconds = 0.obs;

  /// 标签列表版本号：增删/排序/编辑后自增，驱动标签栏刷新
  final tagsRevision = 0.obs;

  void notifyTagsChanged() {
    tagsRevision.value++;
    update();
  }

  final isClockedIn = false.obs;
  final clockInTime = Rxn<DateTime>();
  final clockEntry = Rxn<WorkEntry>();
  final todayClockDuration = Duration.zero.obs;

  List<TimerTag> get tags => _storage.timerTags;

  Timer? _timer;
  TimerTag? _selectedTag;

  @override
  void onInit() {
    super.onInit();
    _selectedTag = tags.isNotEmpty ? tags.first : null;
    currentTimerTag.value = _selectedTag;
    loadEntries();
    _checkActiveTimer();
  }

  void selectTag(TimerTag tag) {
    if (isTimerRunning.value) return;
    _selectedTag = tag;
    currentTimerTag.value = tag;
  }

  void startTimer() {
    if (isTimerRunning.value || isClockedIn.value) return;
    final tag = _selectedTag;
    if (tag == null) return;

    final entry = WorkEntry(
      id: _uuid.v4(),
      startTime: DateTime.now(),
      projectName: tag.name,
      hourlyRate: tag.isWork ? tag.hourlyRate : 0,
      description: tag.name,
      status: WorkStatus.inProgress,
    );
    _workRepo.save(entry);

    isTimerRunning.value = true;
    isPaused.value = false;
    currentTimerEntry.value = entry;
    _startTick();
    loadEntries();
    _refreshDashboard();
  }

  void stopTimer() {
    if (!isTimerRunning.value || currentTimerEntry.value == null) return;

    final entry = currentTimerEntry.value!;
    final tag = _selectedTag;
    final endTime = DateTime.now();
    final duration = entry.liveElapsed;
    final hours = duration.inSeconds / 3600.0;
    final incomeType = tag?.incomeType ?? TimerTag.incomeNone;

    double? income;
    if (incomeType == TimerTag.incomeHourly && tag!.hourlyRate > 0) {
      income = hours * tag.hourlyRate;
    } else if (incomeType == TimerTag.incomeFixed && tag!.fixedSalary > 0) {
      income = tag.fixedSalary;
    }

    final updated = entry.copyWith(
      endTime: endTime,
      status: WorkStatus.completed,
      income: income,
      clearPausedAt: true,
    );
    _workRepo.save(updated);

    if (income != null && income > 0) {
      _saveIncome(income, tag?.name ?? '工时', entry.id);
    }

    _timer?.cancel();
    _timer = null;
    isTimerRunning.value = false;
    isPaused.value = false;
    currentTimerEntry.value = null;
    elapsedSeconds.value = 0;
    loadEntries();
    _refreshDashboard();
    _refreshFinance();

    // 自统计：计时结束后弹窗录入本次所得
    if (incomeType == TimerTag.incomeManual && tag != null) {
      _promptManualIncome(updated, tag);
    }
  }

  void _saveIncome(double amount, String tagName, String workEntryId) {
    _financeRepo.save(FinanceEntry(
      id: _uuid.v4(),
      type: FinanceType.income,
      amount: amount,
      categoryId: 'inc_1',
      description: '工作计时: $tagName',
      workEntryId: workEntryId,
      date: DateTime.now(),
    ));
  }

  /// 自统计标签：结束后由用户手动输入这段时间的所得
  void _promptManualIncome(WorkEntry entry, TimerTag tag) {
    final amountCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text('自统计收入'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '「${tag.name}」本次计时 ${DateHelper.formatDuration(entry.duration ?? Duration.zero)}，请输入这段时间的所得金额：',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '本次所得 (¥)',
                prefixText: '¥ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('跳过'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text);
              if (amount == null || amount <= 0) {
                Get.snackbar('提示', '请输入有效金额');
                return;
              }
              _workRepo.save(entry.copyWith(income: amount));
              _saveIncome(amount, tag.name, entry.id);
              _refreshFinance();
              _refreshDashboard();
              Get.back();
              Get.snackbar('已记录', '本次所得 ¥${amount.toStringAsFixed(2)}');
            },
            child: const Text('记录'),
          ),
        ],
      ),
    );
  }

  /// 暂停计时：冻结显示，累计已计时长并持久化
  void pauseTimer() {
    if (!isTimerRunning.value || isPaused.value) return;
    final entry = currentTimerEntry.value;
    if (entry == null) return;
    final now = DateTime.now();
    final updated = entry.copyWith(
      accumulatedSeconds:
          entry.accumulatedSeconds + now.difference(entry.startTime).inSeconds,
      pausedAt: now,
    );
    _workRepo.save(updated);
    currentTimerEntry.value = updated;
    _timer?.cancel();
    _timer = null;
    isPaused.value = true;
  }

  /// 继续计时：从暂停时刻开启新分段
  void resumeTimer() {
    if (!isTimerRunning.value || !isPaused.value) return;
    final entry = currentTimerEntry.value;
    if (entry == null) return;
    final updated = entry.copyWith(
      startTime: DateTime.now(),
      clearPausedAt: true,
    );
    _workRepo.save(updated);
    currentTimerEntry.value = updated;
    isPaused.value = false;
    _startTick();
  }

  void _startTick() {
    _timer?.cancel();
    void tick() {
      final e = currentTimerEntry.value;
      if (e != null) {
        elapsedSeconds.value = e.liveElapsed.inSeconds;
      }
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    tick();
  }

  void _checkActiveTimer() {
    final active = _workRepo.getInProgress();
    if (active != null) {
      isTimerRunning.value = true;
      currentTimerEntry.value = active;

      if (active.mode == 'clock') {
        isClockedIn.value = true;
        clockInTime.value = active.startTime;
        clockEntry.value = active;
        try {
          _selectedTag = tags.firstWhere((t) => t.name == active.projectName);
          currentTimerTag.value = _selectedTag;
        } catch (_) {}
        _startTick();
        return;
      }

      final tagName = active.projectName;
      try {
        _selectedTag = tags.firstWhere((t) => t.name == tagName);
        currentTimerTag.value = _selectedTag;
      } catch (_) {
        currentTimerTag.value = null;
      }
      if (active.pausedAt != null) {
        isPaused.value = true;
        elapsedSeconds.value = active.liveElapsed.inSeconds;
      } else {
        isPaused.value = false;
        _startTick();
      }
    }
  }

  void clockIn() {
    if (isClockedIn.value || isTimerRunning.value) return;

    final tag = _selectedTag;
    final entry = WorkEntry(
      id: _uuid.v4(),
      startTime: DateTime.now(),
      projectName: tag?.name ?? '打卡',
      description: '打卡',
      hourlyRate: 0,
      status: WorkStatus.inProgress,
      mode: 'clock',
    );
    _workRepo.save(entry);

    isClockedIn.value = true;
    clockInTime.value = entry.startTime;
    clockEntry.value = entry;
    _startTick();
    loadEntries();
    _refreshDashboard();
  }

  void clockOut() {
    if (!isClockedIn.value || clockEntry.value == null) return;

    final entry = clockEntry.value!;
    final endTime = DateTime.now();

    final updated = entry.copyWith(
      endTime: endTime,
      status: WorkStatus.completed,
      description: '结束打卡',
    );
    _workRepo.save(updated);

    _timer?.cancel();
    _timer = null;
    isClockedIn.value = false;
    clockEntry.value = null;
    elapsedSeconds.value = 0;

    _updateTodayClockDuration();
    loadEntries();
    _refreshDashboard();
  }

  void _updateTodayClockDuration() {
    final today = _workRepo.getToday().where(
        (e) => e.mode == 'clock' && e.status == WorkStatus.completed);
    final dur = today.fold(
        Duration.zero, (sum, e) => sum + (e.duration ?? Duration.zero));
    todayClockDuration.value = dur;
  }

  void loadEntries() {
    entries.value = _workRepo.getAll();
    entries.sort((a, b) => b.startTime.compareTo(a.startTime));
    _updateTodayClockDuration();
  }

  void deleteEntry(String id) {
    _workRepo.delete(id);
    loadEntries();
    _refreshDashboard();
  }

  void addTag(
    String name, {
    String icon = 'timer',
    String incomeType = TimerTag.incomeNone,
    double hourlyRate = 0,
    double fixedSalary = 0,
  }) {
    final tag = TimerTag(
      id: _uuid.v4(),
      name: name,
      icon: icon,
      isWork: incomeType != TimerTag.incomeNone,
      incomeType: incomeType,
      hourlyRate: incomeType == TimerTag.incomeHourly ? hourlyRate : 0,
      fixedSalary: incomeType == TimerTag.incomeFixed ? fixedSalary : 0,
      sortOrder: tags.length + 1,
    );
    _storage.addTimerTag(tag);
    notifyTagsChanged();
  }

  void removeTag(String id) {
    if (tags.length <= 1) return;
    _storage.removeTimerTag(id);
    if (_selectedTag?.id == id) {
      _selectedTag = tags.isNotEmpty ? tags.first : null;
      currentTimerTag.value = _selectedTag;
    }
    notifyTagsChanged();
  }

  /// 调整标签顺序（管理弹窗拖动排序）
  void reorderTag(int oldIndex, int newIndex) {
    final list = _storage.timerTags;
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex > list.length - 1) return;
    final tag = list.removeAt(oldIndex);
    list.insert(newIndex, tag);
    for (var i = 0; i < list.length; i++) {
      list[i].sortOrder = i + 1;
    }
    _storage.saveTimerTags();
    notifyTagsChanged();
  }

  String get formattedElapsed {
    final h = elapsedSeconds.value ~/ 3600;
    final m = (elapsedSeconds.value % 3600) ~/ 60;
    final s = elapsedSeconds.value % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Duration get todayTagDuration {
    if (_selectedTag == null) return Duration.zero;
    final today = _workRepo.getToday().where((e) =>
        e.status == WorkStatus.completed &&
        e.projectName == _selectedTag!.name);
    return today.fold(
        Duration.zero, (sum, e) => sum + (e.duration ?? Duration.zero));
  }

  void _refreshDashboard() {
    try {
      Get.find<DashboardController>(tag: 'dashboard').refreshData();
    } catch (_) {}
  }

  void _refreshFinance() {
    try {
      Get.find<FinanceController>().loadEntries();
    } catch (_) {}
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
