// ============================================================
// exchange_rate_page.dart（更多模块 · 汇率计算器）
// 职责：以任选货币为基准、输入金额后实时换算十种常用货币；汇率为联网获取，
//       成功后写入 config.json 缓存，离线时回退到上次缓存。
// 关联：网络请求 open.er-api.com（免费接口，15 秒超时），缓存读写走
//       StorageService 的 getConfig/setConfig；金额展示用 CountUpText。
// ============================================================
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../data/services/storage_service.dart';
import '../../core/widgets/count_up_text.dart';

/// 汇率计算器：以人民币为基准，换算常用货币。
///
/// 汇率表统一以 CNY 为基准存储（正值为“1 CNY 可兑换的数量”），切换基准货币
/// 只是 UI 上的换算方向变化，不需要重新请求接口。
class ExchangeRatePage extends StatefulWidget {
  const ExchangeRatePage({super.key});

  @override
  State<ExchangeRatePage> createState() => _ExchangeRatePageState();
}

class _ExchangeRatePageState extends State<ExchangeRatePage>
    with SingleTickerProviderStateMixin {
  // 免费汇率接口：一次返回以 CNY 为基准的全部货币汇率
  static const _apiBase = 'https://open.er-api.com/v6/latest/CNY';
  // 持久化缓存键：汇率表与更新时间分开存，便于单独读取
  static const _cacheKey = 'fx_cache';
  static const _cacheTimeKey = 'fx_time';

  final _amountCtrl = TextEditingController(text: '100');
  bool _loading = true;
  bool _fetching = false;
  String? _error;
  String? _updated; // 汇率更新时间
  String _base = 'CNY'; // 基准货币
  final Map<String, double> _rates = {}; // 1 CNY -> 币种数量
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  static const _baseOptions = <(String, String)>[
    ('CNY', '人民币'),
    ('USD', '美元'),
    ('EUR', '欧元'),
    ('JPY', '日元'),
    ('HKD', '港币'),
    ('GBP', '英镑'),
    ('KRW', '韩元'),
    ('SGD', '新加坡元'),
    ('AUD', '澳大利亚元'),
    ('THB', '泰铢'),
  ];

  String _baseName() =>
      _baseOptions.firstWhere((o) => o.$1 == _base, orElse: () => ('', '')).$2;

  final List<(String, String)> _currencies = const [
    ('CNY', '人民币'),
    ('USD', '美元'),
    ('EUR', '欧元'),
    ('JPY', '日元'),
    ('HKD', '港币'),
    ('GBP', '英镑'),
    ('KRW', '韩元'),
    ('SGD', '新加坡元'),
    ('AUD', '澳大利亚元'),
    ('THB', '泰铢'),
  ];

  @override
  void initState() {
    super.initState();
    _loadFromCache();
    _fetchRates();
  }

  @override
  void dispose() {
    _spin.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  /// 从 config.json 恢复上次缓存的汇率与更新时间；有缓存则直接可算，不再显示加载圈
  void _loadFromCache() {
    final raw = StorageService().getConfig(_cacheKey);
    if (raw is Map) {
      for (final e in raw.entries) {
        final v = double.tryParse('${e.value}');
        if (v != null && v > 0) _rates['${e.key}'] = v;
      }
    }
    final t = StorageService().getConfig(_cacheTimeKey);
    if (t is String && t.isNotEmpty) _updated = t;
    if (_rates.isNotEmpty) {
      // 缓存是旧版本时可能没有人民币，这里补齐（换算时需要）
      _rates['CNY'] = 1;
      _loading = false;
    }
  }

  /// 联网拉取最新汇率：成功后更新界面并写缓存；
  /// 失败时不弹错，只在“无缓存可兜底”时展示错误提示，有缓存则继续用旧汇率。
  Future<void> _fetchRates() async {
    if (_fetching) return; // 防止连点重复请求
    setState(() {
      _fetching = true;
      _loading = _rates.isEmpty; // 已有缓存时后台静默刷新，不遮界面
      _error = null;
    });
    _spin.repeat();
    try {
      // 15 秒超时：接口偶发无响应时避免一直转圈
      final res = await http
          .get(Uri.parse(_apiBase))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final body = json.decode(res.body);
      if (body is! Map<String, dynamic> || body['rates'] is! Map) {
        throw Exception('bad payload');
      }
      final rates = body['rates'] as Map;
      final picked = <String, double>{};
      for (final (code, _) in _currencies) {
        final v = double.tryParse('${rates[code] ?? ''}');
        if (v != null && v > 0) picked[code] = v;
      }
      picked['CNY'] = 1; // 基准汇率表恒含人民币
      if (picked.isEmpty) throw Exception('no rates');
      final now = DateTime.now();
      final timeStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      setState(() {
        _rates
          ..clear()
          ..addAll(picked);
        _updated = timeStr;
        _loading = false;
      });
      StorageService()
        ..setConfig(_cacheKey, picked.map((k, v) => MapEntry(k, '$v')))
        ..setConfig(_cacheTimeKey, timeStr);
    } catch (e) {
      setState(() {
        _loading = false;
        // 有缓存就不报错：用户仍可基于旧汇率计算，静默等待下次刷新
        _error = _rates.isEmpty ? '汇率获取失败，请检查网络后刷新' : null;
      });
    } finally {
      _fetching = false;
      _spin.stop();
      if (mounted) setState(() {});
    }
  }

  double get _amount =>
      double.tryParse(_amountCtrl.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('汇率计算器'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchRates,
            tooltip: '更新汇率',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAmountCard(cs),
                const SizedBox(height: 12),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error!,
                        style: TextStyle(
                            fontSize: 12.5, color: cs.onErrorContainer)),
                  ),
                  const SizedBox(height: 12),
                ],
                ..._currencies.map((c) => _buildRateRow(cs, c.$1, c.$2)),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _updated == null ? '尚未获取汇率' : '汇率更新于 $_updated',
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAmountCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 左上角基准货币：点击弹出选择，切换后按新基准换算
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _pickBase,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$_base ${_baseName()}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cs.primary)),
                        Icon(Icons.arrow_drop_down_rounded,
                            size: 18, color: cs.primary),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text('× 汇率',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()]),
              decoration: InputDecoration(
                hintText: '输入人民币金额',
                border: InputBorder.none,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.currency_yuan_rounded,
                      size: 24, color: cs.primary),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  /// 基准货币选择（底部弹窗）
  void _pickBase() {
    final cs = Theme.of(context).colorScheme;
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Text('选择基准货币',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SizedBox(
                height: 340,
                child: ListView.builder(
                  itemCount: _baseOptions.length,
                  itemExtent: 52,
                  itemBuilder: (context, index) {
                    final (code, name) = _baseOptions[index];
                    final isCurrent = _base == code;
                    return ListTile(
                      dense: true,
                      leading: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text(code,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: cs.primary)),
                      ),
                      title: Text(name,
                          style: const TextStyle(fontSize: 13.5)),
                      trailing: isCurrent
                          ? Icon(Icons.check_rounded,
                              color: cs.primary, size: 20)
                          : null,
                      onTap: () {
                        setState(() => _base = code);
                        Get.back();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }

  /// 交叉汇率：存储的汇率都以 CNY 为基准，
  /// “1 基准货币 = ? 目标货币” = 目标汇率 / 基准汇率。
  /// 任一侧缺失或基准为 0 时返回 null，由界面隐藏该行金额。
  double? _rateOf(String code) {
    final r = _rates[code];
    final rb = _rates[_base];
    if (r == null || rb == null || rb == 0) return null;
    return r / rb; // 每 1 单位基准货币可兑换的 code 数量
  }

  Widget _buildRateRow(ColorScheme cs, String code, String name) {
    if (code == _base) return const SizedBox.shrink();
    final rate = _rateOf(code);
    final converted = rate == null ? null : _amount * rate;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Text(code,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.primary)),
        ),
        title: Text(name, style: const TextStyle(fontSize: 13.5)),
        subtitle: rate == null
            ? null
            : Text('1 $_base = ${rate.toStringAsFixed(4)} $code',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                    fontFeatures: const [FontFeature.tabularFigures()])),
        trailing: converted == null
            ? null
            : CountUpText(
                value: converted,
                formatter: (v) =>
                    v >= 1000 ? v.toStringAsFixed(0) : v.toStringAsFixed(2),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
      ),
    );
  }
}
