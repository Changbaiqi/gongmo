// ============================================================
// widgets/month_duration_calendar.dart（月历时长网格）
// 职责：无状态月历，日期格下方显示当天累计时长（分钟）
// 关联：由 WorkStatsView 传入月份与 dayMinutes；仅展示、无交互
// ============================================================
import 'package:flutter/material.dart';

/// 月历时长组件：每天日期下方显示对应时长（时钟统计月视图）
class MonthDurationCalendar extends StatelessWidget {
  final DateTime month; // 任意当月日期，只取年/月
  final Map<int, double> dayMinutes; // 日(1..31) -> 分钟

  static const _weekDays = ['一', '二', '三', '四', '五', '六', '日']; // 周一起

  const MonthDurationCalendar({
    super.key,
    required this.month,
    this.dayMinutes = const {},
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    // “下月 0 号”即当月最后一天，避免手写闰年判断
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // weekday 中周一=1，减 1 得到首日前面要补齐的空格数
    final startOffset = DateTime(month.year, month.month, 1).weekday - 1;

    final cells = <Widget>[
      for (final d in _weekDays)
        Center(
          child: Text(d,
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500)),
        ),
    ];
    for (var i = 0; i < startOffset; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      // 今天用主题色圆底高亮
      final isToday = now.year == month.year &&
          now.month == month.month &&
          now.day == day;
      final mins = dayMinutes[day] ?? 0;
      cells.add(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: isToday
                  ? BoxDecoration(color: cs.primary, shape: BoxShape.circle)
                  : null,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? cs.onPrimary : cs.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              mins > 0 ? _fmt(mins) : ' ',
              style: TextStyle(
                fontSize: 9,
                color: mins > 0 ? cs.primary : Colors.transparent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }
    // 末尾补空格，使网格完整成行
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.85,
          children: cells,
        ),
      ],
    );
  }

  /// 分钟转紧凑文案：≥60 分钟显示一位小数的小时，否则显示分钟
  String _fmt(double minutes) {
    final total = minutes.round();
    if (total >= 60) return '${(total / 60).toStringAsFixed(1)}时';
    return '$total分';
  }
}
