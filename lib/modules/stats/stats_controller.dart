import 'dart:ui';
import 'package:get/get.dart';
import '../../core/utils/icon_utils.dart';
import '../../data/models/category.dart';
import '../../data/models/finance_entry.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/services/storage_service.dart';

enum StatsPeriod { week, month, year }

class TrendBucket {
  final String label;
  final double income;
  final double expense;
  const TrendBucket(this.label, this.income, this.expense);
}

class CategorySlice {
  final String name;
  final Color color;
  final double amount;
  const CategorySlice(this.name, this.color, this.amount);
}

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

  bool get canGoNext {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return rangeEnd.isBefore(today);
  }

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

  void setPeriod(StatsPeriod p) {
    if (period.value == p) return;
    period.value = p;
    anchor.value = DateTime.now();
    reload();
  }

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

  void _shiftMonths(int months) {
    final a = anchor.value;
    anchor.value = DateTime(a.year, a.month + months, a.day);
  }

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
    if (unknownIds.isNotEmpty) {
      final unknownSum =
          unknownIds.fold(0.0, (s, id) => s + (byId[id] ?? 0));
      slices.add(
          CategorySlice('未分类', const Color(0xFF9E9E9E), unknownSum));
    }
    slices.sort((a, b) => b.amount.compareTo(a.amount));
    out.assignAll(slices);
  }
}
