import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'sync_controller.dart';

class SyncPage extends StatelessWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SyncController ctrl = Get.put(SyncController());
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub 同步'),
        centerTitle: true,
      ),
      body: Obx(() {
        final connected = ctrl.isConnected;
        final busy = ctrl.isSyncing.value || ctrl.isRestoring.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusCard(context, ctrl, cs, connected),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading:
                    Icon(Icons.autorenew_rounded, color: cs.primary),
                title: const Text('自动同步'),
                subtitle: Text(
                  connected
                      ? '数据变动后自动备份到 GitHub'
                      : '需先绑定仓库并填写 Token',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
                trailing: Obx(() => Switch(
                      value: ctrl.autoSync.value,
                      onChanged: (v) => ctrl.setAutoSync(v),
                    )),
              ),
            ),
            const SizedBox(height: 12),
            _buildStatsCard(context, ctrl, cs),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: busy ? null : () => ctrl.pushToGithub(),
              icon: ctrl.isSyncing.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(ctrl.isSyncing.value ? '正在备份...' : '备份到 GitHub'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : () => _confirmRestore(context, ctrl),
              icon: ctrl.isRestoring.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restore_rounded),
              label: Text(ctrl.isRestoring.value ? '正在恢复...' : '从 GitHub 恢复'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: busy ? null : () => ctrl.exportJson(),
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('导出备份到本地'),
            ),
            const SizedBox(height: 8),
            Text(
              '备份文件为 JSON 格式，保存于 GitHub 仓库根目录的 gongmo_backup.json；'
              '恢复时会覆盖本地全部数据，请谨慎操作。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStatusCard(
      BuildContext context, SyncController ctrl, ColorScheme cs, bool connected) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              connected
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              size: 56,
              color: connected ? cs.primary : cs.outline,
            ),
            const SizedBox(height: 12),
            Text(
              connected ? '已连接' : '未绑定仓库',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Obx(() => Text(
                  ctrl.repoDisplay.isNotEmpty
                      ? ctrl.repoDisplay
                      : '请在设置中填写仓库地址与 Token',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )),
            const SizedBox(height: 4),
            Obx(() => Text(
                  ctrl.lastSyncTime.value != null
                      ? '上次备份：${_formatTime(ctrl.lastSyncTime.value!)}'
                      : '尚未备份',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                )),
            if (!connected) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => Get.toNamed('/settings'),
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('去设置绑定'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
      BuildContext context, SyncController ctrl, ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Obx(() => Column(
              children: [
                _infoRow('本地计时记录', '${ctrl.workCount.value} 条', cs),
                const Divider(height: 1),
                _infoRow('本地账目记录', '${ctrl.financeCount.value} 条', cs),
                const Divider(height: 1),
                _infoRow('合计', '${ctrl.totalEntries.value} 条', cs),
              ],
            )),
      ),
    );
  }

  Widget _infoRow(String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _confirmRestore(BuildContext context, SyncController ctrl) {
    Get.dialog(
      AlertDialog(
        title: const Text('从 GitHub 恢复'),
        content: const Text(
            '将使用云端备份覆盖本地全部数据（计时、账目、分类、标签），\n此操作不可撤销，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              ctrl.restoreFromGithub();
            },
            child: const Text('确定恢复', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
