import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/work_entry.dart';
import '../../data/models/timer_tag.dart';
import '../../data/services/storage_service.dart';
import 'work_controller.dart';

class WorkPage extends StatefulWidget {
  const WorkPage({super.key});

  @override
  State<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends State<WorkPage>
    with SingleTickerProviderStateMixin {
  final WorkController _ctrl = Get.put(WorkController());
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => Column(
          children: [
            const SizedBox(height: 8),
            _buildModeToggle(),
            if (_ctrl.isClockMode.value) ...[
              const SizedBox(height: 12),
              Expanded(child: _buildClockView()),
            ] else ...[
              _buildTagRow(),
              const SizedBox(height: 12),
              Expanded(
                child: _ctrl.isTimerRunning.value
                    ? _buildRunningView()
                    : _buildIdleView(),
              ),
            ],
          ],
        ));
  }

  Widget _buildModeToggle() {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _ctrl.toggleMode(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_ctrl.isClockMode.value
                      ? color.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        !_ctrl.isClockMode.value ? color : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text('计时',
                      style: TextStyle(
                        color: !_ctrl.isClockMode.value ? color : Colors.grey,
                        fontWeight: !_ctrl.isClockMode.value
                            ? FontWeight.w600
                            : FontWeight.normal,
                      )),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _ctrl.toggleMode(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _ctrl.isClockMode.value
                      ? color.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        _ctrl.isClockMode.value ? color : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text('打卡',
                      style: TextStyle(
                        color: _ctrl.isClockMode.value ? color : Colors.grey,
                        fontWeight: _ctrl.isClockMode.value
                            ? FontWeight.w600
                            : FontWeight.normal,
                      )),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockView() {
    final now = DateTime.now();
    final todayRecords = _ctrl.entries
        .where((e) =>
            e.projectName == '打卡' &&
            DateHelper.isSameDay(e.startTime, DateTime.now()))
        .toList();

    return Column(
      children: [
        const Spacer(flex: 2),
        if (_ctrl.isClockedIn.value) ...[
          Text(DateHelper.formatTime(DateTime.now()),
              style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w200,
                  fontFamily: 'monospace')),
          const SizedBox(height: 6),
          Text(
            '上班: ${DateHelper.formatTime(_ctrl.clockInTime.value!)}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Obx(() => Text(
                '已打卡 ${DateHelper.formatDuration(DateTime.now().difference(_ctrl.clockInTime.value!))}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              )),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _ctrl.clockOut,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF5350),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF5350).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text('下班',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ] else ...[
          Text(DateHelper.formatTime(now),
              style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w200,
                  fontFamily: 'monospace')),
          const SizedBox(height: 6),
          Text(DateHelper.formatDate(now),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
          const SizedBox(height: 4),
          Text(DateHelper.formatWeekday(now),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _ctrl.clockIn,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4CAF50),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text('上班',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
        const Spacer(flex: 2),
        _buildClockRecords(todayRecords),
      ],
    );
  }

  Widget _buildClockRecords(List<WorkEntry> records) {
    final completed =
        records.where((e) => e.status == WorkStatus.completed).toList();
    final totalDur = completed.fold(
        Duration.zero, (sum, e) => sum + (e.duration ?? Duration.zero));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('今日打卡记录',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1)),
              const Spacer(),
              if (totalDur > Duration.zero)
                Text('共 ${DateHelper.formatDuration(totalDur)}',
                    style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          if (completed.isEmpty)
            Center(
              child: Text('暂无记录',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            ),
          ...completed.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Color(0xFF4CAF50)),
                    ),
                    const SizedBox(width: 10),
                    Text('上班 ${DateHelper.formatTime(e.startTime)}',
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    const Text('→', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 6),
                    Text(
                        '下班 ${e.endTime != null ? DateHelper.formatTime(e.endTime!) : "..."}',
                        style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    if (e.duration != null)
                      Text(DateHelper.formatDuration(e.duration!),
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _confirmDelete(e),
                      child: Icon(Icons.close,
                          size: 14, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTagRow() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ..._ctrl.tags.map((tag) =>
              _buildTagChip(tag, _ctrl.currentTimerTag.value?.id == tag.id)),
          const SizedBox(width: 4),
          _buildAddTagButton(),
        ],
      ),
    );
  }

  Widget _buildTagChip(TimerTag tag, bool isSelected) {
    final color = _parseColor(tag.color);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: () => _ctrl.selectTag(tag),
        onLongPress: () => _showEditTagDialog(tag),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _iconFor(tag.icon),
                size: 15,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                tag.name,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (tag.isWork)
                Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: isSelected ? Colors.amber.shade200 : Colors.amber,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddTagButton() {
    return GestureDetector(
      onTap: _showAddTagDialog,
      child: Container(
        margin: const EdgeInsets.only(left: 2),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Icon(Icons.add, size: 18, color: Colors.grey.shade500),
      ),
    );
  }

  Widget _buildRunningView() {
    final tag = _ctrl.currentTimerTag.value;
    final color = tag != null ? _parseColor(tag.color) : Colors.grey;

    _pulseCtrl.repeat(reverse: true);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
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
          const Spacer(flex: 3),
          _buildAnimatedRing(color),
          const Spacer(flex: 3),
          Text(DateHelper.formatTime(DateTime.now()),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _ctrl.stopTimer,
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEF5350),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40EF5350),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.stop_rounded, size: 32, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAnimatedRing(Color color) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final scale = 1.0 + _pulseCtrl.value * 0.05;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.2 + _pulseCtrl.value * 0.15),
                width: 5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 20 + _pulseCtrl.value * 12,
                ),
              ],
            ),
            child: Center(
              child: Obx(() {
                final s = _ctrl.elapsedSeconds.value;
                final h = s ~/ 3600;
                final m = (s % 3600) ~/ 60;
                final sec = s % 60;
                final display = h > 0
                    ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}'
                    : '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
                return Text(
                  display,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w200,
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIdleView() {
    final tag = _ctrl.currentTimerTag.value;
    final color = tag != null ? _parseColor(tag.color) : Colors.grey;
    final todayDuration = _ctrl.todayTagDuration;

    return Column(
      children: [
        const Spacer(flex: 3),
        GestureDetector(
          onTap: _ctrl.startTimer,
          child: Container(
            width: 160,
            height: 160,
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
                Icon(Icons.play_arrow_rounded,
                    size: 52, color: color.withValues(alpha: 0.7)),
                const SizedBox(height: 2),
                Text(
                  '开始',
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
          const SizedBox(height: 14),
          Text(
            '今日${tag.name}: ${DateHelper.formatDuration(todayDuration)}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
        const Spacer(flex: 3),
        _buildTodaySessions(),
      ],
    );
  }

  Widget _buildTodaySessions() {
    final todayEntries = _ctrl.entries
        .where((e) => DateHelper.isSameDay(e.startTime, DateTime.now()))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('今日记录',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                )),
          ),
          if (todayEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(
                  child: Text('暂无记录',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 12))),
            ),
          ...todayEntries.map(_buildSessionItem),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSessionItem(WorkEntry entry) {
    final tag = _ctrl.tags.cast<TimerTag?>().firstWhere(
          (t) => t?.name == entry.projectName,
          orElse: () => null,
        );
    final color = tag != null ? _parseColor(tag.color) : Colors.grey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Text(entry.projectName.isNotEmpty ? entry.projectName : '未命名',
                    style: const TextStyle(fontSize: 13)),
                if (tag != null && tag.isWork)
                  const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
              ],
            ),
          ),
          if (entry.duration != null)
            Text(DateHelper.formatDuration(entry.duration!),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          if (entry.endTime != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _confirmDelete(entry),
              child: Icon(Icons.close, size: 14, color: Colors.grey.shade400),
            ),
          ],
        ],
      ),
    );
  }

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

  void _showAddTagDialog() {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    final isWork = false.obs;

    Get.dialog(AlertDialog(
      title: const Text('添加计时标签'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '标签名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Obx(() => SwitchListTile(
                title: const Text('工作标签（计算收入）'),
                value: isWork.value,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => isWork.value = v,
              )),
          Obx(() {
            if (!isWork.value) return const SizedBox.shrink();
            return TextField(
              controller: rateCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '时薪 (¥/小时)',
                border: OutlineInputBorder(),
              ),
            );
          }),
        ],
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
            _ctrl.addTag(name,
                isWork: isWork.value,
                hourlyRate: double.tryParse(rateCtrl.text) ?? 0);
            Get.back();
          },
          child: const Text('添加'),
        ),
      ],
    ));
  }

  void _showEditTagDialog(TimerTag tag) {
    final nameCtrl = TextEditingController(text: tag.name);
    final rateCtrl = TextEditingController(text: tag.hourlyRate.toString());
    final isWork = tag.isWork.obs;

    Get.dialog(AlertDialog(
      title: const Text('编辑 / 删除标签'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: '标签名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Obx(() => SwitchListTile(
                title: const Text('工作标签（计算收入）'),
                value: isWork.value,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => isWork.value = v,
              )),
          Obx(() {
            if (!isWork.value) return const SizedBox.shrink();
            return TextField(
              controller: rateCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '时薪 (¥/小时)',
                border: OutlineInputBorder(),
              ),
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _ctrl.removeTag(tag.id);
            Get.back();
          },
          child: const Text('删除', style: TextStyle(color: Colors.red)),
        ),
        const Spacer(),
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              Get.snackbar('提示', '标签名不能为空');
              return;
            }
            tag.name = name;
            tag.isWork = isWork.value;
            tag.hourlyRate = double.tryParse(rateCtrl.text) ?? 0;
            StorageService().updateTimerTag(tag);
            _ctrl.update();
            Get.back();
          },
          child: const Text('保存'),
        ),
      ],
    ));
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'work':
        return Icons.work_outline_rounded;
      case 'school':
        return Icons.school_outlined;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'fitness_center':
        return Icons.fitness_center_outlined;
      case 'menu_book':
        return Icons.menu_book_outlined;
      case 'timer':
        return Icons.timer_outlined;
      default:
        return Icons.label_outline_rounded;
    }
  }
}
