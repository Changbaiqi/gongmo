import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/account.dart';
import '../../data/models/category.dart';
import '../../data/models/finance_entry.dart';
import '../../data/models/invoice_profile.dart';
import '../../data/models/timer_tag.dart';
import '../../data/models/work_entry.dart';
import '../../data/services/auto_bookkeeping_service.dart';
import '../../data/services/github_sync_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/sync_merge.dart';
import '../dashboard/dashboard_controller.dart';
import '../finance/finance_controller.dart';
import '../settings/settings_controller.dart';
import '../work/work_controller.dart';

class SyncController extends GetxController with WidgetsBindingObserver {
  final StorageService _storage = StorageService();
  final GithubSyncService _sync = GithubSyncService.instance;

  final isSyncing = false.obs;
  final isRestoring = false.obs;
  final lastSyncTime = Rxn<DateTime>();
  final totalEntries = 0.obs;
  final workCount = 0.obs;
  final financeCount = 0.obs;

  /// 自动同步开关（持久化到 config.json）
  final autoSync = false.obs;
  Timer? _autoSyncTimer;
  int _lastSyncedHash = 0;

  /// 仓库是否已绑定（含 Token）
  bool get isConnected {
    final sc = Get.find<SettingsController>();
    return sc.githubRepoUrl.value.isNotEmpty && sc.githubToken.value.isNotEmpty;
  }

  String get repoDisplay {
    final sc = Get.find<SettingsController>();
    return sc.githubRepoUrl.value;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    Get.put(SettingsController());
    // 数据落盘 → 防抖后自动备份
    _storage.onDataChanged = _onDataChanged;
    autoSync.value = _storage.getConfig('auto_sync') == true;
    refreshStats();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSyncTimer?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回到前台：处理自动记账队列（后台引擎写入的待入账条目）
    if (state == AppLifecycleState.resumed) {
      AutoBookkeepingService.instance.processQueue().then((_) {
        _notifyUi();
        refreshStats();
      });
    }
  }

  void setAutoSync(bool v) {
    autoSync.value = v;
    _storage.setConfig('auto_sync', v);
    if (v) _lastSyncedHash = 0; // 开启后允许下一次数据变动立即同步
  }

  void _onDataChanged() {
    _notifyUi(); // 后台自动入账等数据变化时刷新前台界面
    if (!autoSync.value) return;
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer(const Duration(seconds: 6), _runAutoSync);
  }

  void _notifyUi() {
    try {
      Get.find<FinanceController>().loadEntries();
    } catch (_) {}
    try {
      final dc = Get.find<DashboardController>(tag: 'dashboard');
      dc.reloadBudgets();
      dc.refreshData();
    } catch (_) {}
    try {
      Get.find<WorkController>().loadEntries();
    } catch (_) {}
  }

  Future<void> _runAutoSync() async {
    if (!autoSync.value || isSyncing.value || isRestoring.value) return;
    if (!isConnected) return;
    final hash = _storage.syncSignature.hashCode;
    if (hash == _lastSyncedHash) return; // 数据无变化
    isSyncing.value = true;
    try {
      await _sync.pushBackup();
      final now = DateTime.now();
      await _sync.setLastSync(now);
      lastSyncTime.value = now;
      _lastSyncedHash = _storage.syncSignature.hashCode;
      refreshStats();
      _notifyUi(); // 合并可能引入了云端的新数据，刷新界面
    } catch (_) {
      // 自动同步失败时静默，等待下次数据变动重试
    } finally {
      isSyncing.value = false;
    }
  }

  void refreshStats() {
    workCount.value = _storage.workEntries.length;
    financeCount.value = _storage.financeEntries.length;
    totalEntries.value = workCount.value + financeCount.value;
    lastSyncTime.value = _sync.getLastSync();
  }

  /// 备份到 GitHub
  Future<void> pushToGithub() async {
    if (isSyncing.value) return;
    if (!isConnected) {
      _promptConfig();
      return;
    }
    isSyncing.value = true;
    try {
      await _sync.pushBackup();
      final now = DateTime.now();
      await _sync.setLastSync(now);
      lastSyncTime.value = now;
      _lastSyncedHash = _storage.syncSignature.hashCode;
      refreshStats();
      _notifyUi(); // 合并可能引入了云端的新数据，刷新界面
      Get.snackbar('同步完成', '已备份 ${totalEntries.value} 条记录到 GitHub');
    } on GithubSyncException catch (e) {
      Get.snackbar('同步失败', e.message);
    } catch (e) {
      Get.snackbar('同步失败', '发生未知错误，请重试');
    } finally {
      isSyncing.value = false;
    }
  }

  /// 从 GitHub 恢复（覆盖本地）
  Future<void> restoreFromGithub() async {
    if (isRestoring.value) return;
    if (!isConnected) {
      _promptConfig();
      return;
    }
    isRestoring.value = true;
    try {
      final data = await _sync.pullBackup();
      await _storage.restoreAllData(
        workEntries: _parseList(data['workEntries'], WorkEntry.fromJson),
        financeEntries:
            _parseList(data['financeEntries'], FinanceEntry.fromJson),
        categories: _parseList(data['categories'], Category.fromJson),
        accounts: _parseList(data['accounts'], Account.fromJson),
        timerTags: _parseList(data['timerTags'], TimerTag.fromJson),
        invoiceProfiles:
            _parseList(data['invoiceProfiles'], InvoiceProfile.fromJson),
        tombstones: SyncMerge.parseIntMap(data['tombstones']),
      );
      // 恢复预算配置
      try {
        final dc = Get.find<DashboardController>();
        final bMap = <String, double>{};
        if (data['budgets'] is Map) {
          (data['budgets'] as Map).forEach((k, v) {
            final d = double.tryParse('$v');
            if (d != null && d > 0) bMap['$k'] = d;
          });
        }
        dc.restoreBudgets(
            bMap, double.tryParse('${data['totalBudget'] ?? 0}') ?? 0);
      } catch (_) {}
      _refreshAllControllers();
      refreshStats();
      Get.snackbar('恢复完成', '已从云端恢复 ${totalEntries.value} 条记录');
    } on GithubSyncException catch (e) {
      Get.snackbar('恢复失败', e.message);
    } catch (e) {
      Get.snackbar('恢复失败', '备份数据解析失败，请确认备份文件完整');
    } finally {
      isRestoring.value = false;
    }
  }

  /// 导出备份 JSON 到本地 Documents 目录
  Future<void> exportJson() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final ts = DateTime.now()
          .toIso8601String()
          .substring(0, 19)
          .replaceAll(':', '-');
      final file = File('${docs.path}/gongmo_backup_$ts.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'app': 'gongmo',
          'version': 1,
          'exportedAt': DateTime.now().toIso8601String(),
          'data': _storage.exportAllData(),
        }),
      );
      Get.snackbar('导出成功', '已保存到 ${file.path}');
    } catch (e) {
      Get.snackbar('导出失败', '写入文件失败，请重试');
    }
  }

  List<T> _parseList<T>(
      dynamic raw, T Function(Map<String, dynamic>) fromJson) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  void _refreshAllControllers() {
    try {
      Get.find<WorkController>().loadEntries();
    } catch (_) {}
    try {
      Get.find<FinanceController>().loadEntries();
    } catch (_) {}
    try {
      Get.find<DashboardController>(tag: 'dashboard').refreshData();
    } catch (_) {}
  }

  void _promptConfig() {
    Get.snackbar(
      '尚未绑定 GitHub',
      '请先在设置中填写仓库地址和 Token',
      duration: const Duration(seconds: 3),
      mainButton: TextButton(
        onPressed: () => Get.toNamed('/settings'),
        child: const Text('去设置'),
      ),
    );
  }
}
