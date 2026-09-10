import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/widgets/tap_scale.dart';
import '../../data/services/storage_service.dart';

/// 一条秒表历史记录（复位时保存）
class _StopwatchRecord {
  _StopwatchRecord({
    required this.id,
    required this.savedAt,
    required this.totalMs,
    required this.lapTotalsMs,
  });

  final String id;
  final DateTime savedAt;
  final int totalMs;

  /// 各次计次的累计毫秒（按时间先后：旧 → 新）
  final List<int> lapTotalsMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'savedAt': savedAt.toIso8601String(),
        'totalMs': totalMs,
        'laps': lapTotalsMs,
      };

  factory _StopwatchRecord.fromJson(Map<String, dynamic> json) =>
      _StopwatchRecord(
        id: '${json['id']}',
        savedAt: DateTime.tryParse('${json['savedAt']}') ?? DateTime.now(),
        totalMs: (json['totalMs'] as num?)?.toInt() ?? 0,
        lapTotalsMs: [
          for (final e in (json['laps'] as List? ?? const []))
            if (e is num) e.toInt(),
        ],
      );
}

/// 时长格式化：mm:ss.cc（超过 1 小时带小时）
String _fmtSw(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  final centis = (d.inMilliseconds ~/ 10) % 100;
  final base = '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}.'
      '${centis.toString().padLeft(2, '0')}';
  return h > 0 ? '${h.toString().padLeft(2, '0')}:$base' : base;
}

/// 秒表：正计时、计次（分段用时）、复位与历史记录
class StopwatchPage extends StatefulWidget {
  const StopwatchPage({super.key});

  @override
  State<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<StopwatchPage>
    with TickerProviderStateMixin {
  static const _historyKey = 'stopwatch_history';
  static const _historyMax = 50;

  final Stopwatch _sw = Stopwatch();
  Timer? _ticker;

  /// 载入历史记录时的基准用时（继续计时会在此基础上累加）
  Duration _base = Duration.zero;

  int _lapSeq = 0;
  final List<(int, Duration)> _laps = []; // (计次序号, 累计用时)
  final List<_StopwatchRecord> _history = [];

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  Duration get _elapsed => _base + _sw.elapsed;
  bool get _running => _sw.isRunning;
  bool get _hasTime => _elapsed > Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    _pop.dispose();
    _wakelock(false);
    super.dispose();
  }

  // ---------------- 历史记录 ----------------

  void _loadHistory() {
    final raw = StorageService().getConfig(_historyKey);
    if (raw is! List) return;
    for (final e in raw) {
      if (e is Map) {
        try {
          _history.add(
              _StopwatchRecord.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
    }
  }

  void _persistHistory() {
    try {
      StorageService()
          .setConfig(
              _historyKey, [for (final r in _history) r.toJson()])
          .catchError((_) {});
    } catch (_) {}
  }

  /// 把当前计时保存为一条历史（复位 / 载入其它记录前调用）
  void _saveCurrentAsRecord() {
    final elapsed = _elapsed;
    if (elapsed <= Duration.zero && _laps.isEmpty) return;
    final sorted = List.of(_laps)
      ..sort((a, b) => a.$1.compareTo(b.$1));
    _history.insert(
      0,
      _StopwatchRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        savedAt: DateTime.now(),
        totalMs: elapsed.inMilliseconds,
        lapTotalsMs: [for (final l in sorted) l.$2.inMilliseconds],
      ),
    );
    if (_history.length > _historyMax) {
      _history.removeRange(_historyMax, _history.length);
    }
    _persistHistory();
  }

  /// 基于某条历史记录继续计时（会先保存当前计时，算作新记录）
  void _loadRecord(_StopwatchRecord rec) {
    HapticFeedback.mediumImpact();
    _saveCurrentAsRecord();
    _stopTicking();
    setState(() {
      _base = Duration(milliseconds: rec.totalMs);
      _laps.clear();
      for (var i = rec.lapTotalsMs.length - 1; i >= 0; i--) {
        _laps.add((i + 1, Duration(milliseconds: rec.lapTotalsMs[i])));
      }
      _lapSeq = rec.lapTotalsMs.length;
    });
  }

  Future<void> _showHistory() async {
    final picked = await showDialog<_StopwatchRecord>(
      context: context,
      builder: (context) => _HistoryDialog(
        records: _history,
        onDelete: (_) => _persistHistory(),
      ),
    );
    if (picked != null && mounted) _loadRecord(picked);
  }

  // ---------------- 计时控制 ----------------

  void _stopTicking() {
    _sw.stop();
    _ticker?.cancel();
    _ticker = null;
    _pulse.animateBack(0, duration: const Duration(milliseconds: 260));
    _wakelock(false);
  }

  void _wakelock(bool on) {
    try {
      if (on) {
        WakelockPlus.enable().catchError((_) {});
      } else {
        WakelockPlus.disable().catchError((_) {});
      }
    } catch (_) {}
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    if (_sw.isRunning) {
      _stopTicking();
      setState(() {});
    } else {
      _sw.start();
      _ticker = Timer.periodic(
          const Duration(milliseconds: 30), (_) {
        if (mounted) setState(() {});
      });
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
      _wakelock(true);
      setState(() {});
    }
  }

  void _lap() {
    if (!_sw.isRunning) return;
    HapticFeedback.selectionClick();
    _lapSeq++;
    setState(() => _laps.insert(0, (_lapSeq, _elapsed)));
    _pop.forward(from: 0);
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    _saveCurrentAsRecord(); // 复位即保存一次历史
    _stopTicking();
    setState(() {
      _base = Duration.zero;
      _lapSeq = 0;
      _laps.clear();
    });
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('秒表'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '历史记录',
            icon: const Icon(Icons.history_rounded),
            onPressed: _showHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            _buildDial(cs),
            const SizedBox(height: 22),
            _buildButtons(),
            const SizedBox(height: 14),
            Expanded(child: _buildLapList(cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildDial(ColorScheme cs) {
    final elapsed = _elapsed;
    final progress = (elapsed.inMilliseconds % 60000) / 60000.0;
    final color = _running
        ? cs.primary
        : (_hasTime ? cs.tertiary : cs.primary);

    return Center(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final pulse = _running ? _pulse.value : 0.0;
          return SizedBox(
            width: 272,
            height: 272,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 232 + 30 * pulse,
                  height: 232 + 30 * pulse,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        color.withValues(alpha: 0.04 + 0.07 * (1 - pulse)),
                  ),
                ),
                CustomPaint(
                  size: const Size(252, 252),
                  painter: _DialPainter(
                    progress: progress,
                    color: color,
                    trackColor:
                        cs.surfaceContainerHighest.withValues(alpha: 0.65),
                    tickColor:
                        cs.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
                ),
                _buildTimeText(cs, color),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeText(ColorScheme cs, Color color) {
    return AnimatedBuilder(
      animation: _pop,
      builder: (context, child) {
        final scale = 1 + 0.07 * math.sin(_pop.value * math.pi);
        return Transform.scale(scale: scale, child: child);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _fmtSw(_elapsed),
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: a, child: c),
            ),
            child: Text(
              _running ? '计时中' : (_hasTime ? '已暂停' : '就绪'),
              key: ValueKey(_running ? 'run' : (_hasTime ? 'pause' : 'idle')),
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circleButton(
          label: _running ? '计次' : '复位',
          icon: _running ? Icons.flag_rounded : Icons.refresh_rounded,
          color: Theme.of(context).colorScheme.tertiary,
          enabled: _running || _hasTime,
          onTap: _running ? _lap : _reset,
        ),
        const SizedBox(width: 40),
        _circleButton(
          label: _running ? '暂停' : (_hasTime ? '继续' : '开始'),
          icon:
              _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: _running
              ? const Color(0xFFEF5350)
              : const Color(0xFF43A047),
          enabled: true,
          primary: true,
          onTap: _toggle,
        ),
      ],
    );
  }

  Widget _circleButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final size = primary ? 84.0 : 66.0;
    final dark = Color.lerp(color, Colors.black, 0.18)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TapScale(
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, dark],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(scale: a, child: c),
                  ),
                  child: Icon(icon,
                      key: ValueKey(icon),
                      color: Colors.white,
                      size: primary ? 34 : 26),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(label,
              key: ValueKey(label),
              style:
                  TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ),
      ],
    );
  }

  Widget _buildLapList(ColorScheme cs) {
    if (_laps.isEmpty) {
      return Center(
        child: Text(
          '点击「计次」记录分段用时',
          style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _laps.length,
      itemBuilder: (context, i) {
        final (id, total) = _laps[i];
        final prev =
            (i + 1 < _laps.length) ? _laps[i + 1].$2 : Duration.zero;
        final split = total - prev;
        final index = _laps.length - i;
        final newest = i == 0;
        return _LapEntrance(
          key: ValueKey('$id-${total.inMilliseconds}'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: newest
                  ? cs.primary.withValues(alpha: 0.09)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text('计次 $index',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              newest ? FontWeight.w600 : FontWeight.normal,
                          color:
                              newest ? cs.primary : cs.onSurfaceVariant)),
                ),
                Expanded(
                  child: Text('+${_fmtSw(split)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: newest ? cs.primary : cs.onSurface,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ])),
                ),
                SizedBox(
                  width: 100,
                  child: Text(_fmtSw(total),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ])),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 秒表历史弹窗
class _HistoryDialog extends StatefulWidget {
  const _HistoryDialog({required this.records, required this.onDelete});

  final List<_StopwatchRecord> records;
  final void Function(_StopwatchRecord) onDelete;

  @override
  State<_HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<_HistoryDialog> {
  Future<void> _confirmDelete(_StopwatchRecord rec, ColorScheme cs) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: Text(
            '确定删除这条记录吗？\n${_fmtSw(Duration(milliseconds: rec.totalMs))}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('删除', style: TextStyle(color: cs.error))),
        ],
      ),
    );
    if (ok == true) {
      widget.records.removeWhere((r) => r.id == rec.id);
      widget.onDelete(rec);
      if (mounted) setState(() {});
    }
  }

  String _timeText(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.history_rounded, color: cs.primary),
          const SizedBox(width: 8),
          const Text('秒表历史'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.records.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('暂无历史记录\n点击「复位」后会保存一次',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.6,
                          color: cs.onSurfaceVariant
                              .withValues(alpha: 0.7))),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: widget.records.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final rec = widget.records[i];
                  return ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(
                        _fmtSw(Duration(milliseconds: rec.totalMs)),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [
                              FontFeature.tabularFigures()
                            ])),
                    subtitle: Text(
                        '${_timeText(rec.savedAt)} · ${rec.lapTotalsMs.length} 次计次',
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant
                                .withValues(alpha: 0.8))),
                    trailing: IconButton(
                      tooltip: '删除',
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 18, color: cs.error),
                      onPressed: () => _confirmDelete(rec, cs),
                    ),
                    onTap: () => Navigator.pop(context, rec),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭')),
      ],
    );
  }
}

/// 表盘：刻度 + 轨道 + 当前分钟进度弧 + 端点光点
class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.tickColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 14;

    for (var i = 0; i < 60; i++) {
      final major = i % 5 == 0;
      final a = i / 60 * 2 * math.pi - math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      final p = Paint()
        ..color = tickColor.withValues(alpha: major ? 0.9 : 0.45)
        ..strokeWidth = major ? 2 : 1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          center + dir * (radius + 6),
          center + dir * (radius + 6 + (major ? 7 : 3.5)),
          p);
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = trackColor,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        progress * 2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
      final a = -math.pi / 2 + progress * 2 * math.pi;
      final dot = center + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.drawCircle(
          dot, 7, Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawCircle(dot, 3.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.tickColor != tickColor;
}

/// 计次条目入场：自上滑入 + 淡入
class _LapEntrance extends StatefulWidget {
  const _LapEntrance({super.key, required this.child});

  final Widget child;

  @override
  State<_LapEntrance> createState() => _LapEntranceState();
}

class _LapEntranceState extends State<_LapEntrance> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, -0.35),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        child: widget.child,
      ),
    );
  }
}
