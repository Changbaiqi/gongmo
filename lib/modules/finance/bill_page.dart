import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/icon_utils.dart';
import '../../data/models/category.dart';
import '../../data/models/finance_entry.dart';
import 'finance_controller.dart';
import 'widgets/finance_detail_dialog.dart';

/// 月度账单：收支汇总（较上月）、支出分类排行、按日明细（点击查看详情）
class BillPage extends StatefulWidget {
  const BillPage({super.key});

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  late final FinanceController _fc = Get.isRegistered<FinanceController>()
      ? Get.find<FinanceController>()
      : Get.put(FinanceController());

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    // 首帧之后再刷新，避免在构建期间更新 RxList 触发
    // “setState() called during build” 断言
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fc.loadEntries();
    });
  }

  List<FinanceEntry> _entriesOf(DateTime m) => _fc.entries
      .where((e) => e.date.year == m.year && e.date.month == m.month)
      .toList();

  double _sumOf(List<FinanceEntry> list, FinanceType type) => list
      .where((e) => e.type == type)
      .fold(0.0, (s, e) => s + e.amount);

  void _shiftMonth(int delta) {
    setState(() =>
        _month = DateTime(_month.year, _month.month + delta));
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month),
    );
    if (picked == null) return;
    setState(() => _month = DateTime(picked.year, picked.month));
  }

  Category? _catOf(List<Category> cats, String id) {
    for (final c in cats) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('账单'), centerTitle: true),
      body: Obx(() {
        final entries = _entriesOf(_month);
        final income = _sumOf(entries, FinanceType.income);
        final expense = _sumOf(entries, FinanceType.expense);
        final prevExpense = _sumOf(
            _entriesOf(DateTime(_month.year, _month.month - 1)),
            FinanceType.expense);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildMonthBar(cs),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              _buildEmpty(cs)
            else ...[
              _buildSummary(cs, income, expense, prevExpense),
              const SizedBox(height: 12),
              _buildCategoryRank(cs, entries, expense),
              const SizedBox(height: 12),
              _buildDailyList(cs, entries),
            ],
          ],
        );
      }),
    );
  }

  /// 月份切换条
  Widget _buildMonthBar(ColorScheme cs) {
    return Row(
      children: [
        IconButton(
          onPressed: () => _shiftMonth(-1),
          icon: Icon(Icons.chevron_left_rounded,
              color: cs.onSurfaceVariant),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pickMonth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${_month.year}年${_month.month}月',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down_rounded,
                    size: 20, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: _isCurrentMonth ? null : () => _shiftMonth(1),
          icon: Icon(Icons.chevron_right_rounded,
              color: _isCurrentMonth
                  ? cs.outlineVariant.withValues(alpha: 0.5)
                  : cs.onSurfaceVariant),
        ),
      ],
    );
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  /// 收支汇总 + 与上月对比
  Widget _buildSummary(
      ColorScheme cs, double income, double expense, double prevExpense) {
    final balance = income - expense;
    String? compareText;
    Color compareColor = cs.onSurfaceVariant;
    IconData? compareIcon;
    if (prevExpense > 0) {
      final diff = expense - prevExpense;
      final pct = (diff.abs() / prevExpense * 100);
      compareText = diff >= 0
          ? '支出较上月增加 ${pct.toStringAsFixed(1)}%'
          : '支出较上月减少 ${pct.toStringAsFixed(1)}%';
      compareColor = diff >= 0 ? cs.error : Colors.green.shade600;
      compareIcon = diff >= 0
          ? Icons.trending_up_rounded
          : Icons.trending_down_rounded;
    }

    Widget item(String label, double value, Color color) => Expanded(
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.85))),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('¥${value.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ])),
              ),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                item('收入', income, Colors.green.shade600),
                Container(
                    width: 1,
                    height: 30,
                    color: cs.outlineVariant.withValues(alpha: 0.4)),
                item('支出', expense, cs.error),
                Container(
                    width: 1,
                    height: 30,
                    color: cs.outlineVariant.withValues(alpha: 0.4)),
                item('结余', balance,
                    balance >= 0 ? cs.primary : cs.error),
              ],
            ),
            if (compareText != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(compareIcon, size: 14, color: compareColor),
                  const SizedBox(width: 4),
                  Text(compareText,
                      style: TextStyle(
                          fontSize: 11.5, color: compareColor)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 支出分类排行（前 6）
  Widget _buildCategoryRank(
      ColorScheme cs, List<FinanceEntry> entries, double expense) {
    if (expense <= 0) return const SizedBox.shrink();
    final byCat = <String, double>{};
    for (final e in entries) {
      if (e.type != FinanceType.expense) continue;
      byCat[e.categoryId] = (byCat[e.categoryId] ?? 0) + e.amount;
    }
    if (byCat.isEmpty) return const SizedBox.shrink();
    final sorted = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('支出排行',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            for (final item in top) ...[
              _rankRow(cs, item.key, item.value, expense),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rankRow(
      ColorScheme cs, String catId, double amount, double total) {
    final cat = _catOf(_fc.categories, catId);
    final color = IconUtils.hex(cat?.color, cs.primary);
    final name = cat?.name ?? _fc.getCategoryName(catId);
    final pct = total > 0 ? amount / total : 0.0;
    return Row(
      children: [
        Icon(IconUtils.category(cat?.icon ?? ''), size: 16, color: color),
        const SizedBox(width: 8),
        SizedBox(
          width: 62,
          child: Text(name,
              style: const TextStyle(fontSize: 12.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 74,
          child: Text('¥${amount.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ),
      ],
    );
  }

  /// 按日明细
  Widget _buildDailyList(ColorScheme cs, List<FinanceEntry> entries) {
    final groups = <String, List<FinanceEntry>>{};
    final order = <String>[];
    for (final e in entries) {
      final key = DateHelper.formatDate(e.date);
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add(e);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('每日明细',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (final key in order) ...[
              _dayHeader(cs, groups[key]!),
              for (final e in groups[key]!) _entryRow(cs, e),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            Center(
              child: Text('点击任意条目查看详情',
                  style: TextStyle(
                      fontSize: 10.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayHeader(ColorScheme cs, List<FinanceEntry> list) {
    final date = list.first.date;
    final label = DateHelper.isSameDay(date, DateTime.now())
        ? '今天'
        : DateHelper.isSameDay(
                date, DateTime.now().subtract(const Duration(days: 1)))
            ? '昨天'
            : '${date.month}月${date.day}日';
    final income =
        _sumOf(list, FinanceType.income);
    final expense =
        _sumOf(list, FinanceType.expense);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant)),
          const Spacer(),
          if (income > 0)
            Text('收 ¥${income.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 11, color: Colors.green.shade600)),
          if (income > 0 && expense > 0) const SizedBox(width: 8),
          if (expense > 0)
            Text('支 ¥${expense.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 11, color: cs.error)),
        ],
      ),
    );
  }

  Widget _entryRow(ColorScheme cs, FinanceEntry e) {
    final cat = _catOf(_fc.categories, e.categoryId);
    final isIncome = e.type == FinanceType.income;
    final color = IconUtils.hex(cat?.color,
        isIncome ? Colors.green.shade600 : cs.primary);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showFinanceDetailDialog(context, _fc, e),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(IconUtils.category(cat?.icon ?? ''),
                  size: 15, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.description.isNotEmpty
                        ? e.description
                        : _fc.getCategoryName(e.categoryId),
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_fc.getCategoryName(e.categoryId)} · ${DateHelper.formatTime(e.date)}'
                    '${e.attachmentPaths.isNotEmpty ? ' · 附件${e.attachmentPaths.length}' : ''}',
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant
                            .withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            Text(
              '${isIncome ? '+' : '-'}¥${e.amount.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isIncome ? Colors.green.shade600 : cs.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 52, color: cs.outlineVariant),
          const SizedBox(height: 12),
          Text('${_month.year}年${_month.month}月暂无账目',
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}
