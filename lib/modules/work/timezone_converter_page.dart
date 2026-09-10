import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/tz_setup.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/tap_scale.dart';
import '../../data/services/storage_service.dart';
import 'tz_widgets.dart';

/// 时区显示/转换：查看各时区当前时间，也可手动调整基准时间换算对应时刻
class TimezoneConverterPage extends StatefulWidget {
  const TimezoneConverterPage({super.key});

  @override
  State<TimezoneConverterPage> createState() =>
      _TimezoneConverterPageState();
}

class _TimezoneConverterPageState extends State<TimezoneConverterPage> {
  static const _configKey = 'tz_convert_zones';

  late List<String> _selected;
  bool _ready = false;
  Duration _offset = Duration.zero; // 相对“现在”的偏移
  String _baseZoneId = ''; // 基准时区（默认设备本地）
  Timer? _ticker;

  bool get _isLive => _offset == Duration.zero;

  @override
  void initState() {
    super.initState();
    final raw = StorageService().getConfig(_configKey);
    final saved = raw is List
        ? raw
            .map((e) => '$e')
            .where((id) => tzOptions.any((z) => z.id == id))
            .toList()
        : <String>[];
    _selected = saved.isEmpty
        ? ['Asia/Shanghai', 'Europe/London', 'America/New_York']
        : saved;
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_isLive && mounted) setState(() {});
    });
    _init();
  }

  Future<void> _init() async {
    await ensureTimezonesInitialized();
    if (mounted) {
      setState(() {
        _baseZoneId = tz.local.name;
        _ready = true;
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _save() => StorageService().setConfig(_configKey, _selected);

  Future<void> _manageZones() async {
    final picked = await showZonePicker(context, _selected);
    if (picked == null || picked.isEmpty) return;
    setState(() => _selected = picked);
    _save();
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  tz.Location get _baseLoc =>
      tz.getLocation(_baseZoneId.isEmpty ? tz.local.name : _baseZoneId);

  tz.TZDateTime _baseTime() => tz.TZDateTime.now(_baseLoc).add(_offset);

  /// 点选下方时区，把它设为基准时区
  void _setBaseZone(String id) {
    if (id == _baseZoneId) return;
    HapticFeedback.selectionClick();
    setState(() => _baseZoneId = id);
  }

  Future<void> _pickDateTime() async {
    final base = _baseTime();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(base.year, base.month, base.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
    );
    if (t == null) return;
    final loc = _baseLoc;
    final pickedTz =
        tz.TZDateTime(loc, d.year, d.month, d.day, t.hour, t.minute);
    setState(() =>
        _offset = pickedTz.difference(tz.TZDateTime.now(loc)));
  }

  String _offsetLabel() {
    final m = _offset.inMinutes;
    if (m == 0) return '现在';
    final sign = m > 0 ? '+' : '-';
    final a = m.abs();
    final h = a ~/ 60;
    final mm = a % 60;
    return mm == 0 ? '$sign${h}h' : '$sign${h}h${mm}m';
  }

  String _dayDiffText(int diff) =>
      diff > 0 ? '明天' : (diff < 0 ? '昨天' : '今天');

  String _diffText(tz.TZDateTime z, tz.TZDateTime base) {
    final diff =
        z.timeZoneOffset.inMinutes - base.timeZoneOffset.inMinutes;
    if (diff == 0) return '与基准同时';
    final sign = diff > 0 ? '+' : '-';
    final a = diff.abs();
    final h = a ~/ 60;
    final m = a % 60;
    return m == 0 ? '比基准 $sign$h 小时' : '比基准 $sign$h 小时 $m 分';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_ready) {
      return Scaffold(
        appBar: AppBar(title: const Text('时区显示/转换'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final base = _baseTime();
    return Scaffold(
      appBar: AppBar(
        title: const Text('时区显示/转换'),
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
          FadeSlideIn(
            index: 0,
            child: _buildBaseCard(cs, base),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 1,
            child: Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < _selected.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      FadeSlideIn(
                        key: ValueKey(_selected[i]),
                        index: i + 2,
                        child: _buildZoneRow(cs, _selected[i], base),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 3,
            child: Text(
              '点击下方任意时区可将其设为基准；拖动滑块或点击「选择时间」调整基准时间，'
              '其它时区会同步换算，方便直观地知道“我们这边几点时，对方几点”。',
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

  Widget _buildBaseCard(ColorScheme cs, tz.TZDateTime base) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('基准时间 · ${tzCity(_baseZoneId)}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                if (_baseZoneId != tz.local.name) ...[
                  TapScale(
                    onTap: () =>
                        setState(() => _baseZoneId = tz.local.name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('恢复本地',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.primary)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_isLive ? cs.primary : cs.tertiary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(scale: a, child: c),
                    ),
                    child: Text(
                      _isLive ? '实时' : '手动',
                      key: ValueKey(_isLive),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _isLive ? cs.primary : cs.tertiary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: Column(
                children: [
                  _RollingText(
                    text: '${_two(base.hour)}:${_two(base.minute)}',
                    style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${base.year}年${base.month}月${base.day}日 · '
                    '${tzCity(_baseZoneId)}（基准）',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('-24h',
                    style: TextStyle(
                        fontSize: 10, color: cs.onSurfaceVariant)),
                Expanded(
                  child: Slider(
                    min: -24,
                    max: 24,
                    divisions: 192,
                    value: (_offset.inMinutes / 60).clamp(-24.0, 24.0),
                    label: _offsetLabel(),
                    onChanged: (v) => setState(() =>
                        _offset = Duration(minutes: (v * 60).round())),
                  ),
                ),
                Text('+24h',
                    style: TextStyle(
                        fontSize: 10, color: cs.onSurfaceVariant)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pillButton(
                  icon: Icons.restart_alt_rounded,
                  label: '回到现在',
                  onPressed: _isLive
                      ? null
                      : () => setState(() => _offset = Duration.zero),
                ),
                const SizedBox(width: 12),
                _pillButton(
                  icon: Icons.edit_calendar_rounded,
                  label: '选择时间',
                  onPressed: _pickDateTime,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return TapScale(
      onTap: onPressed,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneRow(ColorScheme cs, String id, tz.TZDateTime base) {
    final z = tz.TZDateTime.from(base, tz.getLocation(id));
    final dayDiff = DateTime(z.year, z.month, z.day)
        .difference(DateTime(base.year, base.month, base.day))
        .inDays;
    final isBase = id == _baseZoneId;
    final isLocal = id == tz.local.name;
    final work = z.hour >= 9 && z.hour < 18;
    final badge = isBase
        ? (isLocal ? '基准·本地' : '基准')
        : (isLocal ? '本地' : null);
    return TapScale(
      onTap: () => _setBaseZone(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isBase
              ? cs.primary.withValues(alpha: 0.10)
              : (isLocal
                  ? cs.primary.withValues(alpha: 0.05)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: isBase
              ? Border.all(color: cs.primary.withValues(alpha: 0.45))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(tzCity(id),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                cs.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(badge,
                              style: TextStyle(
                                  fontSize: 9.5, color: cs.primary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${tzRegion(id)} · ${_diffText(z, base)}',
                      style: TextStyle(
                          fontSize: 10.5,
                          color: cs.onSurfaceVariant
                              .withValues(alpha: 0.8))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _RollingText(
                  text: '${_two(z.hour)}:${_two(z.minute)}',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: work ? cs.primary : cs.onSurface,
                      fontFeatures: const [
                        FontFeature.tabularFigures()
                      ]),
                ),
                Text('${z.month}月${z.day}日 ${_dayDiffText(dayDiff)}',
                    style: TextStyle(
                        fontSize: 10.5, color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 数字/时间滚动切换：旧值下滑淡出，新值上滑淡入
class _RollingText extends StatelessWidget {
  const _RollingText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => ClipRect(
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.55),
            end: Offset.zero,
          ).animate(anim),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
      child: Text(text, key: ValueKey(text), style: style),
    );
  }
}
