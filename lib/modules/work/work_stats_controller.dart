// ============================================================
// work_stats_controller.dart（工时统计聚合）
// 职责：按日/周/月/年把计时记录聚合成总时长、日均、趋势柱与标签占比
// 关联：读 WorkRepository 与 StorageService（标签颜色）；供 WorkStatsView
//       及图表组件使用，由统计页 Get.put 创建
// ============================================================
import 'dart:ui';
import 'package:get/get.dart';
import '../../core/utils/icon_utils.dart';
import '../../data/models/timer_tag.dart';
import '../../data/repositories/work_repository.dart';
import '../../data/models/work_entry.dart';
import '../../data/services/storage_service.dart';
import '../stats/stats_controller.dart' show CategorySlice;

/// 统计周期：日/周（周一起）/月/年
enum WorkStatsPeriod { day, week, month, year }

/// 时长趋势的一个分桶（横轴标签 + 该桶内累计分钟数）
class WorkTrendBucket {
  final String label; // 横轴标签：如 "13时" / "周三" / "12"（日） / "3月"
  final double minutes; // 分桶累计时长（分钟）
  const WorkTrendBucket(this.label, this.minutes);
}

/// 工时统计控制器：围绕 `anchor` + `period` 计算一个时间区间并聚合
///
/// 聚合规则：只统计 `completed` 记录，按 `startTime` 归属区间，
/// 时长统一按分钟累加（不足 1 分钟会被 inMinutes 截断）。
class WorkStatsController extends GetxController {
  final WorkRepository _workRepo = WorkRepository();

  final period = WorkStatsPeriod.day.obs; // 当前统计周期
  final anchor = DateTime.now().obs; // 当前锚点日期，翻页时平移

  /// 月历筛选：null=全部标签，否则为标签名
  final tagFilter = Rxn<String>();
  final monthDayMinutes = <int, double>{}.obs; // 月历：日(1..31) → 分钟

  List<TimerTag> get timerTags => StorageService().timerTags;

  /// 月历按标签筛选（null 表示全部标签），改完立即重算
  void setTagFilter(String? tag) {
    tagFilter.value = tag;
    refresh();
  }

  final totalMinutes = 0.0.obs; // 区间内总时长（分钟）
  final entryCount = 0.obs; // 区间内记录条数
  final avgMinutes = 0.0.obs; // 日均时长（按已过天数折算）
  final trendBuckets = <WorkTrendBucket>[].obs; // 趋势分桶
  final tagSlices = <CategorySlice>[].obs; // 标签占比切片（复用统计页环形图结构）

  /// 区间起点（含）：日=当天 0 点；周=周一（weekday-1 天前）；月=1 号；年=1 月 1 日
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

  /// 区间终点（含当天）：日=同一天；周=周日；月=当月最后一天（下月 0 号）；年=12 月 31 日
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

  /// 是否允许向后翻页：未来区间没有数据，直接禁用
  bool get canGoNext {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return rangeEnd.isBefore(today);
  }

  /// 当前区间的可读文案（显示在翻页栏中间）
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

  /// 切换统计周期，锚点重置为“现在”，避免停留在旧周期的翻页位置
  void setPeriod(WorkStatsPeriod p) {
    if (period.value == p) return;
    period.value = p;
    anchor.value = DateTime.now();
    reload();
  }

  /// 向前翻一个周期（日/周按天数，月/年按月数）
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

  /// 向后翻一个周期（不能翻到未来）
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

  /// 按月平移：DateTime 会自动处理跨年，日期溢出（如 31 号）由构造器归一化
  void _shiftMonths(int months) {
    final a = anchor.value;
    anchor.value = DateTime(a.year, a.month + months, a.day);
  }

  /// 重算当前区间的全部统计（周期/锚点/标签筛选变化后调用）
  void reload() {
    final start = rangeStart;
    // 用“次日 0 点”作开区间上界，避免逐字段比较日期带来的边界麻烦
    final endExclusive =
        DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day + 1);
    // 只统计已完成记录，并按 startTime 归属区间
    final entries = _workRepo.getAll().where(
      (e) =>
          e.status == WorkStatus.completed &&
          !e.startTime.isBefore(start) &&
          e.startTime.isBefore(endExclusive),
    ).toList();

    double totalMinutesSum = 0;
    final byTag = <String, double>{};
    for (final e in entries) {
      // 统一按分钟聚合，秒级误差会被舍去
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

    // 日均：按时段内“已过天数”折算；若区间已结束则用满期天数，
    // 否则只除以从区间起点到今天的实际天数（当天算 1 天）
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

  /// 生成趋势分桶：日=24 小时、周=7 天（周一起）、月=当月天数、年=12 个月
  ///
  /// 所有下标都用 `clamp` 兜底，理论上区间过滤已保证不越界。
  void _buildTrend(List<WorkEntry> entries, DateTime start) {
    List<WorkTrendBucket> buckets;
    switch (period.value) {
      case WorkStatsPeriod.day:
        // 按开始时刻的小时分桶
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
        // 周一为第 0 桶，与 rangeStart 的周一基准一致
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
        // 当月天数用“下月 0 号”求得
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
        // 按月份分桶
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

  /// 按标签名生成占比切片：颜色取同名 TimerTag，打卡固定绿色，找不到用灰色兜底
  void _buildTagSlices(Map<String, double> byTag) {
    final tags = StorageService().timerTags;
    final slices = <CategorySlice>[];
    for (final entry in byTag.entries) {
      Color color = const Color(0xFF9E9E9E);
      // 打卡不属于普通标签，单独给绿色
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
    slices.sort((a, b) => b.amount.compareTo(a.amount)); // 占比大者在前
    tagSlices.assignAll(slices);
  }
}
