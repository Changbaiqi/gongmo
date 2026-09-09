import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'stats_controller.dart';
import 'widgets/trend_chart.dart';
import 'widgets/donut_chart.dart';
import '../../core/widgets/count_up_text.dart';

class StatsView extends StatefulWidget {
  const StatsView({super.key});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView>
    with SingleTickerProviderStateMixin {
  late final StatsController _ctrl;
  late final AnimationController _switchAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(StatsController());
    _ctrl.reload();
  }

  @override
  void dispose() {
    _switchAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() => RefreshIndicator(
          onRefresh: () async => _ctrl.reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionEntrance(
                  key: const ValueKey('s_toggle'),
                  index: 0,
                  child: _buildPeriodToggle(cs)),
              const SizedBox(height: 10),
              _SectionEntrance(
                  key: const ValueKey('s_range'),
                  index: 1,
                  child: _buildRangeBar(cs)),
              const SizedBox(height: 12),
              _SectionEntrance(
                key: const ValueKey('s_content'),
                index: 2,
                child: FadeTransition(
                  opacity: CurvedAnimation(
                      parent: _switchAnim, curve: Curves.easeOut),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: _switchAnim, curve: Curves.easeOutCubic)),
                    child: Column(
                      children: [
                        _buildSummaryCard(cs),
                        const SizedBox(height: 12),
                        _buildTrendCard(cs),
                        const SizedBox(height: 12),
                        _buildCategoryCard(
                            cs,
                            '支出构成',
                            _ctrl.expenseSlices.toList(),
                            _ctrl.expense.value,
                            '总支出'),
                        const SizedBox(height: 12),
                        _buildCategoryCard(
                            cs,
                            '收入构成',
                            _ctrl.incomeSlices.toList(),
                            _ctrl.income.value,
                            '总收入'),
                      ],
                    ),
                  ),
                ),
              ),
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
        _switchAnim.forward(from: 0);
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
          onPressed: () {
            _ctrl.prevPeriod();
            _switchAnim.forward(from: 0);
          },
          icon: Icon(Icons.chevron_left_rounded,
              size: 22, color: cs.onSurfaceVariant),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.4),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              _ctrl.rangeLabel,
              key: ValueKey(_ctrl.rangeLabel),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton(
          onPressed: _ctrl.canGoNext
              ? () {
                  _ctrl.nextPeriod();
                  _switchAnim.forward(from: 0);
                }
              : null,
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
          CountUpText(
            value: value,
            formatter: (v) => '¥${v.toStringAsFixed(2)}',
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

  Widget _buildCategoryCard(
      ColorScheme cs, String title, List<CategorySlice> slices, double total,
      String centerLabel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            if (slices.isEmpty)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text('该时段暂无数据',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
                ),
              )
            else
              DonutChart(
                slices: slices,
                total: total,
                centerLabel: centerLabel,
              ),
          ],
        ),
      ),
    );
  }
}

/// 首次出现时从左滑入并淡入（按 index 交错延迟）
class _SectionEntrance extends StatefulWidget {
  const _SectionEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<_SectionEntrance> createState() => _SectionEntranceState();
}

class _SectionEntranceState extends State<_SectionEntrance> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 55 * widget.index.clamp(0, 8));
    Future.delayed(delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(-0.06, 0),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
