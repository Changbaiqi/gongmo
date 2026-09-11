// ============================================================
// stats/stats_controller.dart（Stats 模块 · 统计计算）
// 职责：按周/月/年区间聚合账目——收支汇总、趋势分桶、分类占比，
//       并管理区间切换（前后翻页、禁止进入未来区间）。
// 关联：只读 FinanceRepository 与 StorageService.categories；
//       由 StatsView 注册使用，TrendChart / DonutChart 消费其计算结果。
// ============================================================
import 'dart:ui';
import 'package:get/get.dart';
import '../../core/utils/icon_utils.dart';
import '../../data/models/category.dart';
import '../../data/models/finance_entry.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/services/storage_service.dart';

/// 统计区间粒度：周（周一起始）/ 月 / 年。
enum StatsPeriod { week, month, year }

/// 趋势图的一个数据点（横轴一格）：标签 + 该格收入/支出合计。
class TrendBucket {
  final String label;
  final double income;
  final double expense;
  const TrendBucket(this.label, this.income, this.expense);
}

/// 分类占比图的一片：分类名、颜色与金额（列表按金额降序）。
class CategorySlice {
  final String name;
  final Color color;
  final double amount;
  const CategorySlice(this.name, this.color, this.amount);
}

/// 统计控制器：以 [anchor] 为锚点、[period] 为粒度，计算一个时间区间的统计结果。
///
/// 生命周期：由 StatsView `Get.put` 创建；聚合结果都放在 Rx 里由 Obx 订阅。
/// 计算全程只读账目与分类，不写盘。
class StatsController extends GetxController {
  final FinanceRepository _financeRepo = FinanceRepository();

  final period = StatsPeriod.month.obs;
  final anchor = DateTime.now().obs;

  final income = 0.0.obs;
  final expense = 0.0.obs;
  final entryCount = 0.obs;
  final trendBuckets = <TrendBucket>[].obs;
  final expenseSlices = <CategorySlice>[].obs;
  final incomeSlices = <CategorySlice>[].obs;

  List<Category> get _categories => StorageService().categories;

  /// 当前区间起始时刻（含）：周=周一 00:00，月=当月 1 日，年=1 月 1 日。
  DateTime get rangeStart {
    final a = anchor.value;
    switch (period.value) {
      case StatsPeriod.week:
        final monday = a.subtract(Duration(days: a.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case StatsPeriod.month:
        return DateTime(a.year, a.month, 1);
      case StatsPeriod.year:
        return DateTime(a.year, 1, 1);
    }
  }

  /// 当前区间结束时刻（含），用于展示与判断能否继续向后翻页。
  DateTime get rangeEnd {
    final s = rangeStart;
    switch (period.value) {
      case StatsPeriod.week:
        return s.add(const Duration(days: 6));
      case StatsPeriod.month:
        return DateTime(s.year, s.month + 1, 0);
      case StatsPeriod.year:
        return DateTime(s.year, 12, 31);
    }
  }

  /// 是否允许向后翻：只有区间结束日早于今天才允许，避免翻到未来的空区间。
  bool get canGoNext {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return rangeEnd.isBefore(today);
  }

  /// 区间文案：周显示“x月x日 - x月x日”，月/年显示中文年月。
  String get rangeLabel {
    final s = rangeStart;
    final e = rangeEnd;
    switch (period.value) {
      case StatsPeriod.week:
        return '${s.month}月${s.day}日 - ${e.month}月${e.day}日';
      case StatsPeriod.month:
        return '${s.year}年${s.month}月';
      case StatsPeriod.year:
        return '${s.year}年';
    }
  }

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  /// 切换统计粒度：锚点重置回今天并重新聚合（切粒度后保留历史位置意义不大）。
  void setPeriod(StatsPeriod p) {
    if (period.value == p) return;
    period.value = p;
    anchor.value = DateTime.now();
    reload();
  }

  /// 向前翻一个区间（周 -7 天 / 月 -1 / 年 -12）并重新聚合。
  void prevPeriod() {
    switch (period.value) {
      case StatsPeriod.week:
        _shiftDays(-7);
        break;
      case StatsPeriod.month:
        _shiftMonths(-1);
        break;
      case StatsPeriod.year:
        _shiftMonths(-12);
        break;
    }
    reload();
  }

  /// 向后翻一个区间；已到当前时段时由 [canGoNext] 拦截。
  void nextPeriod() {
    if (!canGoNext) return;
    switch (period.value) {
      case StatsPeriod.week:
        _shiftDays(7);
        break;
      case StatsPeriod.month:
        _shiftMonths(1);
        break;
      case StatsPeriod.year:
        _shiftMonths(12);
        break;
    }
    reload();
  }

  void _shiftDays(int days) =>
      anchor.value = anchor.value.add(Duration(days: days));

  // DateTime 构造器会自动处理月末进位（如 1 月 31 日 +1 月 => 3 月 3 日），
  // 这里只用于翻页定位，这种归一化可以接受
  void _shiftMonths(int months) {
    final a = anchor.value;
    anchor.value = DateTime(a.year, a.month + months, a.day);
  }

  /// 重新聚合当前区间：总额、条目数、趋势分桶与分类占比。
  ///
  /// 过滤采用“左闭右开”：endExclusive 取结束日的次日零点，
  /// 保证结束日当天的记录全部计入。
  void reload() {
    final start = rangeStart;
    final endExclusive =
        DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day + 1);
    final entries = _financeRepo.getAll().where(
      (e) => !e.date.isBefore(start) && e.date.isBefore(endExclusive),
    ).toList();

    double inc = 0, exp = 0;
    for (final e in entries) {
      if (e.type == FinanceType.income) {
        inc += e.amount;
      } else if (e.type == FinanceType.expense) {
        exp += e.amount;
      }
    }
    income.value = inc;
    expense.value = exp;
    entryCount.value = entries.length;

    _buildTrend(entries, start);
    _buildCategorySlices(entries, FinanceType.expense, expenseSlices);
    _buildCategorySlices(entries, FinanceType.income, incomeSlices);
  }

  // 按粒度分桶并累加收入/支出：
  //   周 -> 7 桶，索引=与起始日相差天数（clamp 防越界）
  //   月 -> 当月天数桶，索引=date.day-1
  //   年 -> 12 桶，索引=date.month-1
  void _buildTrend(List<FinanceEntry> entries, DateTime start) {
    final List<TrendBucket> buckets;
    switch (period.value) {
      case StatsPeriod.week:
        const labels = ['一', '二', '三', '四', '五', '六', '日'];
        final inc = List.filled(7, 0.0);
        final exp = List.filled(7, 0.0);
        for (final e in entries) {
          final idx = e.date.difference(start).inDays.clamp(0, 6);
          if (e.type == FinanceType.income) {
            inc[idx] += e.amount;
          } else if (e.type == FinanceType.expense) {
            exp[idx] += e.amount;
          }
        }
        buckets = [
          for (var i = 0; i < 7; i++) TrendBucket(labels[i], inc[i], exp[i]),
        ];
        break;
      case StatsPeriod.month:
        final days = DateTime(start.year, start.month + 1, 0).day;
        final inc = List.filled(days, 0.0);
        final exp = List.filled(days, 0.0);
        for (final e in entries) {
          final idx = e.date.day - 1;
          if (e.type == FinanceType.income) {
            inc[idx] += e.amount;
          } else if (e.type == FinanceType.expense) {
            exp[idx] += e.amount;
          }
        }
        buckets = [
          for (var i = 0; i < days; i++)
            TrendBucket('${i + 1}', inc[i], exp[i]),
        ];
        break;
      case StatsPeriod.year:
        const labels = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
        final inc = List.filled(12, 0.0);
        final exp = List.filled(12, 0.0);
        for (final e in entries) {
          final idx = e.date.month - 1;
          if (e.type == FinanceType.income) {
            inc[idx] += e.amount;
          } else if (e.type == FinanceType.expense) {
            exp[idx] += e.amount;
          }
        }
        buckets = [
          for (var i = 0; i < 12; i++) TrendBucket(labels[i], inc[i], exp[i]),
        ];
        break;
    }
    trendBuckets.assignAll(buckets);
  }

  /// 按分类聚合指定收支类型的金额占比
  void _buildCategorySlices(List<FinanceEntry> entries, FinanceType type,
      RxList<CategorySlice> out) {
    final byId = <String, double>{};
    for (final e in entries) {
      if (e.type == type) {
        byId[e.categoryId] = (byId[e.categoryId] ?? 0) + e.amount;
      }
    }

    final slices = <CategorySlice>[];
    final unknownIds = <String>[];
    for (final entry in byId.entries) {
      Category? cat;
      for (final c in _categories) {
        if (c.id == entry.key) {
          cat = c;
          break;
        }
      }
      if (cat != null) {
        slices.add(CategorySlice(
          cat.name,
          IconUtils.hex(cat.color),
          entry.value,
        ));
      } else {
        unknownIds.add(entry.key);
      }
    }
    // 分类可能已被删除：匹配不到分类的条目合并成一条灰色“未分类”，避免金额丢失
    if (unknownIds.isNotEmpty) {
      final unknownSum =
          unknownIds.fold(0.0, (s, id) => s + (byId[id] ?? 0));
      slices.add(
          CategorySlice('未分类', const Color(0xFF9E9E9E), unknownSum));
    }
    // 按金额降序，饼图与图例从大到小展示
    slices.sort((a, b) => b.amount.compareTo(a.amount));
    out.assignAll(slices);
  }
}
