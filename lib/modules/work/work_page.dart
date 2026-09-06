import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/icon_utils.dart';
import '../../core/widgets/flip_clock.dart';
import '../../data/models/work_entry.dart';
import '../../data/models/timer_tag.dart';
import '../../data/services/storage_service.dart';
import 'widgets/fullscreen_timer_page.dart';
import 'widgets/work_stats_view.dart';
import 'work_controller.dart';

class WorkPage extends StatefulWidget {
  const WorkPage({super.key});

  @override
  State<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends State<WorkPage> {
  final WorkController _ctrl = Get.put(WorkController());

  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  DateTime _recordDate = DateTime.now(); // 今日记录筛选日期

  /// 顶部页签：false=计时（正计时+打卡合并页） true=数据统计
  bool _statsMode = false;

  /// 主体左右滑动：0=正计时 1=打卡计时
  late final PageController _modePageCtrl = PageController(
    initialPage: _ctrl.isClockedIn.value ? 1 : 0,
  );
  int _modeIdx = 0;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _modePageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        _buildTopToggle(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey(_statsMode),
              child:
                  _statsMode ? const WorkStatsView() : _buildMergedTimerPage(),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- 顶部页签：计时 | 统计 ----------------

  Widget _buildTopToggle() {
    final cs = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));

    Widget segment(String label, bool active, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: ShapeDecoration(
            color:
                active ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
            shape: shape,
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  color: active
                      ? cs.primary
                      : cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                )),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: segment('计时', !_statsMode, () {
                if (_statsMode) setState(() => _statsMode = false);
              }),
            ),
            Expanded(
              child: segment('统计', _statsMode, () {
                if (!_statsMode) setState(() => _statsMode = true);
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 合并后的计时页 ----------------

  Widget _buildMergedTimerPage() {
    return Obx(() => Column(
          children: [
            const SizedBox(height: 8),
            _buildTagRow(),
            const SizedBox(height: 2),
            _buildModePills(),
            Expanded(
              child: PageView(
                controller: _modePageCtrl,
                onPageChanged: (i) => setState(() => _modeIdx = i),
                children: [
                  _buildTimerPage(),
                  _buildClockPage(),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _buildTodayRecords(),
          ],
        ));
  }

  /// 正计时 | 打卡 切换 pills（与滑动联动）
  Widget _buildModePills() {
    final cs = Theme.of(context).colorScheme;

    Widget pill(String label, int index) {
      final active = _modeIdx == index;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_modePageCtrl.hasClients && _modeIdx != index) {
            HapticFeedback.selectionClick();
            _modePageCtrl.animateToPage(
              index,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            color:
                active ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                index == 0 ? Icons.timer_outlined : Icons.punch_clock_outlined,
                size: 15,
                color: active ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    color: active
                        ? cs.primary
                        : cs.onSurfaceVariant.withValues(alpha: 0.8),
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  )),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        pill('正计时', 0),
        const SizedBox(width: 8),
        pill('打卡', 1),
      ],
    );
  }

  /// 页 0：正计时（开始按钮 ↔ 翻牌计时牌 过渡切换）
  Widget _buildTimerPage() {
    return Obx(() => AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.82, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: _ctrl.isTimerRunning.value
              ? KeyedSubtree(
                  key: const ValueKey('running'),
                  child: _buildRunningView(),
                )
              : KeyedSubtree(
                  key: const ValueKey('idle'),
                  child: _buildIdleView(),
                ),
        ));
  }

  /// 页 1：打卡
  Widget _buildClockPage() {
    final cs = Theme.of(context).colorScheme;
    final busy = _ctrl.isTimerRunning.value && !_ctrl.isClockedIn.value;

    return Column(
      children: [
        const Spacer(flex: 2),
        _bigClock(),
        if (_ctrl.isClockedIn.value) ...[
          const SizedBox(height: 6),
          Text('打卡: ${DateHelper.formatTime(_ctrl.clockInTime.value!)}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            '已打卡 ${DateHelper.formatDuration(DateTime.now().difference(_ctrl.clockInTime.value!))}',
            style: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 13),
          ),
          const SizedBox(height: 24),
          _clockButton(
            label: '结束打卡',
            isStop: true,
            onTap: () {
              HapticFeedback.mediumImpact();
              _ctrl.clockOut();
            },
          ),
        ] else ...[
          const SizedBox(height: 6),
          Text(DateHelper.formatDate(_now),
              style: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 15)),
          const SizedBox(height: 4),
          Text(DateHelper.formatWeekday(_now),
              style: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 13)),
          const SizedBox(height: 24),
          if (busy) ...[
            Text('正计时进行中，结束后方可打卡',
                style: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 12)),
            const SizedBox(height: 12),
            const SizedBox(height: 84),
          ] else
            _clockButton(
              label: '打卡',
              onTap: () {
                HapticFeedback.mediumImpact();
                _ctrl.clockIn();
              },
            ),
        ],
        const Spacer(flex: 2),
      ],
    );
  }

  // ---------------- 统一今日记录 ----------------

  Widget _buildTodayRecords() {
    final cs = Theme.of(context).colorScheme;
    final isToday = DateHelper.isSameDay(_recordDate, DateTime.now());
    final dayEntries = _ctrl.entries
        .where((e) => DateHelper.isSameDay(e.startTime, _recordDate))
        .toList();
    final totalDur = dayEntries.fold<Duration>(
      Duration.zero,
      (sum, e) =>
          sum +
          (e.endTime != null
              ? (e.duration ?? Duration.zero)
              : (isToday ? e.liveElapsed : Duration.zero)),
    );

    return Container(
      height: 208,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isToday ? '今日记录' : '${_recordDate.month}月${_recordDate.day}日 记录',
                  style: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1)),
              const Spacer(),
              // 日期筛选：点击选择查看哪一天的数据
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _recordDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _recordDate =
                        DateTime(picked.year, picked.month, picked.day));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          size: 12, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        isToday
                            ? '今天'
                            : '${_recordDate.month}月${_recordDate.day}日',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: dayEntries.isEmpty
                ? Center(
                    child: Text(
                        isToday
                            ? '暂无记录，开始计时或打卡后自动记录'
                            : '该日暂无记录',
                        style: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                            fontSize: 12)),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: dayEntries.length,
                    itemExtent: 34,
                    itemBuilder: (context, index) =>
                        _buildSessionItem(dayEntries[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(WorkEntry entry) {
    final cs = Theme.of(context).colorScheme;
    final isClock = entry.projectName == '打卡';
    final tag = _ctrl.tags.cast<TimerTag?>().firstWhere(
          (t) => t?.name == entry.projectName,
          orElse: () => null,
        );
    final color = tag != null
        ? _parseColor(tag.color)
        : (isClock ? const Color(0xFF4CAF50) : Colors.grey);
    final running = entry.endTime == null;
    final range = running
        ? '${DateHelper.formatTime(entry.startTime)} - 进行中'
        : '${DateHelper.formatTime(entry.startTime)} - ${DateHelper.formatTime(entry.endTime!)}';

    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Text(
                  entry.projectName.isNotEmpty ? entry.projectName : '未命名',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              if (tag != null && tag.isWork)
                const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
              const SizedBox(width: 8),
              Text(range,
                  style: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      fontSize: 11)),
            ],
          ),
        ),
        Text(
          DateHelper.formatDuration(entry.duration ?? entry.liveElapsed),
          style: TextStyle(
              color: running
                  ? cs.primary
                  : cs.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: running ? FontWeight.w600 : FontWeight.normal,
              fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        if (!running) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _confirmDelete(entry),
            child: Icon(Icons.close_rounded,
                size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          ),
        ],
        const SizedBox(width: 6),
      ],
    );
  }

  // ---------------- 正计时视图 ----------------

  Widget _buildTagRow() {
    return Obx(() {
      _ctrl.tagsRevision.value; // 标签增删/排序/编辑后刷新
      return SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          children: [
            _buildAddTagButton(),
            const SizedBox(width: 4),
            ..._ctrl.tags.map((tag) => _buildTagChip(
                tag, _ctrl.currentTimerTag.value?.id == tag.id)),
          ],
        ),
      );
    });
  }

  Widget _buildTagChip(TimerTag tag, bool isSelected) {
    final cs = Theme.of(context).colorScheme;
    final color = _parseColor(tag.color);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: () => _ctrl.selectTag(tag),
        onLongPress: () => _showEditTagDialog(tag),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? color
                : cs.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? color
                  : cs.outlineVariant.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _iconFor(tag.icon),
                size: 15,
                color: isSelected ? Colors.white : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                tag.name,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.white : cs.onSurface,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (tag.isWork)
                Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: isSelected
                      ? Colors.amber.shade200
                      : Colors.amber.shade700,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddTagButton() {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _showAddTagDialog,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showTagManagerDialog();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          border:
              Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Icon(Icons.add_rounded, size: 18, color: cs.onSurfaceVariant),
      ),
    );
  }

  // ---------------- 标签管理（长按 + 打开） ----------------

  void _showTagManagerDialog() {
    final cs = Theme.of(context).colorScheme;
    Get.dialog(
      AlertDialog(
        title: const Text('标签管理'),
        content: SizedBox(
          width: double.maxFinite,
          child: Obx(() {
            _ctrl.tagsRevision.value;
            final tags = _ctrl.tags;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '长按拖动调整先后顺序，共 ${tags.length} 个标签',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 320,
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    itemCount: tags.length,
                    onReorder: _ctrl.reorderTag,
                    itemBuilder: (context, index) =>
                        _buildManagerTile(context, tags[index], index),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showAddTagDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('添加标签'),
                  ),
                ),
              ],
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  Widget _buildManagerTile(BuildContext context, TimerTag tag, int index) {
    final cs = Theme.of(context).colorScheme;
    final color = _parseColor(tag.color);
    final canDelete = _ctrl.tags.length > 1;
    return ListTile(
      key: ValueKey(tag.id),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_indicator_rounded,
                size: 18, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
          ),
          const SizedBox(width: 2),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child:
                Icon(IconUtils.tag(tag.icon), size: 17, color: color),
          ),
        ],
      ),
      title: Text(tag.name,
          style:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(_incomeTypeLabel(tag),
          style: TextStyle(
              fontSize: 11.5,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
      trailing: IconButton(
        icon: Icon(
          Icons.delete_outline_rounded,
          size: 20,
          color: canDelete
              ? cs.onSurfaceVariant.withValues(alpha: 0.7)
              : cs.outlineVariant,
        ),
        onPressed: canDelete
            ? () {
                HapticFeedback.selectionClick();
                _ctrl.removeTag(tag.id);
              }
            : () => Get.snackbar('提示', '至少保留一个标签'),
      ),
    );
  }

  String _incomeTypeLabel(TimerTag tag) {
    switch (tag.incomeType) {
      case TimerTag.incomeHourly:
        return '时薪 ¥${tag.hourlyRate.toStringAsFixed(0)}/小时';
      case TimerTag.incomeManual:
        return '自统计收入';
      case TimerTag.incomeFixed:
        return '固定薪资 ¥${tag.fixedSalary.toStringAsFixed(0)}';
      default:
        return '普通标签';
    }
  }

  Widget _buildRunningView() {
    final tag = _ctrl.currentTimerTag.value;
    final color = tag != null ? _parseColor(tag.color) : Colors.grey;
    final cs = Theme.of(context).colorScheme;
    final paused = _ctrl.isPaused.value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (tag != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconFor(tag.icon), size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(tag.name,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  if (tag.isWork)
                    Icon(Icons.star_rounded,
                        size: 16, color: Colors.amber.shade700),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // 翻牌计时牌：点击进入横向全屏沉浸显示
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Get.to(
                () => const FullscreenTimerPage(),
                transition: Transition.fadeIn,
                duration: const Duration(milliseconds: 320),
              );
            },
            child: Obx(() => Opacity(
                  opacity: _ctrl.isPaused.value ? 0.55 : 1,
                  child: FlipClock.elapsed(
                    elapsed: Duration(seconds: _ctrl.elapsedSeconds.value),
                    digitWidth: 52,
                    digitHeight: 76,
                    fontSize: 42,
                  ),
                )),
          ),
          const SizedBox(height: 4),
          Text('点击计时牌进入全屏',
              style: TextStyle(
                  fontSize: 10.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
          if (paused) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('已暂停',
                  style:
                      TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ),
          ],
          const SizedBox(height: 10),
          Text(DateHelper.formatTime(_now),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _roundAction(
                icon:
                    paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: const Color(0xFF43A047),
                onTap: paused ? _ctrl.resumeTimer : _ctrl.pauseTimer,
              ),
              const SizedBox(width: 28),
              _roundAction(
                icon: Icons.stop_rounded,
                color: const Color(0xFFEF5350),
                onTap: _ctrl.stopTimer,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 30, color: Colors.white),
      ),
    );
  }

  Widget _buildIdleView() {
    final tag = _ctrl.currentTimerTag.value;
    final color = tag != null ? _parseColor(tag.color) : Colors.grey;
    final todayDuration = _ctrl.todayTagDuration;
    final busy = _ctrl.isClockedIn.value;

    return Column(
      children: [
        const Spacer(flex: 3),
        GestureDetector(
          onTap: busy
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  _ctrl.startTimer();
                },
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.04),
              border:
                  Border.all(color: color.withValues(alpha: 0.25), width: 3),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    busy
                        ? Icons.punch_clock_outlined
                        : Icons.play_arrow_rounded,
                    size: 48,
                    color: color.withValues(alpha: 0.7)),
                const SizedBox(height: 2),
                Text(
                  busy ? '打卡中' : '开始',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (tag != null && todayDuration > Duration.zero) ...[
          const SizedBox(height: 12),
          Text(
            '今日${tag.name}: ${DateHelper.formatDuration(todayDuration)}',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12),
          ),
        ],
        const Spacer(flex: 3),
      ],
    );
  }

  // ---------------- 打卡视图 ----------------

  Widget _bigClock() {
    return FlipClock(time: _now);
  }

  /// 上下班打卡按钮：上班跟随所选标签色，下班用主题错误色，风格与全页一致
  Widget _clockButton({
    required String label,
    required VoidCallback onTap,
    bool isStop = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tag = _ctrl.currentTimerTag.value;
    final base = isStop
        ? cs.error
        : (tag != null ? _parseColor(tag.color) : cs.primary);
    final dark = Color.lerp(base, Colors.black, 0.16)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 112,
        height: 112,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: base.withValues(alpha: isStop ? 0.10 : 0.08),
        ),
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, dark],
            ),
            boxShadow: [
              BoxShadow(
                color: base.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
          ),
        ),
      ),
    );
  }

  // ---------------- 弹窗 ----------------

  void _confirmDelete(WorkEntry entry) {
    Get.dialog(AlertDialog(
      title: const Text('删除记录'),
      content: const Text('确定删除这条计时记录吗？'),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        TextButton(
          onPressed: () {
            _ctrl.deleteEntry(entry.id);
            Get.back();
          },
          child: const Text('删除', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }

  static const _iconPickerOrder = [
    'work', 'school', 'menu_book', 'code', 'brush',
    'music_note', 'self_improvement', 'fitness_center', 'favorite', 'timer',
    'flight', 'directions_car', 'local_cafe', 'restaurant', 'shopping_cart',
    'sports_esports', 'savings', 'home', 'groups', 'label',
  ];

  void _showAddTagDialog() {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    final fixedCtrl = TextEditingController();
    final incomeType = TimerTag.incomeNone.obs;
    final selectedIcon = 'timer'.obs;

    Get.dialog(AlertDialog(
      title: const Text('添加计时标签'),
      content: SizedBox(
        width: double.maxFinite,
        child: _tagFormContent(
          nameCtrl: nameCtrl,
          rateCtrl: rateCtrl,
          fixedCtrl: fixedCtrl,
          incomeType: incomeType,
          selectedIcon: selectedIcon,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              Get.snackbar('提示', '请输入标签名称');
              return;
            }
            final rate = double.tryParse(rateCtrl.text) ?? 0;
            final fixed = double.tryParse(fixedCtrl.text) ?? 0;
            if (incomeType.value == TimerTag.incomeHourly && rate <= 0) {
              Get.snackbar('提示', '请填写有效的时薪');
              return;
            }
            if (incomeType.value == TimerTag.incomeFixed && fixed <= 0) {
              Get.snackbar('提示', '请填写有效的固定薪资');
              return;
            }
            _ctrl.addTag(
              name,
              icon: selectedIcon.value,
              incomeType: incomeType.value,
              hourlyRate: rate,
              fixedSalary: fixed,
            );
            Get.back();
          },
          child: const Text('添加'),
        ),
      ],
    ));
  }

  void _showEditTagDialog(TimerTag tag) {
    final nameCtrl = TextEditingController(text: tag.name);
    final rateCtrl = TextEditingController(
        text: tag.hourlyRate > 0 ? tag.hourlyRate.toString() : '');
    final fixedCtrl = TextEditingController(
        text: tag.fixedSalary > 0 ? tag.fixedSalary.toString() : '');
    final incomeType = tag.incomeType.obs;
    final selectedIcon = tag.icon.obs;

    Get.dialog(AlertDialog(
      title: const Text('编辑标签'),
      content: SizedBox(
        width: double.maxFinite,
        child: _tagFormContent(
          nameCtrl: nameCtrl,
          rateCtrl: rateCtrl,
          fixedCtrl: fixedCtrl,
          incomeType: incomeType,
          selectedIcon: selectedIcon,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _ctrl.removeTag(tag.id);
            Get.back();
          },
          child: const Text('删除', style: TextStyle(color: Colors.red)),
        ),
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              Get.snackbar('提示', '标签名不能为空');
              return;
            }
            final rate = double.tryParse(rateCtrl.text) ?? 0;
            final fixed = double.tryParse(fixedCtrl.text) ?? 0;
            if (incomeType.value == TimerTag.incomeHourly && rate <= 0) {
              Get.snackbar('提示', '请填写有效的时薪');
              return;
            }
            if (incomeType.value == TimerTag.incomeFixed && fixed <= 0) {
              Get.snackbar('提示', '请填写有效的固定薪资');
              return;
            }
            tag.name = name;
            tag.icon = selectedIcon.value;
            tag.incomeType = incomeType.value;
            tag.isWork = incomeType.value != TimerTag.incomeNone;
            tag.hourlyRate =
                incomeType.value == TimerTag.incomeHourly ? rate : 0;
            tag.fixedSalary =
                incomeType.value == TimerTag.incomeFixed ? fixed : 0;
            StorageService().updateTimerTag(tag);
            _ctrl.notifyTagsChanged();
            Get.back();
          },
          child: const Text('保存'),
        ),
      ],
    ));
  }

  /// 标签表单：名称 + 标签属性单选 + 图标选择
  Widget _tagFormContent({
    required TextEditingController nameCtrl,
    required TextEditingController rateCtrl,
    required TextEditingController fixedCtrl,
    required RxString incomeType,
    required RxString selectedIcon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '标签名称',
            ),
          ),
          const SizedBox(height: 12),
          _labeledDivider('标签属性', cs),
          Obx(() => Column(
                children: [
                  _incomeTypeOption(incomeType, TimerTag.incomeNone, '普通标签',
                      '不计收入，仅用于计时统计'),
                  _incomeTypeOption(incomeType, TimerTag.incomeHourly,
                      '工作标签（时薪）', '按时长 × 时薪自动计算收入'),
                  _incomeTypeOption(incomeType, TimerTag.incomeManual,
                      '工作标签（自统计）', '计时结束后手动输入本次所得'),
                  _incomeTypeOption(incomeType, TimerTag.incomeFixed,
                      '工作标签（固定薪资）', '计时结束后自动记录预设固定薪资'),
                  if (incomeType.value == TimerTag.incomeHourly) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: rateCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '时薪 (¥/小时)',
                      ),
                    ),
                  ],
                  if (incomeType.value == TimerTag.incomeFixed) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: fixedCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '每次固定薪资 (¥)',
                      ),
                    ),
                  ],
                ],
              )),
          const SizedBox(height: 12),
          _labeledDivider('标签图标', cs),
          const SizedBox(height: 4),
          Obx(() => GridView.count(
                crossAxisCount: 5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1,
                children: _iconPickerOrder.map((key) {
                  final selected = selectedIcon.value == key;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      selectedIcon.value = key;
                    },
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected
                              ? cs.primary
                              : cs.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? cs.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          IconUtils.tag(key),
                          size: 20,
                          color:
                              selected ? Colors.white : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              )),
        ],
      ),
    );
  }

  /// 中间带文字的分割线
  Widget _labeledDivider(String text, ColorScheme cs) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8))),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _incomeTypeOption(
      RxString current, String value, String title, String subtitle) {
    final cs = Theme.of(context).colorScheme;
    return RadioListTile<String>(
      value: value,
      groupValue: current.value,
      onChanged: (v) => current.value = v ?? TimerTag.incomeNone,
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontSize: 11.5,
              color: cs.onSurfaceVariant.withValues(alpha: 0.8))),
      dense: true,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }

  // ---------------- 工具 ----------------

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  IconData _iconFor(String name) => IconUtils.tag(name);
}
