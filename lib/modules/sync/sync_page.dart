import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'sync_controller.dart';

class SyncPage extends StatelessWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SyncController ctrl = Get.put(SyncController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub 同步'),
        centerTitle: true,
      ),
      body: Obx(() => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_sync,
                          size: 64,
                          color:
                              ctrl.isSyncing.value ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        if (ctrl.isSyncing.value)
                          const CircularProgressIndicator()
                        else
                          Text(
                            ctrl.lastSyncTime.value != null
                                ? '上次同步: ${ctrl.lastSyncTime.value}'
                                : '尚未同步',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _infoRow('本地工时记录', '${ctrl.totalEntries.value} 条'),
                        const Divider(),
                        _infoRow('同步状态',
                            ctrl.lastSyncTime.value != null ? '已同步' : '未同步'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed:
                      ctrl.isSyncing.value ? null : () => ctrl.pushToGithub(),
                  icon: const Icon(Icons.cloud_upload),
                  label: Text(ctrl.isSyncing.value ? '同步中...' : '同步到 GitHub'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ctrl.exportJson(),
                  icon: const Icon(Icons.download),
                  label: const Text('导出 JSON'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          )),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
