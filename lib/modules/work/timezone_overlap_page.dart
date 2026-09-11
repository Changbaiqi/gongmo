// ============================================================
// timezone_overlap_page.dart（时区重叠图）
// 职责：以本地 0–23 时为列，展示各时区的当地时刻、日期差与 9:00–18:00
//       工作时段，并计算所有选中时区的共同重叠小时
// 关联：时区列表存 StorageService 配置 'tz_overlap_zones'；复用 tz_widgets；
//       从 TimeMorePage 进入
// ============================================================
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/tz_setup.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/tap_scale.dart';
import '../../data/services/storage_service.dart';
import 'tz_widgets.dart';

/// 时区重叠图：以本地时间为基准，查看各时区一天中的工作时段与共同重叠时段
///
/// 算法：对本地每个整点 h（0–23），换算到各时区取当地小时；
/// 若所有选中时区在该列的当地小时都落在 `[9, 18)` 内，则 h 属于共同工作时段。
class TimezoneOverlapPage extends StatefulWidget {
  const TimezoneOverlapPage({super.key});

  @override
  State<TimezoneOverlapPage> createState() => _TimezoneOverlapPageState();
}

class _TimezoneOverlapPageState extends State<TimezoneOverlapPage> {
  static const _configKey = 'tz_overlap_zones';
  static const _workStart = 9; // 工作时段起（含）
  static const _workEnd = 18; // 工作时段止（不含），即 [9, 18)

  late List<String> _selected; // 参与对比的时区
  bool _ready = false; // timezone 数据库是否就绪
  int? _selectedHour; // 点击列高亮的小时（null 表示未选）

  @override
  void initState() {
    super.initState();
    final raw = StorageService().getConfig(_configKey);
    // 读取已存时区，并过滤掉当前选项表中已不存在的 id
    final saved = raw is List
        ? raw
            .map((e) => '$e')
            .where((id) => tzOptions.any((z) => z.id == id))
            .toList()
        : <String>[];
    _selected = saved.isEmpty
        ? ['Asia/Shanghai', 'Europe/London', 'America/New_York']
        : saved;
    _init();
  }

  Future<void> _init() async {
    await ensureTimezonesInitialized();
    if (mounted) setState(() => _ready = true);
  }

  void _save() => StorageService().setConfig(_configKey, _selected);

  /// 打开时区多选面板；变化后保存并清空列高亮
  Future<void> _manageZones() async {
    final picked = await showZonePicker(context, _selected);
    if (picked == null || picked.isEmpty) return;
    setState(() {
      _selected = picked;
      _selectedHour = null;
    });
    _save();
  }

  /// 当地小时是否属于工作时段（左闭右开）
  bool _isWork(int h) => h >= _workStart && h < _workEnd;

  String _two(int v) => v.toString().padLeft(2, '0');

  /// 把离散的小时列表合并成连续区间文案，如 [9,10,14] → “09:00-11:00、14:00-15:00”
  String _overlapLabel(List<int> hours) {
    if (hours.isEmpty) return '没有共同工作时段';
    final ranges = <String>[];
    var start = hours.first;
    var prev = hours.first;
    // 遇到断点（不连续）就收束当前区间，另起一段
    for (final h in hours.skip(1)) {
      if (h == prev + 1) {
        prev = h;
        continue;
      }
      ranges.add(_rangeText(start, prev));
      start = h;
      prev = h;
    }
    ranges.add(_rangeText(start, prev));
    return ranges.join('、');
  }

  /// 区间文案按半开区间展示，23 点所在区间的终点显示为 24:00
  String _rangeText(int a, int b) =>
      '${_two(a)}:00-${b == 23 ? '24' : _two(b + 1)}:00';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_ready) {
      return Scaffold(
        appBar: AppBar(title: const Text('时区重叠图'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final base = tz.local; // 以设备本地时区为基准列
    final now = tz.TZDateTime.now(base);
    final hoursByZone = <String, List<int>>{}; // 时区 → 本地 0..23 点对应当地小时
    final dayByZone = <String, List<int>>{}; // 时区 → 对应日期差（⁺次日/⁻前日）
    for (final id in _selected) {
      final zone = tz.getLocation(id);
      final hs = <int>[];
      final ds = <int>[];
      for (var h = 0; h < 24; h++) {
        // 今天本地 h 点，同一时刻换算到目标时区的当地小时与自然日
        final t = tz.TZDateTime(base, now.year, now.month, now.day, h);
        final zt = tz.TZDateTime.from(t, zone);
        hs.add(zt.hour);
        ds.add(DateTime(zt.year, zt.month, zt.day)
            .difference(DateTime(t.year, t.month, t.day))
            .inDays);
      }
      hoursByZone[id] = hs;
      dayByZone[id] = ds;
    }
    // 共同工作时段：该列所有时区的当地小时都在工作时段内
    final overlap = [
      for (var h = 0; h < 24; h++)
        if (_selected.every((id) => _isWork(hoursByZone[id]![h]))) h,
    ];

    const cellW = 34.0;
    const cellH = 34.0;
    const leftW = 118.0;

    // 顶部小时格：属于共同重叠时段用 tertiary 底色，点击可高亮整列
    Widget headerCell(int h) {
      final hot = overlap.contains(h);
      final sel = _selectedHour == h;
      return TapScale(
        onTap: () => setState(
            () => _selectedHour = _selectedHour == h ? null : h),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: cellW,
          height: cellH,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel
                ? cs.primary.withValues(alpha: 0.85)
                : (hot ? cs.tertiary.withValues(alpha: 0.18) : null),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('$h',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight:
                      (hot || sel) ? FontWeight.w700 : FontWeight.normal,
                  color: sel
                      ? cs.onPrimary
                      : (hot ? cs.tertiary : cs.onSurfaceVariant))),
        ),
      );
    }

    // 时区数据格：绿色表示当地工作时段，⁺/⁻ 表示日期晚/早一天
    Widget zoneCell(String id, int h) {
      final hour = hoursByZone[id]![h];
      final day = dayByZone[id]![h];
      final work = _isWork(hour);
      final sel = _selectedHour == h;
      final mark = day > 0 ? '⁺' : (day < 0 ? '⁻' : '');
      return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: cellW,
        height: cellH,
        alignment: Alignment.center,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: sel
              ? (work
                  ? const Color(0xFF66BB6A).withValues(alpha: 0.5)
                  : cs.primary.withValues(alpha: 0.16))
              : (work
                  ? const Color(0xFF66BB6A).withValues(alpha: 0.22)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(6),
          border: sel
              ? Border.all(
                  color: cs.primary.withValues(alpha: 0.75), width: 1.2)
              : null,
        ),
        child: Text('$hour$mark',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                color: work ? cs.onSurface : cs.onSurfaceVariant)),
      );
    }

    // 左侧城市列：当前当地时刻 + 日期差标记
    Widget leftCell(String id) {
      final zn = tz.TZDateTime.now(tz.getLocation(id));
      final day = DateTime(zn.year, zn.month, zn.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
      final mark = day > 0 ? '⁺' : (day < 0 ? '⁻' : '');
      return Container(
        width: leftW,
        height: cellH,
        padding: const EdgeInsets.only(right: 8),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(tzCity(id),
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ),
            Text('${_two(zn.hour)}:${_two(zn.minute)}$mark',
                style: TextStyle(
                    fontSize: 10.5,
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('时区重叠图'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '管理时区',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _manageZones,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FadeSlideIn(index: 0, child: _buildSummaryCard(cs, base, overlap)),
          const SizedBox(height: 12),
          FadeSlideIn(
            key: ValueKey(_selected.join(',')),
            index: 1,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            SizedBox(
                              width: leftW,
                              height: cellH,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text('城市 / 本地时',
                                    style: TextStyle(
                                        fontSize: 9.5,
                                        color: cs.onSurfaceVariant)),
                              ),
                            ),
                            for (final id in _selected) leftCell(id),
                          ],
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    for (var h = 0; h < 24; h++)
                                      headerCell(h)
                                  ],
                                ),
                                for (final id in _selected)
                                  Row(
                                    children: [
                                      for (var h = 0; h < 24; h++)
                                        zoneCell(id, h)
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    _buildHourInfo(
                        cs,
                        _selectedHour,
                        hoursByZone,
                        dayByZone),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 2,
            child: Text(
              '提示：格内数字为该时区当地时刻，⁺/⁻ 表示比基准日期晚/早一天；'
              '绿色为当地工作时段。点击顶部小时可查看该时刻各地区时间。',
              style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  /// 概览卡片：共同工作时段文案 + 图例
  Widget _buildSummaryCard(
      ColorScheme cs, tz.Location base, List<int> overlap) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('共同工作时段',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                TapScale(
                  onTap: _manageZones,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 16, color: cs.primary),
                        const SizedBox(width: 4),
                        Text('管理时区',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: cs.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '基准：本地时间（${base.name}）　工作时段 '
              '$_workStart:00-$_workEnd:00',
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.tertiary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_available_rounded,
                      size: 16, color: cs.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.4),
                            end: Offset.zero,
                          ).animate(a),
                          child: c,
                        ),
                      ),
                      child: Text(
                        _overlapLabel(overlap),
                        key: ValueKey(_overlapLabel(overlap)),
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: cs.tertiary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _legend(cs),
          ],
        ),
      ),
    );
  }

  /// 选中小时后的各时区时间信息条（展开/收起动画）
  Widget _buildHourInfo(
    ColorScheme cs,
    int? hour,
    Map<String, List<int>> hoursByZone,
    Map<String, List<int>> dayByZone,
  ) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: hour == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本地 ${_two(hour)}:00 时，各地当地时间',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary),
                  ),
                  const SizedBox(height: 8),
                  for (final id in _selected)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(tzCity(id),
                                style: const TextStyle(fontSize: 12.5)),
                          ),
                          Text(
                            '${_two(hoursByZone[id]![hour])}:00'
                            '${dayByZone[id]![hour] > 0 ? ' (次日)' : (dayByZone[id]![hour] < 0 ? ' (前日)' : '')}',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _isWork(hoursByZone[id]![hour])
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  /// 图例：工作时段 / 非工作时段 / 共同重叠
  Widget _legend(ColorScheme cs) {
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 4),
            Text(label,
                style:
                    TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
          ],
        );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(const Color(0xFF66BB6A).withValues(alpha: 0.35), '工作时段'),
        item(cs.surfaceContainerHighest.withValues(alpha: 0.6), '非工作时段'),
        item(cs.tertiary.withValues(alpha: 0.3), '共同重叠'),
      ],
    );
  }
}
