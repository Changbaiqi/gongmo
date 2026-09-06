import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../stats/widgets/donut_chart.dart' show DonutChart;
import 'month_duration_calendar.dart';
import '../work_stats_controller.dart';
import 'duration_bar_chart.dart';

/// 时钟页「统计」子页：计时数据统计（日/周/月/年 + 标签占比）
class WorkStatsView extends StatefulWidget {
  const WorkStatsView({super.key});

  @override
  State<WorkStatsView> createState() => _WorkStatsViewState();
}

class _WorkStatsViewState extends State<WorkStatsView> {
  late final WorkStatsController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(WorkStatsController());
    _ctrl.reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
              _buildPeriodToggle(cs),
              const SizedBox(height: 8),
              _buildRangeBar(cs),
              const SizedBox(height: 12),
              if (_ctrl.period.value == WorkStatsPeriod.month) ...[
                _buildMonthCalendarCard(cs),
                const SizedBox(height: 12),
              ],
              _buildSummaryCard(cs),
            const SizedBox(height: 12),
            _buildTrendCard(cs),
            const SizedBox(height: 12),
            _buildTagCard(cs),
            const SizedBox(height: 8),
          ],
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
              child: _segment('日', WorkStatsPeriod.day, cs)),
          Expanded(
              child: _segment('周', WorkStatsPeriod.week, cs)),
          Expanded(
              child: _segment('月', WorkStatsPeriod.month, cs)),
          Expanded(
              child: _segment('年', WorkStatsPeriod.year, cs)),
        ],
      ),
    );
  }

  Widget _segment(String label, WorkStatsPeriod p, ColorScheme cs) {
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
          color:
              active ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
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
        child: Obx(() => Row(
              children: [
                _summaryItem(
                  context,
                  '总时长',
                  formatMinutes(_ctrl.totalMinutes.value),
                  cs.primary,
                ),
                _divider(cs),
                _summaryItem(
                  context,
                  '记录数',
                  '${_ctrl.entryCount.value} 条',
                  cs.onSurface,
                ),
                _divider(cs),
                _summaryItem(
                  context,
                  '日均时长',
                  formatMinutes(_ctrl.avgMinutes.value),
                  cs.tertiary,
                ),
              ],
            )),
      ),
    );
  }

  Widget _summaryItem(
      BuildContext context, String label, String value, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8))),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 14.5,
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

  Widget _divider(ColorScheme cs) {
    return Container(
      width: 1,
      height: 32,
      color: cs.outlineVariant.withValues(alpha: 0.4),
    );
  }

  /// 月视图：日历时长（每天下方显示所选标签的时长，右上角下拉切换）
  Widget _buildMonthCalendarCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('每日时长',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _ctrl.tagFilter.value,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    borderRadius: BorderRadius.circular(10),
                    style:
                        TextStyle(fontSize: 12.5, color: cs.onSurface),
                    icon: Icon(Icons.arrow_drop_down_rounded,
                        color: cs.onSurfaceVariant),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('全部标签',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                      ..._ctrl.timerTags
                          .map((t) => DropdownMenuItem<String>(
                                value: t.name,
                                child: Text(t.name,
                                    style: const TextStyle(fontSize: 12.5)),
                              )),
                    ],
                    onChanged: (v) => _ctrl.setTagFilter(v),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              MonthDurationCalendar(
                month: _ctrl.anchor.value,
                dayMinutes: _ctrl.monthDayMinutes,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('时长趋势',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_ctrl.entryCount.value == 0)
              SizedBox(
                height: 160,
                child: Center(
                  child: Text('该时段暂无数据',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
                ),
              )
            else
              DurationBarChart(
                buckets: _ctrl.trendBuckets.toList(),
                barColor: cs.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('标签占比',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            if (_ctrl.tagSlices.isEmpty)
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
                slices: _ctrl.tagSlices.toList(),
                total: _ctrl.totalMinutes.value,
                centerLabel: '总时长',
                formatAmount: formatMinutes,
              ),
          ],
        ),
      ),
    );
  }
}
