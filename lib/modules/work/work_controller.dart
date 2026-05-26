import 'dart:async';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/work_repository.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/services/storage_service.dart';
import '../../data/models/work_entry.dart';
import '../../data/models/finance_entry.dart';
import '../../data/models/timer_tag.dart';
import '../dashboard/dashboard_controller.dart';

class WorkController extends GetxController {
  final WorkRepository _workRepo = WorkRepository();
  final FinanceRepository _financeRepo = FinanceRepository();
  final StorageService _storage = StorageService();
  final _uuid = const Uuid();

  final entries = <WorkEntry>[].obs;
  final isTimerRunning = false.obs;
  final currentTimerTag = Rxn<TimerTag>();
  final currentTimerEntry = Rxn<WorkEntry>();
  final elapsedSeconds = 0.obs;

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
    if (isTimerRunning.value) return;
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
    currentTimerEntry.value = entry;
    _startTick(entry.startTime);
    loadEntries();
    _refreshDashboard();
  }

  void stopTimer() {
    if (!isTimerRunning.value || currentTimerEntry.value == null) return;

    final entry = currentTimerEntry.value!;
    final tag = _selectedTag;
    final endTime = DateTime.now();
    final duration = endTime.difference(entry.startTime);
    final hours = duration.inSeconds / 3600.0;

    double? income;
    if (tag != null && tag.isWork && tag.hourlyRate > 0) {
      income = hours * tag.hourlyRate;
    }

    final updated = entry.copyWith(
      endTime: endTime,
      status: WorkStatus.completed,
      income: income,
    );
    _workRepo.save(updated);

    if (income != null && income > 0) {
      final financeEntry = FinanceEntry(
        id: _uuid.v4(),
        type: FinanceType.income,
        amount: income,
        categoryId: 'inc_1',
        description: '工作计时: ${tag?.name ?? "工时"}',
        workEntryId: entry.id,
        date: DateTime.now(),
      );
      _financeRepo.save(financeEntry);
    }

    _timer?.cancel();
    _timer = null;
    isTimerRunning.value = false;
    currentTimerEntry.value = null;
    elapsedSeconds.value = 0;
    loadEntries();
    _refreshDashboard();
  }

  void _startTick(DateTime start) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds.value = DateTime.now().difference(start).inSeconds;
    });
    elapsedSeconds.value = DateTime.now().difference(start).inSeconds;
  }

  void _checkActiveTimer() {
    final active = _workRepo.getInProgress();
    if (active != null) {
      isTimerRunning.value = true;
      currentTimerEntry.value = active;
      final tagName = active.projectName;
      try {
        _selectedTag = tags.firstWhere((t) => t.name == tagName);
        currentTimerTag.value = _selectedTag;
      } catch (_) {
        currentTimerTag.value = null;
      }
      _startTick(active.startTime);
    }
  }

  void loadEntries() {
    entries.value = _workRepo.getAll();
    entries.sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  void deleteEntry(String id) {
    _workRepo.delete(id);
    loadEntries();
    _refreshDashboard();
  }

  void addTag(String name, {bool isWork = false, double hourlyRate = 0}) {
    final tag = TimerTag(
      id: _uuid.v4(),
      name: name,
      isWork: isWork,
      hourlyRate: hourlyRate,
      sortOrder: tags.length + 1,
    );
    _storage.addTimerTag(tag);
    update();
  }

  void removeTag(String id) {
    if (tags.length <= 1) return;
    _storage.removeTimerTag(id);
    if (_selectedTag?.id == id) {
      _selectedTag = tags.isNotEmpty ? tags.first : null;
      currentTimerTag.value = _selectedTag;
    }
    update();
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

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
