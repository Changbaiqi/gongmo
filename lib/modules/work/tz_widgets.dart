import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 可选时区（IANA 名称 + 城市 + 国家/地区）
class TzOption {
  const TzOption(this.id, this.city, this.region);

  final String id;
  final String city;
  final String region;
}

const tzOptions = <TzOption>[
  TzOption('Asia/Shanghai', '北京', '中国'),
  TzOption('Asia/Hong_Kong', '香港', '中国香港'),
  TzOption('Asia/Taipei', '台北', '中国台湾'),
  TzOption('Asia/Seoul', '首尔', '韩国'),
  TzOption('Asia/Tokyo', '东京', '日本'),
  TzOption('Asia/Singapore', '新加坡', '新加坡'),
  TzOption('Asia/Bangkok', '曼谷', '泰国'),
  TzOption('Asia/Kolkata', '孟买', '印度'),
  TzOption('Asia/Dubai', '迪拜', '阿联酋'),
  TzOption('Europe/Moscow', '莫斯科', '俄罗斯'),
  TzOption('Europe/Berlin', '柏林', '德国'),
  TzOption('Europe/Paris', '巴黎', '法国'),
  TzOption('Europe/London', '伦敦', '英国'),
  TzOption('America/Sao_Paulo', '圣保罗', '巴西'),
  TzOption('America/New_York', '纽约', '美国东部'),
  TzOption('America/Chicago', '芝加哥', '美国中部'),
  TzOption('America/Denver', '丹佛', '美国山地'),
  TzOption('America/Los_Angeles', '洛杉矶', '美国西部'),
  TzOption('Pacific/Honolulu', '檀香山', '美国夏威夷'),
  TzOption('Australia/Sydney', '悉尼', '澳大利亚'),
  TzOption('Pacific/Auckland', '奥克兰', '新西兰'),
];

String tzCity(String id) {
  for (final z in tzOptions) {
    if (z.id == id) return z.city;
  }
  return id;
}

String tzRegion(String id) {
  for (final z in tzOptions) {
    if (z.id == id) return z.region;
  }
  return '';
}

/// 弹出时区多选面板；返回新的选择，取消返回 null
Future<List<String>?> showZonePicker(
    BuildContext context, List<String> selected) {
  var current = List<String>.from(selected);
  return Get.bottomSheet<List<String>>(
    StatefulBuilder(
      builder: (context, setSheet) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const Text('选择时区',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('至少 1 个，最多 8 个',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 380,
                  child: ListView.builder(
                    itemCount: tzOptions.length,
                    itemBuilder: (context, i) {
                      final z = tzOptions[i];
                      final sel = current.contains(z.id);
                      return CheckboxListTile(
                        dense: true,
                        value: sel,
                        title: Text('${z.city}  ${z.region}',
                            style: const TextStyle(fontSize: 13.5)),
                        subtitle: Text(z.id,
                            style: TextStyle(
                                fontSize: 10.5,
                                color: cs.onSurfaceVariant)),
                        onChanged: (v) {
                          if (v == true) {
                            if (current.length >= 8) {
                              Get.snackbar('提示', '最多选择 8 个时区');
                              return;
                            }
                            current.add(z.id);
                          } else {
                            if (current.length <= 1) {
                              Get.snackbar('提示', '至少保留一个时区');
                              return;
                            }
                            current.remove(z.id);
                          }
                          setSheet(() {});
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Get.back(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Get.back(result: current),
                          child: const Text('确定'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}
