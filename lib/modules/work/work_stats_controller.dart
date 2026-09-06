import 'dart:ui';
import 'package:get/get.dart';
import '../../core/utils/icon_utils.dart';
import '../../data/models/timer_tag.dart';
import '../../data/repositories/work_repository.dart';
import '../../data/models/work_entry.dart';
import '../../data/services/storage_service.dart';
import '../stats/stats_controller.dart' show CategorySlice;

enum WorkStatsPeriod { day, week, month, year }

/// 时长趋势分桶
class WorkTrendBucket {
  final String label;
  final double minutes;
  const WorkTrendBucket(this.label, this.minutes);
}

class WorkStatsController extends GetxController {
  final WorkRepository _workRepo = WorkRepository();

  final period = WorkStatsPeriod.day.obs;
  final anchor = DateTime.now().obs;

  /// 月历筛选：null=全部标签，否则为标签名
  final tagFilter = Rxn<String>();
  final monthDayMinutes = <int, double>{}.obs;

  List<TimerTag> get timerTags => StorageService().timerTags;

  void setTagFilter(String? tag) {
    tagFilter.value = tag;
    refresh();
  }

  final totalMinutes = 0.0.obs;
  final entryCount = 0.obs;
  final avgMinutes = 0.0.obs;
  final trendBuckets = <WorkTrendBucket>[].obs;
  final tagSlices = <CategorySlice>[].obs;

  DateTime get rangeStart {
    final a = anchor.value;
    switch (period.value) {
      case WorkStatsPeriod.day:
        return DateTime(a.year, a.month, a.day);
      case WorkStatsPeriod.week:
        final monday = a.subtract(Duration(days: a.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case WorkStatsPeriod.month:
        return DateTime(a.year, a.month, 1);
      case WorkStatsPeriod.year:
        return DateTime(a.year, 1, 1);
    }
  }

  DateTime get rangeEnd {
    final s = rangeStart;
    switch (period.value) {
      case WorkStatsPeriod.day:
        return s;
      case WorkStatsPeriod.week:
        return s.add(const Duration(days: 6));
      case WorkStatsPeriod.month:
        return DateTime(s.year, s.month + 1, 0);
      case WorkStatsPeriod.year:
        return DateTime(s.year, 12, 31);
    }
  }

  bool get canGoNext {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return rangeEnd.isBefore(today);
  }

  String get rangeLabel {
    final s = rangeStart;
    final e = rangeEnd;
    switch (period.value) {
      case WorkStatsPeriod.day:
        return '${s.month}月${s.day}日';
      case WorkStatsPeriod.week:
        return '${s.month}月${s.day}日 - ${e.month}月${e.day}日';
      case WorkStatsPeriod.month:
        return '${s.year}年${s.month}月';
      case WorkStatsPeriod.year:
        return '${s.year}年';
    }
  }

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  void setPeriod(WorkStatsPeriod p) {
    if (period.value == p) return;
    period.value = p;
    anchor.value = DateTime.now();
    reload();
  }

  void prevPeriod() {
    switch (period.value) {
      case WorkStatsPeriod.day:
        _shiftDays(-1);
        break;
      case WorkStatsPeriod.week:
        _shiftDays(-7);
        break;
      case WorkStatsPeriod.month:
        _shiftMonths(-1);
        break;
      case WorkStatsPeriod.year:
        _shiftMonths(-12);
        break;
    }
    reload();
  }

  void nextPeriod() {
    if (!canGoNext) return;
    switch (period.value) {
      case WorkStatsPeriod.day:
        _shiftDays(1);
        break;
      case WorkStatsPeriod.week:
        _shiftDays(7);
        break;
      case WorkStatsPeriod.month:
        _shiftMonths(1);
        break;
      case WorkStatsPeriod.year:
        _shiftMonths(12);
        break;
    }
    reload();
  }

  void _shiftDays(int days) =>
      anchor.value = anchor.value.add(Duration(days: days));

  void _shiftMonths(int months) {
    final a = anchor.value;
    anchor.value = DateTime(a.year, a.month + months, a.day);
  }

  void reload() {
    final start = rangeStart;
    final endExclusive =
        DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day + 1);
    final entries = _workRepo.getAll().where(
      (e) =>
          e.status == WorkStatus.completed &&
          !e.startTime.isBefore(start) &&
          e.startTime.isBefore(endExclusive),
    ).toList();

    double totalMinutesSum = 0;
    final byTag = <String, double>{};
    for (final e in entries) {
      final mins = (e.duration?.inMinutes ?? 0).toDouble();
      totalMinutesSum += mins;
      final key = e.projectName.isNotEmpty ? e.projectName : '未命名';
      byTag[key] = (byTag[key] ?? 0) + mins;
    }
    totalMinutes.value = totalMinutesSum;
    entryCount.value = entries.length;

    // 月历：按天聚合时长（可按标签筛选）
    final dayMap = <int, double>{};
    for (final e in entries) {
      if (tagFilter.value != null && e.projectName != tagFilter.value) {
        continue;
      }
      dayMap[e.startTime.day] = (dayMap[e.startTime.day] ?? 0) +
          (e.duration?.inMinutes ?? 0).toDouble();
    }
    monthDayMinutes
      ..clear()
      ..addAll(dayMap);

    // 日均：按时段内已过天数折算
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodDays = rangeEnd.difference(rangeStart).inDays + 1;
    final elapsedDays = rangeEnd.isBefore(today)
        ? periodDays
        : today.difference(rangeStart).inDays + 1;
    avgMinutes.value =
        elapsedDays > 0 ? totalMinutesSum / elapsedDays : 0;

    _buildTrend(entries, start);
    _buildTagSlices(byTag);
  }

  void _buildTrend(List<WorkEntry> entries, DateTime start) {
    List<WorkTrendBucket> buckets;
    switch (period.value) {
      case WorkStatsPeriod.day:
        final mins = List.filled(24, 0.0);
        for (final e in entries) {
          mins[e.startTime.hour.clamp(0, 23)] +=
              (e.duration?.inMinutes ?? 0).toDouble();
        }
        buckets = [
          for (var i = 0; i < 24; i++) WorkTrendBucket('$i时', mins[i]),
        ];
        break;
      case WorkStatsPeriod.week:
        const labels = ['一', '二', '三', '四', '五', '六', '日'];
        final mins = List.filled(7, 0.0);
        for (final e in entries) {
          final idx = e.startTime.difference(start).inDays.clamp(0, 6);
          mins[idx] += (e.duration?.inMinutes ?? 0).toDouble();
        }
        buckets = [
          for (var i = 0; i < 7; i++) WorkTrendBucket(labels[i], mins[i]),
        ];
        break;
      case WorkStatsPeriod.month:
        final days = DateTime(start.year, start.month + 1, 0).day;
        final mins = List.filled(days, 0.0);
        for (final e in entries) {
          mins[(e.startTime.day - 1).clamp(0, days - 1)] +=
              (e.duration?.inMinutes ?? 0).toDouble();
        }
        buckets = [
          for (var i = 0; i < days; i++)
            WorkTrendBucket('${i + 1}', mins[i]),
        ];
        break;
      case WorkStatsPeriod.year:
        const labels = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
        final mins = List.filled(12, 0.0);
        for (final e in entries) {
          mins[(e.startTime.month - 1).clamp(0, 11)] +=
              (e.duration?.inMinutes ?? 0).toDouble();
        }
        buckets = [
          for (var i = 0; i < 12; i++) WorkTrendBucket(labels[i], mins[i]),
        ];
        break;
    }
    trendBuckets.assignAll(buckets);
  }

  void _buildTagSlices(Map<String, double> byTag) {
    final tags = StorageService().timerTags;
    final slices = <CategorySlice>[];
    for (final entry in byTag.entries) {
      Color color = const Color(0xFF9E9E9E);
      if (entry.key == '打卡') {
        color = const Color(0xFF4CAF50);
      } else {
        for (final t in tags) {
          if (t.name == entry.key) {
            color = IconUtils.hex(t.color);
            break;
          }
        }
      }
      slices.add(CategorySlice(entry.key, color, entry.value));
    }
    slices.sort((a, b) => b.amount.compareTo(a.amount));
    tagSlices.assignAll(slices);
  }
}
