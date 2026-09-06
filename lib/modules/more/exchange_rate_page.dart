import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../data/services/storage_service.dart';

/// 汇率计算器：以人民币为基准，换算常用货币
class ExchangeRatePage extends StatefulWidget {
  const ExchangeRatePage({super.key});

  @override
  State<ExchangeRatePage> createState() => _ExchangeRatePageState();
}

class _ExchangeRatePageState extends State<ExchangeRatePage> {
  static const _apiBase = 'https://open.er-api.com/v6/latest/CNY';
  static const _cacheKey = 'fx_cache';
  static const _cacheTimeKey = 'fx_time';

  final _amountCtrl = TextEditingController(text: '100');
  bool _loading = true;
  String? _error;
  String? _updated; // 汇率更新时间
  final Map<String, double> _rates = {}; // 1 CNY -> 币种数量

  final List<(String, String)> _currencies = const [
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
    if (_rates.isNotEmpty) _loading = false;
  }

  Future<void> _fetchRates() async {
    setState(() {
      _loading = _rates.isEmpty;
      _error = null;
    });
    try {
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
        _error = _rates.isEmpty ? '汇率获取失败，请检查网络后刷新' : null;
      });
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
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('CNY 人民币',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.primary)),
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

  Widget _buildRateRow(ColorScheme cs, String code, String name) {
    final rate = _rates[code];
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
            : Text('1 CNY = $rate $code',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                    fontFeatures: const [FontFeature.tabularFigures()])),
        trailing: converted == null
            ? null
            : Text(
                converted >= 1000
                    ? converted.toStringAsFixed(0)
                    : converted.toStringAsFixed(2),
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
