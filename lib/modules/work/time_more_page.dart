import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';

/// 时钟「更多」页：时间工具聚合入口（与记账的「更多」页面设计一致但相互独立）
class TimeMorePage extends StatelessWidget {
  const TimeMorePage({super.key});

  static const _items = <(
    IconData icon,
    String label,
    String subtitle,
    String route,
  )>[
    (
      Icons.timer_rounded,
      '秒表',
      '计时、计次与分段用时',
      AppRoutes.stopwatch,
    ),
    (
      Icons.public_rounded,
      '时区重叠图',
      '跨时区协作的重叠时段',
      AppRoutes.timezones,
    ),
    (
      Icons.schedule_rounded,
      '时区显示/转换',
      '查看并换算各国当前时间',
      AppRoutes.tzConverter,
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
