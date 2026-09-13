// ============================================================
// money_progress_page.dart（时钟模块 · 来财进度条）
// 职责：
//   1. 输入月薪或时薪（两者自动换算），显示「今日已挣」金额与
//      「下一元进度条」——进度随时间增长，满一元即清零并计满 1 元；
//   2. 显示本月累计收入占月薪的进度条（工资按当月天数均匀到账）。
// 计薪规则：每天在设定时段（默认 09:00 起 8 小时）内按秒进账，
//          日薪 = 时薪 × 每日小时数，月薪 = 日薪 × 当月自然天数。
// 关联：配置存 config.json 的 money_progress_config；入口在「更多」页。
// ============================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/services/storage_service.dart';

class MoneyProgressPage extends StatefulWidget {
  const MoneyProgressPage({super.key});

  @override
  State<MoneyProgressPage> createState() => _MoneyProgressPageState();
}

class _MoneyProgressPageState extends State<MoneyProgressPage> {
  static const _configKey = 'money_progress_config';

  final _amountCtrl = TextEditingController();
  final _startCtrl = TextEditingController(text: '9');
  final _hoursCtrl = TextEditingController(text: '8');

  /// true=输入的是月薪，false=时薪
  bool _byMonth = true;

  /// 全屏展示时是否显示「今日已挣」/「月薪进度」
  bool _showToday = true;
  bool _showMonth = true;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _amountCtrl.addListener(_onChanged);
    _startCtrl.addListener(_onChanged);
    _hoursCtrl.addListener(_onChanged);
    // 每秒刷新一次，让金额与进度条实时增长
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _saveConfig();
    _amountCtrl.removeListener(_onChanged);
    _amountCtrl.dispose();
    _startCtrl.removeListener(_onChanged);
    _startCtrl.dispose();
    _hoursCtrl.removeListener(_onChanged);
    _hoursCtrl.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  // ---------------- 配置 ----------------

  void _loadConfig() {
    final raw = StorageService().getConfig(_configKey);
    if (raw is! Map) return;
    final byMonth = raw['byMonth'];
    if (byMonth is bool) _byMonth = byMonth;
    final showToday = raw['showToday'];
    if (showToday is bool) _showToday = showToday;
    final showMonth = raw['showMonth'];
    if (showMonth is bool) _showMonth = showMonth;
    final amount = raw['amount'];
    if (amount is num && amount > 0) {
      _amountCtrl.text = amount == amount.roundToDouble()
          ? amount.toStringAsFixed(0)
          : amount.toStringAsFixed(2);
    }
    final start = raw['startHour'];
    if (start is int && start >= 0 && start <= 23) {
      _startCtrl.text = '$start';
    }
    final hours = raw['hoursPerDay'];
    if (hours is num && hours > 0 && hours <= 24) {
      _hoursCtrl.text = hours == hours.roundToDouble()
          ? hours.toStringAsFixed(0)
          : hours.toStringAsFixed(1);
    }
  }

  void _saveConfig() {
    StorageService().setConfig(_configKey, {
      'byMonth': _byMonth,
      'showToday': _showToday,
      'showMonth': _showMonth,
      'amount': _amount,
      'startHour': _startHour,
      'hoursPerDay': _hoursPerDay,
    });
  }

  // ---------------- 参数 ----------------

  double get _amount => double.tryParse(_amountCtrl.text.trim()) ?? 0;

  /// 每日计薪小时数（1~24）
  double get _hoursPerDay =>
      (double.tryParse(_hoursCtrl.text.trim()) ?? 8).clamp(1.0, 24.0);

  /// 每日计薪开始整点（0~23）
  int get _startHour =>
      (int.tryParse(_startCtrl.text.trim()) ?? 9).clamp(0, 23);

  /// 当月自然天数
  int get _daysInMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0).day;
  }

  /// 时薪（元/小时）
  double get _hourly {
    if (_byMonth) {
      final m = _amount;
      if (m <= 0) return 0;
      return m / (_daysInMonth * _hoursPerDay);
    }
    return _amount;
  }

  /// 月薪（元/月）
  double get _monthly {
    if (!_byMonth) return _amount * _daysInMonth * _hoursPerDay;
    return _amount;
  }

  /// 日薪（元/天）
  double get _dailyPay => _hourly * _hoursPerDay;

  Duration get _windowLength =>
      Duration(minutes: (_hoursPerDay * 60).round());

  DateTime _windowStart(DateTime day) =>
      DateTime(day.year, day.month, day.day, _startHour);

  /// 结束时间文本（如 17:00；跨天显示次日）
  String get _windowText {
    final now = DateTime.now();
    final end = _windowStart(now).add(_windowLength);
    final eh = end.hour.toString().padLeft(2, '0');
    final em = end.minute.toString().padLeft(2, '0');
    final sh = _startHour.toString().padLeft(2, '0');
    final cross = end.day != now.day ? '次日' : '';
    return '$sh:00 - $cross$eh:$em';
  }

  /// 当前所处计薪窗口内已过的小时数（支持跨天时段）
  double get _workedHoursToday {
    final now = DateTime.now();
    for (final base in [now, now.subtract(const Duration(days: 1))]) {
      final s = _windowStart(base);
      final e = s.add(_windowLength);
      if (!now.isBefore(s) && now.isBefore(e)) {
        return now.difference(s).inSeconds / 3600.0;
      }
    }
    // 今天的窗口已结束 → 满额；还没开始 → 0
    final todayEnd = _windowStart(now).add(_windowLength);
    if (!now.isBefore(todayEnd)) return _hoursPerDay;
    return 0;
  }

  /// 今日已挣（元，封顶日薪）
  double get _todayEarned =>
      (_workedHoursToday * _hourly).clamp(0.0, _dailyPay).toDouble();

  /// 本月累计已挣：已过整天按日薪计，今天按实时
  double get _monthEarned {
    final now = DateTime.now();
    return (now.day - 1) * _dailyPay + _todayEarned;
  }

  /// 月薪进度（0~1）
  double get _monthProgress {
    if (_monthly <= 0) return 0;
    return (_monthEarned / _monthly).clamp(0.0, 1.0).toDouble();
  }

  /// 下一元的进度（今日已挣的小数部分）
  double get _yuanProgress {
    final v = _todayEarned;
    return (v - v.floorToDouble()).clamp(0.0, 1.0).toDouble();
  }

  /// 距下一元还需的秒数
  int get _secondsToNextYuan {
    if (_hourly <= 0) return 0;
    final remain = (1 - _yuanProgress) * 3600 / _hourly;
    return remain.ceil();
  }

  /// 今日剩余计薪秒数（未开始或已结束为 0）
  int get _secondsLeftToday {
    final now = DateTime.now();
    for (final base in [now, now.subtract(const Duration(days: 1))]) {
      final s = _windowStart(base);
      final e = s.add(_windowLength);
      if (!now.isBefore(s) && now.isBefore(e)) {
        return e.difference(now).inSeconds;
      }
    }
    return 0;
  }

  /// 金额格式化：千分位 + 指定小数位
  String _fmt(double v, {int digits = 2}) {
    final s = v.toStringAsFixed(digits);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return digits > 0 ? '$intPart.${parts[1]}' : intPart;
  }

  String _durationText(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '$h 小时 $m 分';
    if (m > 0) return '$m 分 $s 秒';
    return '$s 秒';
  }

  // ---------------- 界面 ----------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('来财进度条'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _settingCard(cs),
          const SizedBox(height: 12),
          _todayCard(cs),
          const SizedBox(height: 12),
          _monthCard(cs),
          const SizedBox(height: 12),
          Text(
            '计薪规则：每天在设定时段内按秒进账，日薪 = 时薪 × 每日小时数，'
            '月薪 = 日薪 × 当月天数（默认按每月自然天数分摊）。',
            style: TextStyle(
                fontSize: 11,
                height: 1.6,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _openFullscreen,
              icon: const Icon(Icons.fullscreen_rounded, size: 20),
              label: const Text('全屏展示',
                  style:
                      TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 打开全屏展示（沉浸式，轻点任意处退出）
  void _openFullscreen() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => _MoneyFullscreenPage(owner: this),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  /// 收入设置：月薪/时薪输入 + 计薪时段
  Widget _settingCard(ColorScheme cs) {
    final hourDigits = RegExp(r'[0-9.]');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 17, color: cs.primary),
                const SizedBox(width: 6),
                const Text('收入设置',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _modeChip(cs, '按月薪', true),
                const SizedBox(width: 8),
                _modeChip(cs, '按时薪', false),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(hourDigits)],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveConfig(),
              decoration: InputDecoration(
                isDense: true,
                prefixText: '￥ ',
                hintText: _byMonth ? '输入月薪' : '输入时薪',
                suffixText: _byMonth ? '/ 月' : '/ 小时',
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
            const SizedBox(height: 8),
            Text(
              _byMonth
                  ? '按时薪 ￥${_fmt(_hourly)} / 小时 折算'
                  : '按月薪 ￥${_fmt(_monthly, digits: 0)} / 月 折算',
              style: TextStyle(
                  fontSize: 11.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('计薪时段',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.9))),
                const Spacer(),
                SizedBox(
                  width: 44,
                  child: TextField(
                    controller: _startCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 2,
                    textAlign: TextAlign.center,
                    onSubmitted: (_) => _saveConfig(),
                    decoration: _miniDecoration(cs),
                  ),
                ),
                Text(' 点起 · 每天 ',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.9))),
                SizedBox(
                  width: 44,
                  child: TextField(
                    controller: _hoursCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(hourDigits)
                    ],
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    onSubmitted: (_) => _saveConfig(),
                    decoration: _miniDecoration(cs),
                  ),
                ),
                Text(' 小时',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.9))),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _windowText,
                style: TextStyle(
                    fontSize: 11,
                    color: cs.primary.withValues(alpha: 0.9)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _miniDecoration(ColorScheme cs) => InputDecoration(
        isDense: true,
        counterText: '',
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      );

  Widget _modeChip(ColorScheme cs, String label, bool byMonth) {
    final active = _byMonth == byMonth;
    return GestureDetector(
      onTap: () {
        if (active) return;
        HapticFeedback.selectionClick();
        setState(() {
          // 切换口径时把当前数值换算过去，避免金额突变
          final cur = _amount;
          if (byMonth) {
            _amountCtrl.text = (_hourly * _daysInMonth * _hoursPerDay)
                .toStringAsFixed(0);
          } else {
            _amountCtrl.text = _monthly > 0 && cur > 0
                ? _hourly.toStringAsFixed(2)
                : '';
          }
          _byMonth = byMonth;
        });
        _saveConfig();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? cs.primary : cs.onSurface,
          ),
        ),
      ),
    );
  }

  /// 今日已挣 + 下一元进度条
  Widget _todayCard(ColorScheme cs) {
    final hasRate = _hourly > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.savings_rounded, size: 17, color: cs.primary),
                const SizedBox(width: 6),
                const Text('今日已挣',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_showToday)
                  Text(_windowText,
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              cs.onSurfaceVariant.withValues(alpha: 0.8))),
                const SizedBox(width: 8),
                _cardSwitch(
                  value: _showToday,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _showToday = v);
                    _saveConfig();
                  },
                ),
              ],
            ),
            // 关闭展示后卡片收起，只保留标题行
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_showToday
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        if (!hasRate)
                          Text('请输入月薪或时薪',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.7)))
                        else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('￥',
                                  style: TextStyle(
                                      fontSize: 18, color: cs.primary)),
                              Text(
                                _fmt(_todayEarned),
                                style: TextStyle(
                                  fontSize: 38,
                                  height: 1.05,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: _yuanProgress),
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOut,
                              builder: (context, v, _) =>
                                  LinearProgressIndicator(
                                value: v,
                                minHeight: 10,
                                backgroundColor:
                                    cs.primary.withValues(alpha: 0.12),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    cs.primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                _secondsLeftToday > 0
                                    ? '距下一元还差 $_secondsToNextYuan 秒'
                                    : (_workedHoursToday >= _hoursPerDay
                                        ? '今日已收工'
                                        : '今日还没开始计薪'),
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.9)),
                              ),
                              const Spacer(),
                              Text(
                                '日薪 ￥${_fmt(_dailyPay)}',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.9)),
                              ),
                            ],
                          ),
                          if (_secondsLeftToday > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              '距离今天收工还有 ${_durationText(_secondsLeftToday)}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.7)),
                            ),
                          ],
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 月薪进度条
  Widget _monthCard(ColorScheme cs) {
    final now = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    size: 17, color: cs.primary),
                const SizedBox(width: 6),
                const Text('月薪进度',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_showMonth)
                  Text('第 ${now.day} 天 / 共 $_daysInMonth 天',
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              cs.onSurfaceVariant.withValues(alpha: 0.8))),
                const SizedBox(width: 8),
                _cardSwitch(
                  value: _showMonth,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _showMonth = v);
                    _saveConfig();
                  },
                ),
              ],
            ),
            // 关闭展示后卡片收起，只保留标题行
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_showMonth
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        if (_monthly <= 0)
                          Text('请输入月薪或时薪',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.7)))
                        else ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: _monthProgress),
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOut,
                              builder: (context, v, _) =>
                                  LinearProgressIndicator(
                                value: v,
                                minHeight: 10,
                                backgroundColor:
                                    cs.primary.withValues(alpha: 0.12),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    cs.primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '￥${_fmt(_monthEarned)}',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700),
                              ),
                              Text(
                                ' / ￥${_fmt(_monthly, digits: 0)}',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.9)),
                              ),
                              const Spacer(),
                              Text(
                                '${(_monthProgress * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 卡片右上角的展示开关（紧凑尺寸）
  Widget _cardSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      width: 38,
      height: 22,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

/// 全屏展示：沉浸式大屏进度（今日已挣 + 下一元进度 + 月薪进度）
///
/// 直接读取所属页面的实时计算结果，自身每秒刷新一次；
/// 进入时隐藏系统栏，退出时恢复。
class _MoneyFullscreenPage extends StatefulWidget {
  const _MoneyFullscreenPage({required this.owner});

  final _MoneyProgressPageState owner;

  @override
  State<_MoneyFullscreenPage> createState() => _MoneyFullscreenPageState();
}

class _MoneyFullscreenPageState extends State<_MoneyFullscreenPage> {
  Timer? _timer;

  /// 屏幕常亮开关，进入全屏默认开启
  bool _keepOn = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // 全屏展示期间允许旋转，横放时切换为左右分栏布局
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _wakelock(true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wakelock(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // 恢复全局竖屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  /// 常亮开关的静默封装：插件通道不可用时忽略异常
  void _wakelock(bool on) {
    try {
      if (on) {
        WakelockPlus.enable().catchError((_) {});
      } else {
        WakelockPlus.disable().catchError((_) {});
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final owner = widget.owner;
    final now = DateTime.now();
    final clock = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final hasRate = owner._hourly > 0;
    final barColor = Color.lerp(cs.primary, Colors.white, 0.45)!;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(cs.primary, Colors.black, 0.62)!,
                const Color(0xFF0A0E14),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: isLandscape
                  ? _landscapeBody(now, clock, hasRate, barColor)
                  : _portraitBody(now, clock, hasRate, barColor),
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部：时钟 + 屏幕常亮 + 关闭（展示开关在主页面卡片上控制）
  Widget _header(String clock) {
    return Row(
      children: [
        Text(
          clock,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        const Spacer(),
        _iconButton(
          icon: _keepOn
              ? Icons.lightbulb_rounded
              : Icons.lightbulb_outline_rounded,
          active: _keepOn,
          tooltip: _keepOn ? '屏幕常亮：开' : '屏幕常亮：关',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _keepOn = !_keepOn);
            _wakelock(_keepOn);
          },
        ),
        const SizedBox(width: 10),
        _iconButton(
          icon: Icons.close_rounded,
          active: false,
          tooltip: '退出全屏',
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required bool active,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? 0.22 : 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.white.withValues(alpha: active ? 0.95 : 0.85),
          ),
        ),
      ),
    );
  }

  /// 竖屏布局：今日在上、月薪在下
  Widget _portraitBody(
      DateTime now, String clock, bool hasRate, Color barColor) {
    final owner = widget.owner;
    final showAny = owner._showToday || owner._showMonth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(clock),
        Expanded(
          child: !hasRate
              ? Center(child: _noRateText())
              : !showAny
                  ? Center(child: _allHiddenText())
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (owner._showToday)
                          _todayBlock(owner, barColor, amountSize: 58),
                        if (owner._showMonth)
                          _monthBlock(owner, barColor, now),
                      ],
                    ),
        ),
        const SizedBox(height: 14),
        _exitHint(),
      ],
    );
  }

  /// 横屏布局：左=今日已挣与下一元进度，右=月薪进度
  Widget _landscapeBody(
      DateTime now, String clock, bool hasRate, Color barColor) {
    final owner = widget.owner;
    final showAny = owner._showToday || owner._showMonth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(clock),
        const SizedBox(height: 6),
        Expanded(
          child: !hasRate
              ? Center(child: _noRateText())
              : !showAny
                  ? Center(child: _allHiddenText())
                  : Row(
                      children: [
                        if (owner._showToday)
                          Expanded(
                            flex: 6,
                            child: Center(
                              child: _todayBlock(owner, barColor,
                                  amountSize: 46),
                            ),
                          ),
                        if (owner._showToday && owner._showMonth)
                          Container(
                            width: 1,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 4),
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        if (owner._showMonth)
                          Expanded(
                            flex: 4,
                            child: Center(
                              child: _monthBlock(owner, barColor, now),
                            ),
                          ),
                      ],
                    ),
        ),
        const SizedBox(height: 8),
        _exitHint(),
      ],
    );
  }

  Widget _noRateText() => Text(
        '请先输入月薪或时薪',
        style:
            TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
      );

  Widget _allHiddenText() => Text(
        '两个面板都已隐藏，退出全屏后点击对应显示项右上角开关可恢复显示',
        textAlign: TextAlign.center,
        style:
            TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
      );

  Widget _exitHint() => Center(
        child: Text(
          '轻点任意处退出',
          style: TextStyle(
              fontSize: 11, color: Colors.white.withValues(alpha: 0.35)),
        ),
      );

  /// 今日已挣 + 下一元进度
  Widget _todayBlock(
    _MoneyProgressPageState owner,
    Color barColor, {
    required double amountSize,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日已挣',
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 4,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('￥',
                  style: TextStyle(
                      fontSize: amountSize * 0.45,
                      color: Colors.white.withValues(alpha: 0.85))),
              Text(
                owner._fmt(owner._todayEarned),
                style: TextStyle(
                  fontSize: amountSize,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: owner._yuanProgress),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 16,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              owner._secondsLeftToday > 0
                  ? '距下一元 ${owner._secondsToNextYuan} 秒'
                  : (owner._workedHoursToday >= owner._hoursPerDay
                      ? '今日已收工'
                      : '今日还没开始计薪'),
              style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(width: 12),
            if (owner._secondsLeftToday > 0)
              Flexible(
                child: Text(
                  '距收工 ${owner._durationText(owner._secondsLeftToday)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.6)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 月薪进度
  Widget _monthBlock(
      _MoneyProgressPageState owner, Color barColor, DateTime now) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '月薪进度',
              style: TextStyle(
                fontSize: 13,
                letterSpacing: 2,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            Text(
              '${(owner._monthProgress * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: owner._monthProgress),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '￥${owner._fmt(owner._monthEarned)}',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            Text(
              ' / ￥${owner._fmt(owner._monthly, digits: 0)}',
              style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                '第 ${now.day} 天 / 共 ${owner._daysInMonth} 天',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
