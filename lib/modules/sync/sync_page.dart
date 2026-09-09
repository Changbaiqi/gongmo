import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'sync_controller.dart';
import '../../core/widgets/count_up_text.dart';

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
            _Entrance(
              index: 0,
              child: _buildStatusCard(context, ctrl, cs, connected),
            ),
            const SizedBox(height: 12),
            _Entrance(
              index: 1,
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
              index: 2,
              child: _buildStatsCard(context, ctrl, cs),
            ),
            const SizedBox(height: 24),
            _Entrance(
              index: 3,
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
              index: 4,
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
              index: 5,
              child: TextButton.icon(
                onPressed: busy ? null : () => ctrl.exportJson(),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('导出备份到本地'),
              ),
            ),
            const SizedBox(height: 8),
            _Entrance(
              index: 6,
              child: Text(
                '备份文件为 JSON 格式，保存于 GitHub 仓库根目录的 gongmo_backup.json；'
                '恢复时会覆盖本地全部数据，请谨慎操作。',
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
