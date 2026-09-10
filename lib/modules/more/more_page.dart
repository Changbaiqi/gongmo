import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';

/// “更多”功能页：网格入口，聚合扩展工具
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  static const _items = <(
    IconData icon,
    String label,
    String subtitle,
    String route,
  )>[
    (Icons.receipt_rounded, '发票助手', '管理常用开票抬头', AppRoutes.invoice),
    (
      Icons.currency_exchange_rounded,
      '汇率计算器',
      '人民币换算常用货币',
      AppRoutes.exchange,
    ),
    (
      Icons.calculate_rounded,
      '薪资计算器',
      '五险一金与税后工资估算',
      AppRoutes.salary,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('更多'),
        centerTitle: true,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
        children: [
          for (final (icon, label, subtitle, route) in _items)
            _featureCard(context, cs, icon, label, subtitle, route),
        ],
      ),
    );
  }

  Widget _featureCard(BuildContext context, ColorScheme cs, IconData icon,
      String label, String subtitle, String route) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Get.toNamed(route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 24, color: cs.primary),
              ),
              const Spacer(),
              Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
