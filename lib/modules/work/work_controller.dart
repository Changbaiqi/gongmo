// ============================================================
// work_controller.dart（工时模块 · 计时核心状态机）
// 职责：正计时/打卡的开始、暂停、继续、停止与收入结算，以及标签管理、记录增删改
// 关联：WorkRepository/FinanceRepository 读写数据，StorageService 负责落盘（触发云备份防抖）；
//       数据变化后刷新 DashboardController 与 FinanceController；被 WorkPage 等页面使用
// ============================================================
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

/// 工时计时核心控制器（GetX 依赖注入，随 WorkPage 的 `Get.put` 创建并常驻）
///
/// 管理两条互斥的计时线：
/// - 正计时：开始/暂停/继续/停止，停止时按标签收入模式结算并写入财务账目；
/// - 打卡：上/下班打卡，只累计时长，不产生收入账目。
///
/// 另外负责标签增删改/排序、计时记录列表的加载与编辑删除。
/// 计时采用分段累计：运行中 `startTime` 为当前分段起点，暂停时把
/// `now - startTime` 累加进 `accumulatedSeconds`（见 WorkEntry）。
class WorkController extends GetxController {
  final WorkRepository _workRepo = WorkRepository(); // 计时记录读写
  final FinanceRepository _financeRepo = FinanceRepository(); // 收入账目写入
  final StorageService _storage = StorageService(); // 标签配置的持久化出口
  final _uuid = const Uuid(); // 生成记录/标签唯一 id

  final entries = <WorkEntry>[].obs; // 全部记录（按开始时间倒序）
  final isTimerRunning = false.obs; // 正计时进行中
  final isPaused = false.obs; // 正计时处于暂停
  final currentTimerTag = Rxn<TimerTag>(); // 当前选中的标签
  final currentTimerEntry = Rxn<WorkEntry>(); // 进行中的记录（暂停/恢复现场）
  final elapsedSeconds = 0.obs; // 计时牌显示的已计秒数

  /// 标签列表版本号：增删/排序/编辑后自增，驱动标签栏刷新
  final tagsRevision = 0.obs;

  /// 标签变更后调用：自增版本号并 `update()`，驱动依赖它的界面（标签栏等）刷新
  void notifyTagsChanged() {
    tagsRevision.value++;
    update();
  }

  final isClockedIn = false.obs; // 是否已上班打卡
  final clockInTime = Rxn<DateTime>(); // 本次上班打卡时刻
  final clockEntry = Rxn<WorkEntry>(); // 进行中的打卡记录
  final todayClockDuration = Duration.zero.obs; // 今日已完成打卡总时长

  List<TimerTag> get tags => _storage.timerTags;

  Timer? _timer; // 秒级 tick，驱动 elapsedSeconds
  TimerTag? _selectedTag; // 与 currentTimerTag 同步的普通变量，便于同步读取

  @override
  void onInit() {
    super.onInit();
    _selectedTag = tags.isNotEmpty ? tags.first : null;
    currentTimerTag.value = _selectedTag;
    loadEntries();
    // 应用被杀/页面重建后，恢复尚未结束的计时或打卡
    _checkActiveTimer();
  }

  /// 选择计时标签（计时进行中禁止切换，避免记录归属混乱）
  void selectTag(TimerTag tag) {
    if (isTimerRunning.value) return;
    _selectedTag = tag;
    currentTimerTag.value = tag;
  }

  /// 开始正计时：生成一条 inProgress 记录并启动秒级 tick
  ///
  /// 与打卡互斥：打卡进行中或本身已在计时则直接忽略。
  /// 标签的收入模式只决定停止时的结算方式，开始时不预生成账目。
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

  /// 停止正计时：落库为 completed，并按标签收入模式结算
  ///
  /// 四种模式：
  /// - none：不产生收入；
  /// - hourly：时长(小时) × 时薪，写入收入账目；
  /// - fixed：固定薪资，写入收入账目；
  /// - manual：先结束，再弹窗让用户输入本次所得（见 `_promptManualIncome`）。
  /// 同时会刷新首页看板与财务列表。
  void stopTimer() {
    if (!isTimerRunning.value || currentTimerEntry.value == null) return;

    final entry = currentTimerEntry.value!;
    final tag = _selectedTag;
    final endTime = DateTime.now();
    // liveElapsed 已合并暂停分段累计的时长
    final duration = entry.liveElapsed;
    final hours = duration.inSeconds / 3600.0;
    final incomeType = tag?.incomeType ?? TimerTag.incomeNone;

    // 自动结算的两种模式（manual 延后到弹窗里处理）
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
      clearPausedAt: true, // 结束后不再保留暂停标记
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

    // 自统计：停止动作先完成，再弹窗录入本次所得（弹窗取消则本条记录无收入）
    if (incomeType == TimerTag.incomeManual && tag != null) {
      _promptManualIncome(updated, tag);
    }
  }

  /// 生成一条收入账目，并通过 `workEntryId` 与计时记录互相追溯
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
              // 把金额补写到该条记录，再生成关联的收入账目
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

  /// 暂停计时：冻结显示，把当前分段时长累加进 `accumulatedSeconds` 并持久化
  ///
  /// 分段累计的原因：计时可能多次暂停/继续，不能只用一个固定起始时间，
  /// 每次继续都会把 `startTime` 重置为新的分段起点。
  void pauseTimer() {
    if (!isTimerRunning.value || isPaused.value) return;
    final entry = currentTimerEntry.value;
    if (entry == null) return;
    final now = DateTime.now();
    final updated = entry.copyWith(
      accumulatedSeconds:
          entry.accumulatedSeconds + now.difference(entry.startTime).inSeconds,
      pausedAt: now, // 标记暂停，恢复时清除
    );
    _workRepo.save(updated);
    currentTimerEntry.value = updated;
    _timer?.cancel();
    _timer = null;
    isPaused.value = true;
  }

  /// 继续计时：重置 `startTime` 为新的分段起点并清除暂停标记
  ///
  /// 此前的分段时长已保存在 `accumulatedSeconds` 中，不会丢失。
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

  /// 启动秒级 tick：每秒把记录的实时时长写入 `elapsedSeconds`，并立即刷新一次
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

  /// 启动时恢复未结束的计时/打卡（应用冷启动或页面重建都会走到这里）
  ///
  /// - `mode == 'clock'` ⇒ 恢复打卡态；
  /// - 普通计时 ⇒ 按 projectName 找回标签；若记录带 `pausedAt` 则恢复为暂停态，
  ///   此时只显示冻结时长，不再启动 tick。
  void _checkActiveTimer() {
    final active = _workRepo.getInProgress();
    if (active != null) {
      isTimerRunning.value = true;
      currentTimerEntry.value = active;

      // 打卡记录只维护上下班状态，不参与收入标签
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

  /// 上班打卡：生成 mode 为 'clock' 的进行中记录
  ///
  /// 与正计时互斥；打卡不写收入账目（结束打卡时只更新时长）。
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

  /// 下班打卡：结束本次打卡记录，只统计时长、不产生收入
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

  /// 重算今日已完成打卡的总时长（仅 mode == 'clock'）
  void _updateTodayClockDuration() {
    final today = _workRepo.getToday().where(
        (e) => e.mode == 'clock' && e.status == WorkStatus.completed);
    final dur = today.fold(
        Duration.zero, (sum, e) => sum + (e.duration ?? Duration.zero));
    todayClockDuration.value = dur;
  }

  /// 从仓库重新加载全部记录并按开始时间倒序（最新在前）
  void loadEntries() {
    entries.value = _workRepo.getAll();
    entries.sort((a, b) => b.startTime.compareTo(a.startTime));
    _updateTodayClockDuration();
  }

  /// 删除一条记录并刷新列表与首页看板
  void deleteEntry(String id) {
    _workRepo.delete(id);
    loadEntries();
    _refreshDashboard();
  }

  /// 更新一条记录（长按编辑后保存），会刷新列表与首页看板
  void updateEntry(WorkEntry entry) {
    _workRepo.save(entry);
    loadEntries();
    _refreshDashboard();
  }

  /// 新增计时标签并按收入模式归一化字段（非对应模式的费率清零）
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

  /// 删除标签；至少保留 1 个，删除当前选中标签时自动回退到第一个
  void removeTag(String id) {
    if (tags.length <= 1) return;
    _storage.removeTimerTag(id);
    if (_selectedTag?.id == id) {
      _selectedTag = tags.isNotEmpty ? tags.first : null;
      currentTimerTag.value = _selectedTag;
    }
    notifyTagsChanged();
  }

  /// 调整标签顺序（管理弹窗拖动排序），并重写 sortOrder 后持久化
  void reorderTag(int oldIndex, int newIndex) {
    final list = _storage.timerTags;
    if (oldIndex < 0 || oldIndex >= list.length) return;
    // ReorderableListView 的 newIndex 是“插入到该下标之前”，向下拖动时要修正
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

  /// 已计时长格式化为 `HH:mm:ss`
  String get formattedElapsed {
    final h = elapsedSeconds.value ~/ 3600;
    final m = (elapsedSeconds.value % 3600) ~/ 60;
    final s = elapsedSeconds.value % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 今天当前标签的累计时长（仅已完成记录）
  Duration get todayTagDuration {
    if (_selectedTag == null) return Duration.zero;
    final today = _workRepo.getToday().where((e) =>
        e.status == WorkStatus.completed &&
        e.projectName == _selectedTag!.name);
    return today.fold(
        Duration.zero, (sum, e) => sum + (e.duration ?? Duration.zero));
  }

  /// 通知首页看板刷新；控制器未注册时静默忽略（如独立打开统计页）
  void _refreshDashboard() {
    try {
      Get.find<DashboardController>(tag: 'dashboard').refreshData();
    } catch (_) {}
  }

  /// 通知财务列表刷新；控制器未注册时静默忽略
  void _refreshFinance() {
    try {
      Get.find<FinanceController>().loadEntries();
    } catch (_) {}
  }

  @override
  void onClose() {
    // 控制器销毁时停掉秒级 tick，避免定时器泄漏
    _timer?.cancel();
    super.onClose();
  }
}
