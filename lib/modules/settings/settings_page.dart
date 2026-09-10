import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_controller.dart';
import '../../data/services/auto_bookkeeping_service.dart';
import '../../data/services/github_sync_service.dart';
import '../../data/services/keep_alive_service.dart';
import '../../data/services/reminder_service.dart';
import '../lock/lock_controller.dart';
import '../lock/pattern_setup_page.dart';
import 'settings_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController ctrl = Get.put(SettingsController());
    final ThemeController tc = Get.put(ThemeController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Entrance(index: 0, child: _buildSectionTitle('外观')),
          _Entrance(index: 1, child: _buildAppearanceCard(context, tc)),
          const SizedBox(height: 24),
          _Entrance(index: 2, child: _buildSectionTitle('自动记账')),
          _Entrance(index: 3, child: _AutoAccountingCard(ctrl: ctrl)),
          const SizedBox(height: 24),
          _Entrance(index: 4, child: _buildSectionTitle('记账提醒')),
          _Entrance(index: 5, child: const _ReminderCard()),
          const SizedBox(height: 24),
          _Entrance(index: 6, child: _buildSectionTitle('GitHub 连接')),
          _Entrance(
              index: 7,
              child: Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('仓库地址'),
                  subtitle: Obx(() => Text(
                        ctrl.githubRepoUrl.value.isEmpty
                            ? '未绑定'
                            : ctrl.githubRepoUrl.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showGithubConfig(ctrl),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_sync),
                  title: const Text('同步设置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Get.toNamed('/sync'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded,
                      color: Colors.red.shade600),
                  title: Text('清空所有云端备份',
                      style: TextStyle(
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '危险操作：将永久删除仓库中的全部分备份文件',
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.red.shade400),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: Colors.red),
                  onTap: () => _confirmClearCloudBackups(ctrl),
                ),
              ],
            ),
          )),
          const SizedBox(height: 24),
          _Entrance(index: 8, child: _buildSectionTitle('安全')),
          _Entrance(index: 9, child: _buildSecurityCard(context)),
          const SizedBox(height: 24),
          _Entrance(index: 10, child: _buildSectionTitle('关于')),
          _Entrance(
              index: 11,
              child: Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('版本'),
                  trailing: Text('v1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('开源仓库地址'),
                  subtitle: const Text('github.com/Changbaiqi/gongmo'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse('https://github.com/Changbaiqi/gongmo'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('开源协议'),
                  trailing: const Text('MIT'),
                  onTap: () {},
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  /// 安全：应用锁（图案密码 + 生物识别）
  Widget _buildSecurityCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lock = Get.find<LockController>();
    return Card(
      child: Obx(() => Column(
            children: [
              SwitchListTile(
                secondary:
                    Icon(Icons.lock_outline_rounded, color: cs.primary),
                title: const Text('应用锁'),
                subtitle: Text(
                  lock.hasPattern.value
                      ? '启动或回到应用时需验证身份'
                      : '开启前需先设置解锁图案',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
                value: lock.enabled.value,
                onChanged: (v) async {
                  if (v) {
                    if (!lock.hasPattern.value) {
                      final ok =
                          await Get.to(() => const PatternSetupPage());
                      if (ok != true) return;
                    }
                    await lock.setEnabled(true);
                    // 设备支持时默认同时开启指纹解锁
                    if (lock.biometricAvailable.value &&
                        !lock.biometricEnabled.value) {
                      await lock.setBiometricEnabled(true);
                    }
                    Get.snackbar(
                        '已开启应用锁',
                        lock.biometricEnabled.value
                            ? '下次启动或回到应用时可用指纹快速解锁'
                            : '下次启动或回到应用时需解锁');
                  } else {
                    await lock.setEnabled(false);
                  }
                },
              ),
              if (lock.enabled.value && lock.biometricAvailable.value) ...[
                const Divider(height: 1),
                SwitchListTile(
                  secondary:
                      Icon(Icons.fingerprint_rounded, color: cs.primary),
                  title: const Text('指纹/生物识别解锁'),
                  subtitle: Text('使用系统指纹或面容快速解锁',
                      style: TextStyle(
                          fontSize: 11.5,
                          color:
                              cs.onSurfaceVariant.withValues(alpha: 0.8))),
                  value: lock.biometricEnabled.value,
                  onChanged: (v) => lock.setBiometricEnabled(v),
                ),
              ],
              if (lock.hasPattern.value) ...[
                const Divider(height: 1),
                ListTile(
                  leading:
                      Icon(Icons.grid_view_rounded, color: cs.primary),
                  title: const Text('修改解锁图案'),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => Get.to(() => const PatternSetupPage()),
                ),
              ],
            ],
          )),
    );
  }

  /// 清空云端备份：需输入指定文字二次确认
  void _confirmClearCloudBackups(SettingsController ctrl) {
    final confirmCtrl = TextEditingController();
    final canConfirm = false.obs;
    const keyword = '自愿清空仓库';

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('清空所有云端备份'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                '将永久删除仓库中的全部分备份文件（含所有年份的计时与账目备份），删除后无法恢复！',
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: Colors.red.shade700),
              ),
            ),
            const SizedBox(height: 12),
            const Text('如确认执行，请输入「自愿清空仓库」：',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: confirmCtrl,
              autofocus: true,
              onChanged: (v) => canConfirm.value = v.trim() == keyword,
              decoration: const InputDecoration(
                hintText: '自愿清空仓库',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          Obx(() => TextButton(
                onPressed: canConfirm.value
                    ? () {
                        Get.back();
                        ctrl.clearCloudBackups();
                      }
                    : null,
                child: Text('确认清空',
                    style: TextStyle(
                        color:
                            canConfirm.value ? Colors.red.shade600 : null)),
              )),
        ],
      ),
    );
  }

  Widget _buildAppearanceCard(BuildContext context, ThemeController tc) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('深色模式',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _modePill(context, tc, '跟随系统', ThemeMode.system),
                    const SizedBox(width: 8),
                    _modePill(context, tc, '浅色', ThemeMode.light),
                    const SizedBox(width: 8),
                    _modePill(context, tc, '深色', ThemeMode.dark),
                  ],
                ),
                const SizedBox(height: 18),
                Text('主题配色',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    itemCount: AppThemePreset.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) =>
                        _presetTile(context, tc, AppThemePreset.values[index]),
                  ),
                ),
                const SizedBox(height: 18),
                Text('自定义背景',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (tc.hasBackground) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(tc.backgroundPath.value),
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) =>
                              Container(width: 52, height: 52, color:
                                  cs.surfaceContainerHighest),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickBackgroundImage(tc),
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: Text(tc.hasBackground ? '更换背景' : '选择背景图片'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: cs.surface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    if (tc.hasBackground) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          tc.clearBackground();
                          Get.snackbar('已清除', '已恢复默认背景');
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: '清除背景',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tc.hasBackground
                      ? '背景图会铺在所有页面下方，卡片保持不透明'
                      : '从相册选择图片作为应用背景',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                ),
              ],
            )),
      ),
    );
  }

  Widget _modePill(
      BuildContext context, ThemeController tc, String label, ThemeMode mode) {
    final cs = Theme.of(context).colorScheme;
    final selected = tc.mode.value == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => tc.setMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected
                      ? cs.primary
                      : cs.onSurfaceVariant.withValues(alpha: 0.8),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                )),
          ),
        ),
      ),
    );
  }

  Widget _presetTile(
      BuildContext context, ThemeController tc, AppThemePreset preset) {
    final cs = Theme.of(context).colorScheme;
    final selected = tc.preset.value == preset;
    return GestureDetector(
      onTap: () => tc.setPreset(preset),
      child: AnimatedScale(
        scale: selected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.1)
              : cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.5),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final c in preset.swatches) ...[
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  if (c != preset.swatches.last) const SizedBox(width: 4),
                ],
              ],
            ),
            const SizedBox(height: 7),
            Text(preset.label,
                style: TextStyle(
                  fontSize: 12,
                  color: selected
                      ? cs.primary
                      : cs.onSurfaceVariant.withValues(alpha: 0.8),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _pickBackgroundImage(ThemeController tc) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;
      final docs = await getApplicationDocumentsDirectory();
      final bgDir = Directory('${docs.path}/gongmo_data');
      if (!await bgDir.exists()) {
        await bgDir.create(recursive: true);
      }
      final dest = File('${bgDir.path}/background.jpg');
      if (await dest.exists()) {
        await dest.delete();
      }
      await picked.saveTo(dest.path);
      tc.setBackgroundImage(dest.path);
      Get.snackbar('已设置', '自定义背景已更新');
    } catch (e) {
      Get.snackbar('设置失败', '选择背景图片失败，请重试');
    }
  }

  void _showGithubConfig(SettingsController ctrl) {
    final urlCtrl = TextEditingController(text: ctrl.githubRepoUrl.value);
    final tokenCtrl = TextEditingController(text: ctrl.githubToken.value);

    Get.dialog(
      AlertDialog(
        title: const Text('GitHub 配置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: '仓库 URL',
                hintText: 'https://github.com/user/repo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tokenCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Personal Access Token',
                hintText: 'ghp_xxxx',
                helperText: '需要 Contents 读写权限',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              TextButton(
                onPressed: () {
                  ctrl.disconnectGithub();
                  Get.back();
                },
                child: const Text('断开连接', style: TextStyle(color: Colors.red)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final url = urlCtrl.text.trim();
                  final token = tokenCtrl.text.trim();
                  if (url.isNotEmpty &&
                      GithubSyncService.normalizeRepo(url) == null) {
                    Get.snackbar('格式错误',
                        '仓库地址不正确，示例：https://github.com/user/repo');
                    return;
                  }
                  if (token.isNotEmpty &&
                      !GithubSyncService.isValidTokenFormat(token)) {
                    Get.snackbar(
                        'Token 格式可疑',
                        'Token 通常以 ghp_ 或 github_pat_ 开头，'
                        '请检查是否复制完整或混入了空格');
                    return;
                  }
                  await ctrl.setGithubRepo(url);
                  await ctrl.setGithubToken(token);
                  Get.back();
                  if (url.isEmpty || token.isEmpty) {
                    Get.snackbar('已保存', 'GitHub 配置已更新');
                    return;
                  }
                  Get.snackbar('正在检测', '正在验证仓库与 Token...',
                      duration: const Duration(seconds: 2));
                  try {
                    await GithubSyncService.instance.testConnection();
                    Get.snackbar('连接成功', '仓库与 Token 验证通过，可以同步了');
                  } on GithubSyncException catch (e) {
                    Get.snackbar('连接失败', e.message);
                  } catch (_) {
                    Get.snackbar('连接失败', '网络异常，请检查网络');
                  }
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 自动记账卡片：开关 + 通知使用权限入口（从系统设置返回后自动刷新状态）
class _AutoAccountingCard extends StatefulWidget {
  final SettingsController ctrl;

  const _AutoAccountingCard({required this.ctrl});

  @override
  State<_AutoAccountingCard> createState() => _AutoAccountingCardState();
}

class _AutoAccountingCardState extends State<_AutoAccountingCard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.ctrl.refreshAutoAccountingStatus();
  }

  @override
  void didUpdateWidget(covariant _AutoAccountingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.ctrl.refreshAutoAccountingStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统设置授权返回后刷新状态
    if (state == AppLifecycleState.resumed) {
      widget.ctrl.refreshAutoAccountingStatus();
      if (widget.ctrl.autoAccounting.value &&
          widget.ctrl.autoAccountingHasPermission.value) {
        AutoBookkeepingService.instance.start();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          Obx(() => SwitchListTile(
                secondary: _PulseIcon(
                  icon: Icons.notifications_active_outlined,
                  color: cs.primary,
                  active: widget.ctrl.autoAccountingRunning.value,
                ),
                title: const Text('自动记账',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  widget.ctrl.autoAccounting.value
                      ? (widget.ctrl.autoAccountingRunning.value
                          ? '监听服务运行中，已自动记录收支'
                          : '监听服务启动中...')
                      : '读取支付宝/招商银行通知，自动入账',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
                value: widget.ctrl.autoAccounting.value,
                onChanged: (v) async {
                  await widget.ctrl.setAutoAccounting(v);
                  // 开启时顺带提示常驻设置（非强制，且已设置过则不再打扰）
                  if (v && mounted) {
                    final ignoring = await KeepAliveService.instance
                        .isIgnoringBatteryOptimizations();
                    if (mounted && !ignoring) showKeepAliveGuide();
                  }
                },
              )),
          Obx(() => AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !widget.ctrl.autoAccounting.value
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        children: [
                          const Divider(height: 1),
                          for (final app
                              in AutoBookkeepingService.supportedApps)
                            SwitchListTile(
                              secondary: Icon(
                                app.key == 'alipay'
                                    ? Icons.currency_yuan_rounded
                                    : app.key == 'wechat'
                                        ? Icons.wechat
                                        : Icons.account_balance_rounded,
                                color: cs.primary.withValues(alpha: 0.8),
                                size: 20,
                              ),
                              dense: true,
                              title: Text(app.name,
                                  style: const TextStyle(fontSize: 13.5)),
                              subtitle: Text(
                                switch (app.key) {
                                  'cmb' => '入账/支出短信通知自动入账',
                                  'wechat' => '微信支付/收款通知自动入账',
                                  _ => '支出/收入通知自动入账',
                                },
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.8)),
                              ),
                              value: widget.ctrl.autoApps[app.key] ?? true,
                              onChanged: (v) =>
                                  widget.ctrl.setAutoApp(app.key, v),
                            ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: Icon(
                                Icons.assignment_return_outlined,
                                color: cs.primary,
                                size: 20),
                            dense: true,
                            title: const Text('自动记录退款',
                                style: TextStyle(fontSize: 13.5)),
                            subtitle: Text('识别到退款通知时自动记为收入',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.8))),
                            value: widget.ctrl.autoRefund.value,
                            onChanged: (v) =>
                                widget.ctrl.setAutoRefund(v),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            dense: true,
                            leading: Icon(Icons.battery_saver_rounded,
                                color: cs.primary, size: 20),
                            title: const Text('后台常驻设置',
                                style: TextStyle(fontSize: 13.5)),
                            subtitle: Text('忽略电池优化 / 自启动，避免后台被清理',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.8))),
                            trailing:
                                const Icon(Icons.chevron_right, size: 18),
                            onTap: showKeepAliveGuide,
                          ),
                        ],
                      ),
              )),
          const Divider(height: 1),
          Obx(() => ListTile(
                dense: true,
                leading: Icon(
                  widget.ctrl.autoAccountingHasPermission.value
                      ? Icons.verified_user_outlined
                      : Icons.key_rounded,
                  size: 20,
                  color: widget.ctrl.autoAccountingHasPermission.value
                      ? Colors.green.shade600
                      : Colors.orange.shade700,
                ),
                title: const Text('通知使用权限',
                    style: TextStyle(fontSize: 13.5)),
                subtitle: Text(
                  widget.ctrl.autoAccountingHasPermission.value
                      ? '已授权'
                      : '未授权，点击前往系统设置开启',
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () async {
                  await NotificationsListener.openPermissionSettings();
                  if (context.mounted) {
                    widget.ctrl.refreshAutoAccountingStatus();
                  }
                },
              )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Text(
              '开启后监听支付宝等通知（如"你有一笔200.00元的支出"）并自动入账，'
              '自动记账的条目会在账目列表中标记为"自动"。'
              '部分手机需在系统设置中允许本应用后台运行。',
              style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
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

/// 图标在 active 时轻微脉冲缩放
class _PulseIcon extends StatefulWidget {
  const _PulseIcon({
    required this.icon,
    required this.color,
    required this.active,
  });

  final IconData icon;
  final Color color;
  final bool active;

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.active && _ctrl.isAnimating) {
      _ctrl.animateBack(0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.18).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Icon(widget.icon, color: widget.color),
    );
  }
}

/// 每日记账提醒：开关 + 提醒时间
class _ReminderCard extends StatefulWidget {
  const _ReminderCard();

  @override
  State<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<_ReminderCard> {
  final ReminderService _reminder = ReminderService.instance;
  bool _enabled = false;
  int _hour = ReminderService.defaultHour;
  int _minute = ReminderService.defaultMinute;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _enabled = _reminder.enabled;
    _hour = _reminder.hour;
    _minute = _reminder.minute;
  }

  String get _timeText =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  Future<void> _toggle(bool v) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (v) {
        final ok = await _reminder.requestPermission();
        if (!ok) {
          Get.snackbar('无法开启', '请在系统设置中允许「工墨」发送通知');
          return;
        }
      }
      await _reminder.setEnabled(v);
      if (mounted) setState(() => _enabled = v);
      Get.snackbar(v ? '已开启记账提醒' : '已关闭记账提醒',
          v ? '每天 $_timeText 提醒你记账' : '将不再发送记账提醒');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (t == null) return;
    await _reminder.setTime(t.hour, t.minute);
    if (!mounted) return;
    setState(() {
      _hour = t.hour;
      _minute = t.minute;
    });
    if (_enabled) {
      Get.snackbar('提醒时间已更新', '每天 $_timeText 提醒你记账');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(Icons.alarm_rounded, color: cs.primary),
            title: const Text('每日记账提醒'),
            subtitle: Text(
              _enabled ? '每天 $_timeText 提醒你记账' : '开启后每天定时提醒记账',
              style: TextStyle(
                  fontSize: 11.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
            ),
            value: _enabled,
            onChanged: _toggle,
          ),
          if (_enabled) ...[
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.schedule_rounded, color: cs.primary),
              title: const Text('提醒时间'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_timeText,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ])),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              onTap: _pickTime,
            ),
          ],
        ],
      ),
    );
  }
}

/// 后台常驻设置指引（非强制）
void showKeepAliveGuide() {
  Get.dialog(const _KeepAliveDialog());
}

class _KeepAliveDialog extends StatefulWidget {
  const _KeepAliveDialog();

  @override
  State<_KeepAliveDialog> createState() => _KeepAliveDialogState();
}

class _KeepAliveDialogState extends State<_KeepAliveDialog> {
  bool _ignoring = false;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final v = await KeepAliveService.instance
        .isIgnoringBatteryOptimizations();
    if (mounted) {
      setState(() {
        _ignoring = v;
        _loaded = true;
      });
    }
  }

  Future<void> _request() async {
    if (_busy) return;
    setState(() => _busy = true);
    await KeepAliveService.instance.requestIgnoreBatteryOptimizations();
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.battery_charging_full_rounded, color: cs.primary),
          const SizedBox(width: 8),
          const Text('保持后台运行'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '自动记账依赖通知监听。部分手机在后台会清理应用，'
              '下面的设置为可选，建议开启以免漏记：',
              style: TextStyle(
                  fontSize: 12.5, height: 1.5, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _ignoring
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  size: 16,
                  color: _ignoring
                      ? Colors.green.shade600
                      : Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  _loaded
                      ? (_ignoring ? '电池优化：已忽略（推荐）' : '电池优化：未设置')
                      : '电池优化：检测中...',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _step(cs, '1', '点击「忽略电池优化」，在系统弹窗中选择「允许」'),
            _step(cs, '2', '进入「应用设置」，将省电策略设为「无限制」'),
            _step(cs, '3', '在「自启动管理」中允许「工墨」自启动'),
            _step(cs, '4', '在最近任务界面锁定工墨，避免被一键清理'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('知道了')),
        if (!_ignoring)
          TextButton(
            onPressed: _busy ? null : _request,
            child: const Text('忽略电池优化'),
          ),
        ElevatedButton(
          onPressed: () =>
              KeepAliveService.instance.openSystemAppSettings(),
          child: const Text('打开应用设置'),
        ),
      ],
    );
  }

  Widget _step(ColorScheme cs, String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(n,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cs.primary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12, height: 1.4, color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}