import 'package:flutter/material.dart';

class MonthCalendar extends StatefulWidget {
  final DateTime initialMonth;
  final Set<DateTime> markedDates;
  final ValueChanged<DateTime>? onDaySelected;

  MonthCalendar({
    super.key,
    DateTime? initialMonth,
    this.markedDates = const {},
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isMarked(DateTime date) {
    return widget.markedDates.any((d) =>
        d.year == date.year && d.month == date.month && d.day == date.day);
  }

  @override
  Widget build(BuildContext context) {
    final monthStr = '${_displayMonth.year}年${_displayMonth.month}月';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: _prevMonth,
            ),
            Text(monthStr, style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: _nextMonth,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: _weekDays.map((d) {
            return Expanded(
              child: Center(
                child: Text(d,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
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

  Widget _buildDaysGrid() {
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final lastDay = DateTime(_displayMonth.year, _displayMonth.month + 1, 0);
    final daysInMonth = lastDay.day;

    // Monday = 1, Sunday = 7
    int startOffset = firstDay.weekday - 1;

    final cells = <Widget>[];
    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_displayMonth.year, _displayMonth.month, day);
      final isToday = _isToday(date);
      final hasEntry = _isMarked(date);

      cells.add(GestureDetector(
        onTap: () => widget.onDaySelected?.call(date),
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color:
                isToday ? Theme.of(context).colorScheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : null,
                ),
              ),
              if (hasEntry)
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ));
    }

    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: cells,
    );
  }
}
