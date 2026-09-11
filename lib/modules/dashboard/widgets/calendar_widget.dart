// ============================================================
// dashboard/widgets/calendar_widget.dart（Dashboard 模块 · 纯 UI 组件）
// 职责：自绘月历网格，标记有记录的日期，支持翻月与日期点选。
// 关联：由 DashboardPage 传入 entryDates 使用；无业务逻辑，不依赖控制器/服务。
// ============================================================
import 'package:flutter/material.dart';

/// 月历组件：按周一起始展示一个月，[markedDates] 中的日期显示圆点。
///
/// 自身维护当前展示月份（翻月用），[initialMonth] 只在首次创建时生效，
/// 之后外部重新传入也不会跳月。
class MonthCalendar extends StatefulWidget {
  final DateTime initialMonth;
  final Set<DateTime> markedDates;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDaySelected;

  MonthCalendar({
    super.key,
    DateTime? initialMonth,
    this.markedDates = const {},
    this.selectedDate,
    this.onDaySelected,
  }) : initialMonth = initialMonth ?? DateTime.now();

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _displayMonth;

  static const _weekDays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _displayMonth =
        DateTime(widget.initialMonth.year, widget.initialMonth.month);
  }

  void _prevMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
    });
  }

  /// 把日期编码成 yyyyMMdd 整数比较：DateTime 的 == 包含时分秒，
  /// 这里只关心“同一天”，整数比较更直接，也方便做去重。
  static int _dayKey(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  bool _isToday(DateTime date) => _dayKey(date) == _dayKey(DateTime.now());

  bool _isSelected(DateTime date) =>
      widget.selectedDate != null &&
      _dayKey(date) == _dayKey(widget.selectedDate!);

  // 逐日比对而非 Set.contains：外部传入的日期可能带时分秒
  bool _isMarked(DateTime date) => widget.markedDates.any(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final monthStr = '${_displayMonth.year}年${_displayMonth.month}月';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: 8),
            Text(monthStr,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.chevron_left_rounded,
                  size: 22, color: cs.onSurfaceVariant),
              onPressed: _prevMonth,
            ),
            IconButton(
              icon: Icon(Icons.chevron_right_rounded,
                  size: 22, color: cs.onSurfaceVariant),
              onPressed: _nextMonth,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: _weekDays.map((d) {
            return Expanded(
              child: Center(
                child: Text(d,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    )),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        _buildDaysGrid(),
      ],
    );
  }

  /// 生成整月格子：先补首日前置空格，再填 1..最后一天，末尾补空保持整行。
  Widget _buildDaysGrid() {
    final cs = Theme.of(context).colorScheme;
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final lastDay = DateTime(_displayMonth.year, _displayMonth.month + 1, 0);
    final daysInMonth = lastDay.day;

    // Monday = 1, Sunday = 7：减 1 得到“周一起始”的前置空格数
    int startOffset = firstDay.weekday - 1;

    final cells = <Widget>[];
    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_displayMonth.year, _displayMonth.month, day);
      final isToday = _isToday(date);
      final isSelected = _isSelected(date);
      final hasEntry = _isMarked(date);
      final isWeekend = date.weekday == DateTime.saturday ||
          date.weekday == DateTime.sunday;

      cells.add(GestureDetector(
        onTap: () => widget.onDaySelected?.call(date),
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isToday
                  ? cs.primary
                  : isSelected
                      ? cs.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
              shape: BoxShape.circle,
              border: isSelected && !isToday
                  ? Border.all(color: cs.primary, width: 1.4)
                  : null,
            ),
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isToday
                        ? cs.onPrimary
                        : isWeekend
                            ? cs.onSurfaceVariant.withValues(alpha: 0.6)
                            : cs.onSurface,
                  ),
                ),
                if (hasEntry)
                  Positioned(
                    bottom: -3,
                    child: Container(
                      width: 4.5,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isToday ? cs.onPrimary : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ));
    }

    // 补齐最后一行的空位，保证格子总数能被 7 整除
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.0,
      children: cells,
    );
  }
}
