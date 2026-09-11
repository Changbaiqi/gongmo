// ============================================================
// more_page.dart（更多模块 · 入口页）
// 职责：“更多”页，用两列网格聚合扩展工具入口（发票助手 / 汇率计算器 /
//       薪资计算器），点击后按命名路由跳转。
// 关联：各工具页相互独立、不依赖控制器；路由常量集中在 AppRoutes。
// ============================================================
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';

/// “更多”功能页：网格入口，聚合扩展工具。
///
/// 无状态页面；功能项以记录元组 `(icon, label, subtitle, route)` 声明，
/// 新增工具只需在 `_items` 里加一行并注册对应路由。
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  // 网格数据源：图标、标题、副标题、命名路由
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
