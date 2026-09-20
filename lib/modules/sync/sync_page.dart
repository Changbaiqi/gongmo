// ============================================================
// sync_page.dart（同步模块 · 页面）
// 职责：GitHub 同步页 UI——展示连接/备份状态与本地数据统计，提供自动同步
//       开关、手动备份、云端恢复（二次确认）、本地导出四个操作入口。
// 关联：SyncController（全部业务逻辑与状态）；页面通过 /sync 路由进入。
// ============================================================
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'sync_controller.dart';
import '../../core/widgets/count_up_text.dart';
import '../../data/services/local_backup_service.dart';

/// 数据备份页：无状态页面，状态全部来自 [SyncController]。
///
/// 用 `busy`（同步中或恢复中）统一禁用操作按钮，防止备份与恢复并发导致
/// 数据互相覆盖。包含「本地备份」（公共下载目录，不依赖 GitHub）与
/// 「GitHub 同步」两部分。
class SyncPage extends StatelessWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SyncController ctrl = Get.put(SyncController());
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据备份'),
        centerTitle: true,
      ),
      body: Obx(() {
        final connected = ctrl.isConnected;
        // 任一流程进行中即锁定所有操作入口，避免并发写云端/本地
        final busy = ctrl.isSyncing.value || ctrl.isRestoring.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Entrance(
              index: 0,
              child: _buildPathsCard(context, cs),
            ),
            const SizedBox(height: 12),
            _Entrance(
              index: 1,
              child: _buildLocalCard(context, ctrl, cs, busy),
            ),
            const SizedBox(height: 20),
            _Entrance(
              index: 2,
              child: Row(
                children: [
                  Icon(Icons.cloud_sync_outlined, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  const Text('GitHub 同步',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _Entrance(
              index: 3,
              child: _buildStatusCard(context, ctrl, cs, connected),
            ),
            const SizedBox(height: 12),
            _Entrance(
              index: 4,
              child: Card(
                child: ListTile(
                  leading: _SpinIcon(
                    icon: Icons.autorenew_rounded,
                    color: cs.primary,
                    spinning: ctrl.autoSync.value,
                  ),
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
            ),
            const SizedBox(height: 12),
            _Entrance(
              index: 5,
              child: _buildStatsCard(context, ctrl, cs),
            ),
            const SizedBox(height: 24),
            _Entrance(
              index: 6,
              child: ElevatedButton.icon(
                onPressed: busy ? null : () => ctrl.pushToGithub(),
                icon: ctrl.isSyncing.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label:
                    Text(ctrl.isSyncing.value ? '正在备份...' : '备份到 GitHub'),
              ),
            ),
            const SizedBox(height: 12),
            _Entrance(
              index: 7,
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => _confirmRestore(context, ctrl),
                icon: ctrl.isRestoring.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore_rounded),
                label:
                    Text(ctrl.isRestoring.value ? '正在恢复...' : '从 GitHub 恢复'),
              ),
            ),
            const SizedBox(height: 12),
            _Entrance(
              index: 8,
              child: TextButton.icon(
                onPressed: busy ? null : () => ctrl.exportPackage(),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('导出数据到本地'),
              ),
            ),
            const SizedBox(height: 12),
            _Entrance(
              index: 9,
              child: TextButton.icon(
                onPressed: busy ? null : () => ctrl.importFromFile(),
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('导入本地数据'),
              ),
            ),
            const SizedBox(height: 8),
            _Entrance(
              index: 10,
              child: Text(
                '备份按年份分片保存在仓库的 gongmo_backup/ 目录；“备份”会先合并云端数据再上传，'
                '多台设备同时记录也不会互相覆盖；“恢复”会用云端数据覆盖本地，请谨慎操作。'
                '「导出数据到本地」生成 .gongmo 数据包（压缩的原始分片文件），'
                '「导入本地数据」读取该数据包、快照目录或旧版 JSON，可选择合并（推荐）或覆盖。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  /// 顶部路径卡片：软件数据目录 + 本地备份目录，都可查看/打开
  Widget _buildPathsCard(BuildContext context, ColorScheme cs) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.storage_rounded, size: 20, color: cs.primary),
            title: const Text('软件数据目录',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            subtitle: Text(
              LocalBackupService.dataDirPath,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
            ),
            trailing: TextButton(
              onPressed: () => _showDataDir(context, cs),
              child: const Text('查看'),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading:
                Icon(Icons.folder_open_rounded, size: 20, color: cs.primary),
            title: const Text('本地备份目录',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            subtitle: Text(
              LocalBackupService.visibleFolder,
              style: TextStyle(
                  fontSize: 10.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
            ),
            trailing: TextButton(
              onPressed: () => _showBackupDir(context, cs),
              child: const Text('查看'),
            ),
          ),
        ],
      ),
    );
  }

  /// 本地备份目录内容（与「软件数据目录」一致的查看方式，位于公共目录）
  Future<void> _showBackupDir(BuildContext context, ColorScheme cs) async {
    final files = await LocalBackupService.listSnapshots();
    if (!context.mounted) return;
    final grouped = <String, List<LocalBackupFile>>{};
    for (final f in files) {
      grouped.putIfAbsent(f.folder, () => []).add(f);
    }
    final folders = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final buf = StringBuffer('${LocalBackupService.visibleFolder}/');
    if (folders.isEmpty) {
      buf.write('\n\n（还没有备份）');
    }
    for (final folder in folders) {
      buf.write('\n\n${folder.isEmpty ? '(旧版备份)' : folder}/');
      for (final f in grouped[folder]!) {
        buf.write(
            '\n  ${f.name}  (${(f.size / 1024).toStringAsFixed(1)} KB)');
      }
    }
    final path = LocalBackupService.visibleFolder;
    Get.dialog(
      AlertDialog(
        title: const Text('本地备份目录'),
        content: SizedBox(
          width: double.maxFinite,
          height: 380,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(path, style: TextStyle(fontSize: 11, color: cs.primary)),
                const SizedBox(height: 10),
                Text(buf.toString(),
                    style: const TextStyle(fontSize: 11.5, height: 1.6)),
                const SizedBox(height: 10),
                Text(
                  '每个时间戳目录是一次完整快照（原始分片文件，不打包）；'
                  '自动备份只保留最近 3 个快照。',
                  style: TextStyle(
                      fontSize: 10.5,
                      height: 1.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: path));
              Get.closeCurrentSnackbar();
              Get.back();
              Get.snackbar('已复制路径', path);
            },
            child: const Text('复制路径'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await LocalBackupService.openFolder();
              if (!ok) {
                Get.snackbar('无法打开', '路径：$path');
              }
            },
            child: const Text('打开目录'),
          ),
        ],
      ),
    );
  }

  /// 应用私有数据目录无法被其它应用浏览，这里用应用内列表展示内容
  Future<void> _showDataDir(BuildContext context, ColorScheme cs) async {
    final path = LocalBackupService.dataDirPath;
    var items = '';
    try {
      final dir = Directory(path);
      final entities = dir.listSync()
        ..sort((a, b) => a.path.compareTo(b.path));
      final lines = <String>[];
      for (final e in entities) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        final size = await e.length();
        lines.add('$name  (${(size / 1024).toStringAsFixed(1)} KB)');
      }
      items = lines.isEmpty ? '（目录为空）' : lines.join('\n');
    } catch (e) {
      items = '读取失败：$e';
    }
    if (!context.mounted) return;
    Get.dialog(
      AlertDialog(
        title: const Text('软件数据目录'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(path,
                    style: TextStyle(
                        fontSize: 11, color: cs.primary)),
                const SizedBox(height: 10),
                Text(items,
                    style: const TextStyle(fontSize: 11.5, height: 1.6)),
                const SizedBox(height: 10),
                Text(
                  '该目录属于应用私有空间，系统文件管理器无法进入；'
                  '需要外部查看时请用「备份到本地」镜像到公共目录。',
                  style: TextStyle(
                      fontSize: 10.5,
                      height: 1.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: path));
              Get.closeCurrentSnackbar();
              Get.back();
              Get.snackbar('已复制路径', path);
            },
            child: const Text('复制路径'),
          ),
          TextButton(onPressed: () => Get.back(), child: const Text('关闭')),
        ],
      ),
    );
  }

  /// 本地备份卡片：不依赖 GitHub，备份到公共下载目录，清理应用数据也不会丢
  Widget _buildLocalCard(
      BuildContext context, SyncController ctrl, ColorScheme cs, bool busy) {
    final last = ctrl.localBackupLast.value;
    final lastText = last == null
        ? '还没有本地备份'
        : '最近备份：${last.month.toString().padLeft(2, '0')}-'
            '${last.day.toString().padLeft(2, '0')} '
            '${last.hour.toString().padLeft(2, '0')}:'
            '${last.minute.toString().padLeft(2, '0')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                const Text('本地备份',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  lastText,
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '直接镜像数据目录里的原始文件到手机公共目录「下载 / ${LocalBackupService.folderName} / 时间戳」，'
              '不打包所以很快；不依赖 GitHub，清理应用数据或重装后依然保留。',
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.85)),
            ),
            if (ctrl.localBackupPath.value != null) ...[
              const SizedBox(height: 6),
              Text(
                ctrl.localBackupPath.value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10.5,
                    color: cs.primary.withValues(alpha: 0.9)),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (busy || ctrl.localBackupBusy.value)
                        ? null
                        : () => ctrl.backupToLocal(),
                    icon: ctrl.localBackupBusy.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_alt_rounded, size: 18),
                    label: const Text('备份到本地'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => ctrl.exportPackage(),
                    icon: const Icon(Icons.archive_outlined, size: 17),
                    label: const Text('导出本地备份'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Obx(() => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  secondary: Icon(Icons.autorenew_rounded,
                      size: 18, color: cs.primary),
                  title: const Text('自动本地备份',
                      style: TextStyle(fontSize: 13.5)),
                  subtitle: Text('每天自动备份一份（数据变动时检查，最快 24 小时一次）',
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.8))),
                  value: ctrl.localBackupAuto.value,
                  onChanged: (v) => ctrl.setLocalBackupAuto(v),
                )),
          ],
        ),
      ),
    );
  }

  /// 顶部状态卡：连接状态云朵图标、仓库地址、上次备份时间，未绑定时给出入口
  Widget _buildStatusCard(
      BuildContext context, SyncController ctrl, ColorScheme cs, bool connected) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _CloudStatusIcon(
              connected: connected,
              syncing: ctrl.isSyncing.value,
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
                _infoRow('本地计时记录', ctrl.workCount.value.toDouble(), cs),
                const Divider(height: 1),
                _infoRow('本地账目记录', ctrl.financeCount.value.toDouble(), cs),
                const Divider(height: 1),
                _infoRow('合计', ctrl.totalEntries.value.toDouble(), cs),
              ],
            )),
      ),
    );
  }

  Widget _infoRow(String label, double value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5)),
          CountUpText(
            value: value,
            formatter: (v) => '${v.round()} 条',
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// 恢复是覆盖式操作（云端 → 本地），必须二次确认；确认后才真正发起拉取
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

/// 云朵状态图标：常态缓慢上下漂浮；同步中加速浮动并伴随光晕脉冲，
/// 图标切换（连接/断开/同步）带缩放淡入过渡
class _CloudStatusIcon extends StatefulWidget {
  const _CloudStatusIcon({
    required this.connected,
    required this.syncing,
    required this.color,
  });

  final bool connected;
  final bool syncing;
  final Color color;

  @override
  State<_CloudStatusIcon> createState() => _CloudStatusIconState();
}

class _CloudStatusIconState extends State<_CloudStatusIcon>
    with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  @override
  void initState() {
    super.initState();
    if (widget.syncing) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _CloudStatusIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.syncing && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.syncing && _pulse.isAnimating) {
      _pulse.animateBack(0, duration: const Duration(milliseconds: 180));
    }
  }

  @override
  void dispose() {
    _float.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = widget.syncing
        ? Icons.cloud_sync_outlined
        : widget.connected
            ? Icons.cloud_done_outlined
            : Icons.cloud_off_outlined;
    return AnimatedBuilder(
      animation: Listenable.merge([_float, _pulse]),
      builder: (context, _) {
        final floatT = Curves.easeInOut.transform(_float.value);
        final dy = (widget.syncing ? 6.0 : 3.0) * (floatT - 0.5) * 2;
        final pulse = widget.syncing ? _pulse.value : 0.0;
        return SizedBox(
          width: 100,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (pulse > 0)
                Container(
                  width: 66 + 22 * pulse,
                  height: 66 + 22 * pulse,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withValues(alpha: 0.16 * (1 - pulse)),
                  ),
                ),
              Transform.translate(
                offset: Offset(0, -dy),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Icon(
                    icon,
                    key: ValueKey(icon),
                    size: 56,
                    color: widget.color,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 自动同步开关左侧图标：开启时缓慢旋转
class _SpinIcon extends StatefulWidget {
  const _SpinIcon({
    required this.icon,
    required this.color,
    required this.spinning,
  });

  final IconData icon;
  final Color color;
  final bool spinning;

  @override
  State<_SpinIcon> createState() => _SpinIconState();
}

class _SpinIconState extends State<_SpinIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _SpinIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.spinning && _ctrl.isAnimating) {
      _ctrl.animateBack(0, duration: const Duration(milliseconds: 220));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Icon(widget.icon, color: widget.color),
    );
  }
}

/// 页面元素首次出现时上滑淡入（按 index 交错延迟）
class _Entrance extends StatefulWidget {
  const _Entrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 45 * widget.index.clamp(0, 8));
    Future.delayed(delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, 0.06),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
