// ============================================================
// hourly_rate_page.dart（时钟模块 · 时薪计算器）
// 职责：选择标签与月份，统计这些月份中该标签的计时总时长，
//       结合用户输入的月薪折算平均时薪（月薪 × 月数 ÷ 总时长），
//       并按有记录的天数折算每天收入（月薪 × 月数 ÷ 天数）。
// 关联：数据来自 StorageService.workEntries（仅已完成记录）与 timerTags；
//       输入项存 config.json 的 hourly_rate_config 键；入口在「更多」页。
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/count_up_text.dart';
import '../../data/models/work_entry.dart';
import '../../data/services/storage_service.dart';

/// 时薪计算器：按标签时长 + 月薪估算时薪。
class HourlyRatePage extends StatefulWidget {
  const HourlyRatePage({super.key});

  @override
  State<HourlyRatePage> createState() => _HourlyRatePageState();
}

class _HourlyRatePageState extends State<HourlyRatePage> {
  static const _configKey = 'hourly_rate_config';

  final _salaryCtrl = TextEditingController();

  late final List<WorkEntry> _entries; // 已完成的计时记录
  late final List<String> _tags; // 可选标签
  late final List<String> _months; // 可选月份（yyyy-MM，新在前）
  final Set<String> _selectedMonths = {};
  String? _tag;

  /// 当前标签在各月份的分钟数（随标签变化重算）
  Map<String, double> _monthMinutes = {};

  /// 选中月份的总分钟数
  double _totalMinutes = 0;

  /// 选中范围内有记录的天数（每天收入按此天数折算）
  Set<String> _workDays = {};

  @override
  void initState() {
    super.initState();
    _entries = StorageService()
        .workEntries
        .where((e) => e.status == WorkStatus.completed && e.duration != null)
        .toList();
    _collectTags();
    _collectMonths();
    _loadConfig();
    _tag ??= _autoTag();
    if (_selectedMonths.isEmpty) {
      final latest = _tag == null ? null : _latestMonthOf(_tag!);
      if (latest != null) {
        _selectedMonths.add(latest);
      } else if (_months.isNotEmpty) {
        _selectedMonths.add(_months.first);
      }
    }
    _rebuildMonthMinutes();
    _rebuildSelectedStats();
    _salaryCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _saveConfig();
    _salaryCtrl.removeListener(_onChanged);
    _salaryCtrl.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  // ---------------- 数据准备 ----------------

  static String _tagOf(WorkEntry e) =>
      e.projectName.isNotEmpty ? e.projectName : '未命名';

  static String _monthKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}';

  static String _dayKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  /// 可选标签：标签列表 + 记录中出现过的标签，按累计时长降序
  void _collectTags() {
    final minutes = <String, double>{};
    for (final t in StorageService().timerTags) {
      if (t.name.isNotEmpty) minutes.putIfAbsent(t.name, () => 0);
    }
    for (final e in _entries) {
      final n = _tagOf(e);
      minutes[n] = (minutes[n] ?? 0) + (e.duration?.inMinutes ?? 0).toDouble();
    }
    final list = minutes.keys.toList()
      ..sort((a, b) => minutes[b]!.compareTo(minutes[a]!));
    _tags = list;
  }

  /// 可选月份：最早记录所在月 ~ 当前月（新在前）
  void _collectMonths() {
    final now = DateTime.now();
    var first = DateTime(now.year, now.month);
    for (final e in _entries) {
      final m = DateTime(e.startTime.year, e.startTime.month);
      if (m.isBefore(first)) first = m;
    }
    final list = <String>[];
    var cur = DateTime(now.year, now.month);
    while (!cur.isBefore(first)) {
      list.add(_monthKey(cur));
      cur = DateTime(cur.year, cur.month - 1);
    }
    _months = list;
  }

  /// 累计时长最多的标签（作为默认项）
  String? _autoTag() {
    if (_tags.isEmpty) return null;
    return _tags.first;
  }

  /// 某标签最新有记录的月份
  String? _latestMonthOf(String tag) {
    String? best;
    for (final e in _entries) {
      if (_tagOf(e) != tag) continue;
      final k = _monthKey(e.startTime);
      if (best == null || k.compareTo(best) > 0) best = k;
    }
    return best;
  }

  /// 重算当前标签的每月时长
  void _rebuildMonthMinutes() {
    final map = <String, double>{};
    for (final e in _entries) {
      if (_tag != null && _tagOf(e) != _tag) continue;
      final k = _monthKey(e.startTime);
      map[k] = (map[k] ?? 0) + (e.duration?.inMinutes ?? 0).toDouble();
    }
    _monthMinutes = map;
  }

  /// 重算选中范围内的总时长与有记录天数
  void _rebuildSelectedStats() {
    final days = <String>{};
    var mins = 0.0;
    for (final e in _entries) {
      if (_tag != null && _tagOf(e) != _tag) continue;
      if (_selectedMonths.isNotEmpty &&
          !_selectedMonths.contains(_monthKey(e.startTime))) {
        continue;
      }
      days.add(_dayKey(e.startTime));
      mins += (e.duration?.inMinutes ?? 0).toDouble();
    }
    _workDays = days;
    _totalMinutes = mins;
  }

  // ---------------- 配置 ----------------

  void _loadConfig() {
    final raw = StorageService().getConfig(_configKey);
    if (raw is! Map) return;
    final s = raw['salary'];
    if (s is num && s > 0) _salaryCtrl.text = s.toStringAsFixed(0);
    final tag = raw['tag'];
    if (tag is String && _tags.contains(tag)) _tag = tag;
    final months = raw['months'];
    if (months is List) {
      final loaded =
          months.whereType<String>().where(_months.contains).toSet();
      if (loaded.isNotEmpty) {
        _selectedMonths
          ..clear()
          ..addAll(loaded);
      }
    }
  }

  void _saveConfig() {
    StorageService().setConfig(_configKey, {
      'tag': _tag,
      'salary': double.tryParse(_salaryCtrl.text.trim()) ?? 0,
      'months': _selectedMonths.toList(),
    });
  }

  /// 标签或月份变化后重算
  void _recompute() {
    setState(() {
      _rebuildMonthMinutes();
      _rebuildSelectedStats();
    });
    _saveConfig();
  }

  // ---------------- 计算 ----------------

  double get _salary => double.tryParse(_salaryCtrl.text.trim()) ?? 0;

  int get _monthCount => _selectedMonths.length;

  double get _hours => _totalMinutes / 60;

  double get _pay => _salary * _monthCount;

  double get _hourly => _hours > 0 ? _pay / _hours : 0;

  double get _avgMonthHours => _monthCount > 0 ? _hours / _monthCount : 0;

  /// 记录范围内的平均每天工作时长
  double get _avgDayHours =>
      _workDays.isNotEmpty ? _hours / _workDays.length : 0;

  /// 每天能挣：月薪合计 ÷ 有记录天数
  double get _daily =>
      _workDays.isNotEmpty ? _pay / _workDays.length : 0;

  // ---------------- 界面 ----------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('时薪计算器'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_entries.isEmpty) ...[
            _emptyHint(cs),
            const SizedBox(height: 12),
          ],
          _tagCard(cs),
          const SizedBox(height: 12),
          _monthCard(cs),
          const SizedBox(height: 12),
          _salaryCard(cs),
          const SizedBox(height: 12),
          _resultCard(cs),
          const SizedBox(height: 12),
          _dailyCard(cs),
          const SizedBox(height: 12),
          Text(
            '时薪 = 月薪 × 选中月数 ÷ 选中标签的总时长；仅统计已完成计时的记录。',
            style: TextStyle(
                fontSize: 11,
                height: 1.6,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _emptyHint(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '还没有已完成的计时记录，先去计时并结束一次，再回来计算时薪吧。',
              style: TextStyle(
                  fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }

  /// 标签选择卡片
  Widget _tagCard(ColorScheme cs) {
    return _sectionCard(
      cs,
      icon: Icons.label_rounded,
      title: '选择标签',
      trailing: Text(
        _tag ?? '未选择',
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
      ),
      child: _tags.isEmpty
          ? _placeholderText(cs, '暂无标签')
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _tags) _tagChip(cs, t),
              ],
            ),
    );
  }

  Widget _tagChip(ColorScheme cs, String name) {
    final active = _tag == name;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _tag = name;
        _recompute();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? cs.primary.withValues(alpha: 0.14)
              : cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? cs.primary.withValues(alpha: 0.7)
                : cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: active
                    ? cs.primary
                    : cs.onSurfaceVariant.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? cs.primary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 月份选择卡片（可多选，chip 上显示该标签当月时长）
  Widget _monthCard(ColorScheme cs) {
    final allSelected =
        _months.isNotEmpty && _selectedMonths.length == _months.length;
    return _sectionCard(
      cs,
      icon: Icons.calendar_month_rounded,
      title: '选择月份',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '已选 $_monthCount 个月',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.primary),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (allSelected) {
                  _selectedMonths.clear();
                } else {
                  _selectedMonths.addAll(_months);
                }
              });
              _saveConfig();
            },
            child: Text(
              allSelected ? '清空' : '全选',
              style: TextStyle(
                  fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
      child: _months.isEmpty
          ? _placeholderText(cs, '暂无可选月份')
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in _months) _monthChip(cs, k),
              ],
            ),
    );
  }

  Widget _monthChip(ColorScheme cs, String key) {
    final active = _selectedMonths.contains(key);
    final parts = key.split('-');
    final now = DateTime.now();
    final label = parts[0] == '${now.year}'
        ? '${int.parse(parts[1])}月'
        : '${parts[0]}年${int.parse(parts[1])}月';
    final minutes = _monthMinutes[key] ?? 0;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (!_selectedMonths.remove(key)) _selectedMonths.add(key);
        });
        _saveConfig();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? cs.primary.withValues(alpha: 0.14)
              : cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? cs.primary.withValues(alpha: 0.7)
                : cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? cs.primary : cs.onSurface,
              ),
            ),
            if (minutes > 0)
              Text(
                '${(minutes / 60).toStringAsFixed(1)} 小时',
                style: TextStyle(
                  fontSize: 10,
                  color: active
                      ? cs.primary.withValues(alpha: 0.8)
                      : cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 月薪输入卡片
  Widget _salaryCard(ColorScheme cs) {
    return _sectionCard(
      cs,
      icon: Icons.payments_rounded,
      title: '月薪',
      child: TextField(
        controller: _salaryCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _saveConfig(),
        decoration: InputDecoration(
          isDense: true,
          prefixText: '￥ ',
          hintText: '输入月薪',
          suffixText: '/ 月',
          filled: true,
          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  /// 结果卡片：时薪用滚动数字突出展示
  Widget _resultCard(ColorScheme cs) {
    final hasHours = _hours > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate_rounded, size: 17, color: cs.primary),
                const SizedBox(width: 6),
                const Text('时薪估算',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 14),
            if (_monthCount == 0)
              _placeholderText(cs, '请至少选择一个月')
            else if (!hasHours)
              _placeholderText(cs, '选中范围内暂无该标签的计时记录')
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('￥',
                      style: TextStyle(fontSize: 18, color: cs.primary)),
                  Flexible(
                    child: CountUpText(
                      value: _hourly,
                      formatter: (v) => v.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 38,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(' / 小时',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.9))),
                ],
              ),
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            _resultRow(cs, '选中标签', _tag ?? '未选择'),
            _resultRow(cs, '选中月数', '$_monthCount 个月'),
            _resultRow(cs, '标签总时长', '${_hours.toStringAsFixed(1)} 小时'),
            _resultRow(cs, '平均每月', '${_avgMonthHours.toStringAsFixed(1)} 小时'),
            _resultRow(cs, '月薪合计', '￥${_pay.toStringAsFixed(0)}'),
          ],
        ),
      ),
    );
  }

  /// 每天能挣卡片：按选中范围内有记录的天数折算
  Widget _dailyCard(ColorScheme cs) {
    final available = _monthCount > 0 && _workDays.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today_rounded, size: 17, color: cs.primary),
                const SizedBox(width: 6),
                const Text('每天能挣多少',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_workDays.isNotEmpty)
                  Text(
                    '${_workDays.length} 天有记录',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (!available)
              _placeholderText(cs, '先选择标签与月份，并输入月薪')
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('￥',
                      style: TextStyle(fontSize: 16, color: cs.primary)),
                  Flexible(
                    child: CountUpText(
                      value: _daily,
                      formatter: (v) => v.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(' / 天',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.9))),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              _resultRow(cs, '有记录天数', '${_workDays.length} 天'),
              _resultRow(
                  cs, '平均每天时长', '${_avgDayHours.toStringAsFixed(1)} 小时'),
              _resultRow(cs, '月薪合计', '￥${_pay.toStringAsFixed(0)}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultRow(ColorScheme cs, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.9))),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _placeholderText(ColorScheme cs, String text) => Text(
        text,
        style: TextStyle(
            fontSize: 12.5,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
      );

  /// 统一的分组卡片：图标 + 标题 + 右侧说明 + 内容
  Widget _sectionCard(
    ColorScheme cs, {
    required IconData icon,
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: cs.primary),
                const SizedBox(width: 6),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
