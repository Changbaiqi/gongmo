// ============================================================
// 日期与时长格式化工具（core/utils）
// 职责：统一 App 内的日期/时间/时长显示格式（中文 locale）
// 关联：被各页面与控制器使用；中文星期依赖 main() 中 initializeDateFormatting('zh_CN')
// ============================================================

import 'package:intl/intl.dart';

/// 日期/时长格式化辅助类（纯静态方法，无状态）
class DateHelper {
  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final _monthFormat = DateFormat('yyyy-MM');
  static final _timeFormat = DateFormat('HH:mm');
  static final _fullDisplayFormat = DateFormat('MM月dd日 HH:mm');
  static final _weekdayFormat = DateFormat('EEEE', 'zh_CN');

  static String formatDate(DateTime date) => _dateFormat.format(date);
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);
  static String formatMonth(DateTime date) => _monthFormat.format(date);
  static String formatTime(DateTime date) => _timeFormat.format(date);
  static String formatDisplay(DateTime date) => _fullDisplayFormat.format(date);
  static String formatWeekday(DateTime date) => _weekdayFormat.format(date);

  /// 中文可读时长，如 "2小时35分钟"（不足 1 小时只显示分钟）
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours小时${minutes > 0 ? '$minutes分钟' : ''}';
    }
    return '$minutes分钟';
  }

  /// 定长时钟格式 "HH:mm:ss"（用于计时器/秒表显示）
  static String formatDurationShort(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final h = hours.toString().padLeft(2, '0');
    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  static DateTime todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime monthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }
}
