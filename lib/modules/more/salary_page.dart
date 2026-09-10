import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/widgets/count_up_text.dart';
import '../../data/services/storage_service.dart';

/// 五险一金条目：名称 + 个人缴纳比例 + 单位缴纳比例
class _SalaryItem {
  _SalaryItem(this.name, this.personal, this.company);

  final String name;
  double personal;
  double company;
}

/// 薪资计算器：输入税前月薪与五险一金构成，估算个人/单位缴纳与税后到手
class SalaryPage extends StatefulWidget {
  const SalaryPage({super.key});

  @override
  State<SalaryPage> createState() => _SalaryPageState();
}

class _SalaryPageState extends State<SalaryPage> {
  /// 个税起征点（元/月）
  static const double _threshold = 5000;

  static const _configKey = 'salary_config';

  final _grossCtrl = TextEditingController(text: '10000');
  final _baseCtrl = TextEditingController();
  final _deductCtrl = TextEditingController();

  List<_SalaryItem> _items = _defaultItems();

  static List<_SalaryItem> _defaultItems() => [
        _SalaryItem('养老保险', 0.08, 0.16),
        _SalaryItem('医疗保险', 0.02, 0.095),
        _SalaryItem('失业保险', 0.005, 0.005),
        _SalaryItem('工伤保险', 0, 0.002),
        _SalaryItem('生育保险', 0, 0.008),
        _SalaryItem('住房公积金', 0.12, 0.12),
      ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
    for (final c in [_grossCtrl, _baseCtrl, _deductCtrl]) {
      c.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final c in [_grossCtrl, _baseCtrl, _deductCtrl]) {
      c.removeListener(_onChanged);
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _loadConfig() {
    final raw = StorageService().getConfig(_configKey);
    if (raw is! Map) return;
    final items = raw['items'];
    if (items is List) {
      final loaded = <_SalaryItem>[];
      for (final e in items) {
        if (e is Map && e['name'] is String) {
          loaded.add(_SalaryItem(
            e['name'] as String,
            (e['personal'] as num?)?.toDouble() ?? 0,
            (e['company'] as num?)?.toDouble() ?? 0,
          ));
        }
      }
      if (loaded.isNotEmpty) _items = loaded;
    }
    final d = raw['deduction'];
    if (d is num && d > 0) _deductCtrl.text = d.toStringAsFixed(0);
  }

  void _saveConfig() {
    StorageService().setConfig(_configKey, {
      'items': [
        for (final i in _items)
          {'name': i.name, 'personal': i.personal, 'company': i.company},
      ],
      'deduction': double.tryParse(_deductCtrl.text.trim()) ?? 0,
    });
  }

  // ---------------- 计算 ----------------

  double get _gross => double.tryParse(_grossCtrl.text.trim()) ?? 0;

  /// 缴费基数：留空时按税前月薪
  double get _base {
    final v = double.tryParse(_baseCtrl.text.trim());
    return (v != null && v > 0) ? v : _gross;
  }

  double get _deduction => double.tryParse(_deductCtrl.text.trim()) ?? 0;

  double get _personalTotal =>
      _items.fold(0.0, (s, i) => s + _base * i.personal);

  double get _companyTotal =>
      _items.fold(0.0, (s, i) => s + _base * i.company);

  double get _taxable =>
      (_gross - _personalTotal - _threshold - _deduction)
          .clamp(0.0, double.infinity);

  double get _tax => _monthlyTax(_taxable);

  double get _net => _gross - _personalTotal - _tax;

  double get _companyCost => _gross + _companyTotal;

  /// 月度个税（按月换算的综合所得税率表，速算扣除数）
  static double _monthlyTax(double taxable) {
    if (taxable <= 0) return 0;
    const brackets = <(double, double, double)>[
      (3000, 0.03, 0),
      (12000, 0.10, 210),
      (25000, 0.20, 1410),
      (35000, 0.25, 2660),
      (55000, 0.30, 4410),
      (80000, 0.35, 7160),
      (double.infinity, 0.45, 15160),
    ];
    for (final (cap, rate, quick) in brackets) {
      if (taxable <= cap) {
        final v = taxable * rate - quick;
        return v > 0 ? v : 0;
      }
    }
    return 0;
  }

  // ---------------- 展示 ----------------

  String _money(double v) => '¥${v.toStringAsFixed(2)}';

  String _pct(double ratio) {
    final p = ratio * 100;
    return p == p.roundToDouble()
        ? p.toStringAsFixed(0)
        : p.toStringAsFixed(1);
  }

  String _share(double amount) =>
      _gross > 0 ? '${(amount / _gross * 100).toStringAsFixed(1)}%' : '--';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('薪资计算器'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '恢复默认比例',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () {
              setState(() => _items = _defaultItems());
              _saveConfig();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInputCard(cs),
          const SizedBox(height: 12),
          _buildBreakdownCard(cs),
          const SizedBox(height: 12),
          _buildResultCard(cs),
          const SizedBox(height: 8),
          Text(
            '说明：按通用比例估算，各地社保基数上下限、公积金比例与专项附加扣除不同，'
            '实际金额以当地政策与公司申报为准。',
            style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('薪资输入',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _numField(
              controller: _grossCtrl,
              label: '税前月薪 (¥)',
              icon: Icons.payments_rounded,
            ),
            const SizedBox(height: 12),
            _numField(
              controller: _baseCtrl,
              label: '五险一金缴费基数 (¥，留空按税前月薪)',
              icon: Icons.percent_rounded,
            ),
            const SizedBox(height: 12),
            _numField(
              controller: _deductCtrl,
              label: '专项附加扣除 (¥/月，选填)',
              icon: Icons.receipt_long_rounded,
            ),
            const SizedBox(height: 10),
            Text(
              '当前缴费基数：${_money(_base)}　起征点：${_money(_threshold)}',
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }

  Widget _buildBreakdownCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('五险一金构成',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('点击条目可修改比例',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _items.length; i++) _buildItemRow(cs, i),
            const Divider(height: 20),
            _summaryRow(
              cs,
              '个人合计',
              _personalTotal,
              color: cs.error,
            ),
            const SizedBox(height: 6),
            _summaryRow(
              cs,
              '单位合计',
              _companyTotal,
              color: cs.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(ColorScheme cs, int index) {
    final item = _items[index];
    final personal = _base * item.personal;
    final company = _base * item.company;
    return InkWell(
      onTap: () => _editRates(index),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.name,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w500)),
                ),
                Text('个人 ${_pct(item.personal)}%',
                    style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                const SizedBox(width: 10),
                Text('单位 ${_pct(item.company)}%',
                    style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                const SizedBox(width: 4),
                Icon(Icons.edit_rounded,
                    size: 14,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '个人 ${_money(personal)}（${_share(personal)}）　'
              '单位 ${_money(company)}（${_share(company)}）',
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(ColorScheme cs, String label, double value,
      {required Color color}) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('${_money(value)}（占税前 ${_share(value)}）',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ],
    );
  }

  Widget _buildResultCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('估算结果',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _resultRow(cs, '税前月薪', _money(_gross)),
            _resultRow(cs, '个人五险一金', '-${_money(_personalTotal)}',
                note: '占税前 ${_share(_personalTotal)}'),
            _resultRow(cs, '个人所得税', '-${_money(_tax)}',
                note: '应纳税所得额 ${_money(_taxable)}'),
            _resultRow(cs, '单位五险一金', '+${_money(_companyTotal)}',
                note: '占税前 ${_share(_companyTotal)}'),
            const Divider(height: 22),
            Center(
              child: Column(
                children: [
                  Text('税后到手',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.8))),
                  const SizedBox(height: 4),
                  CountUpText(
                    value: _net,
                    formatter: (v) => _money(v),
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _net >= 0 ? cs.primary : cs.error,
                        fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text('公司总成本 ${_money(_companyCost)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.85))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(ColorScheme cs, String label, String value,
      {String? note}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()])),
              if (note != null)
                Text(note,
                    style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- 编辑比例 ----------------

  void _editRates(int index) {
    final item = _items[index];
    final pCtrl =
        TextEditingController(text: _pct(item.personal));
    final cCtrl = TextEditingController(text: _pct(item.company));

    void save() {
      final p = double.tryParse(pCtrl.text.trim());
      final c = double.tryParse(cCtrl.text.trim());
      if (p == null || c == null || p < 0 || c < 0 || p > 100 || c > 100) {
        Get.snackbar('提示', '请输入 0-100 之间的比例');
        return;
      }
      setState(() {
        item.personal = p / 100;
        item.company = c / 100;
      });
      _saveConfig();
      Get.closeCurrentSnackbar();
      Get.back();
    }

    Get.dialog(
      AlertDialog(
        title: Text('${item.name} · 缴费比例'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: '个人比例', suffixText: '%'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: '单位比例', suffixText: '%'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          ElevatedButton(onPressed: save, child: const Text('保存')),
        ],
      ),
    );
  }
}
