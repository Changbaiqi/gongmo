import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'stats_controller.dart';
import 'widgets/trend_chart.dart';
import 'widgets/donut_chart.dart';

class StatsView extends StatefulWidget {
  const StatsView({super.key});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  late final StatsController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(StatsController());
    _ctrl.reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() => RefreshIndicator(
          onRefresh: () async => _ctrl.reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildPeriodToggle(cs),
              const SizedBox(height: 10),
              _buildRangeBar(cs),
              const SizedBox(height: 12),
              _buildSummaryCard(cs),
              const SizedBox(height: 12),
              _buildTrendCard(cs),
              const SizedBox(height: 12),
              _buildCategoryCard(cs),
              const SizedBox(height: 8),
            ],
          ),
        ));
  }

  Widget _buildPeriodToggle(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _periodSegment('周', StatsPeriod.week, cs),
          ),
          Expanded(
            child: _periodSegment('月', StatsPeriod.month, cs),
          ),
          Expanded(
            child: _periodSegment('年', StatsPeriod.year, cs),
          ),
        ],
      ),
    );
  }

  Widget _periodSegment(String label, StatsPeriod p, ColorScheme cs) {
    final active = _ctrl.period.value == p;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _ctrl.setPeriod(p);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                color: active
                    ? cs.primary
                    : cs.onSurfaceVariant.withValues(alpha: 0.7),
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              )),
        ),
      ),
    );
  }

  Widget _buildRangeBar(ColorScheme cs) {
    return Row(
      children: [
        IconButton(
          onPressed: _ctrl.prevPeriod,
          icon: Icon(Icons.chevron_left_rounded,
              size: 22, color: cs.onSurfaceVariant),
        ),
        Expanded(
          child: Text(
            _ctrl.rangeLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          onPressed: _ctrl.canGoNext ? _ctrl.nextPeriod : null,
          icon: Icon(Icons.chevron_right_rounded,
              size: 22,
              color: _ctrl.canGoNext
                  ? cs.onSurfaceVariant
                  : cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            _summaryItem('收入', _ctrl.income.value, Colors.green.shade600),
            _divider(),
            _summaryItem('支出', _ctrl.expense.value, Colors.red.shade600),
            _divider(),
            _summaryItem(
              '结余',
              _ctrl.income.value - _ctrl.expense.value,
              _ctrl.income.value - _ctrl.expense.value >= 0
                  ? cs.primary
                  : Colors.red.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, double value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.8))),
          const SizedBox(height: 4),
          Text(
            '¥${value.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 32,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }

  Widget _buildTrendCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('收支趋势',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                _legendDot(Colors.green, '收入'),
                const SizedBox(width: 12),
                _legendDot(const Color(0xFFEF5350), '支出'),
              ],
            ),
            const SizedBox(height: 12),
            if (_ctrl.entryCount.value == 0)
              SizedBox(
                height: 180,
                child: Center(
                  child: Text('该时段暂无数据',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
                ),
              )
            else
              TrendChart(buckets: _ctrl.trendBuckets.toList()),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color:
                    Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildCategoryCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('支出构成',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            if (_ctrl.expenseSlices.isEmpty)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text('该时段暂无支出',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
                ),
              )
            else
              DonutChart(
                slices: _ctrl.expenseSlices.toList(),
                total: _ctrl.expense.value,
              ),
          ],
        ),
      ),
    );
  }
}
