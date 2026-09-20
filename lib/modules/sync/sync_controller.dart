// ============================================================
// sync_controller.dart（同步模块 · 业务控制器）
// 职责：云端同步总调度——监听数据落盘做 6 秒防抖自动备份、手动备份/恢复、
//       导出本地 JSON，并在数据变化或恢复后刷新各业务控制器。
// 关联：依赖 StorageService（数据与变更通知）、GithubSyncService（远端读写）、
//       SyncMerge（拉取后的合并纯函数），并反向驱动 Work/Finance/Dashboard
//       三个控制器刷新；被 SyncPage 使用，随 App 常驻。
// ============================================================
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/account.dart';
import '../../data/models/category.dart';
import '../../data/models/finance_entry.dart';
import '../../data/models/invoice_profile.dart';
import '../../data/models/timer_tag.dart';
import '../../data/models/work_entry.dart';
import '../../data/services/auto_bookkeeping_service.dart';
import '../../data/services/backup_package_service.dart';
import '../../data/services/github_sync_service.dart';
import '../../data/services/local_backup_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/sync_merge.dart';
import '../dashboard/dashboard_controller.dart';
import '../finance/finance_controller.dart';
import '../settings/settings_controller.dart';
import '../work/work_controller.dart';

/// 同步控制器：应用内所有 GitHub 备份/恢复流程的唯一入口。
///
/// 生命周期：在 SyncPage 首次 `Get.put` 时创建，之后常驻（含后台自动同步），
/// 通过 [WidgetsBindingObserver] 感知前后台切换。自动同步通过
/// `StorageService.onDataChanged` 回调触发，写入防抖定时器做延迟合并。
class SyncController extends GetxController with WidgetsBindingObserver {
  final StorageService _storage = StorageService();
  final GithubSyncService _sync = GithubSyncService.instance;

  final isSyncing = false.obs;
  final isRestoring = false.obs;

  /// 顶部同步图标的动画状态：备份/恢复都会驱动，
  /// 且保证至少展示 [_minSpin] 时间，避免瞬间完成看不到动画
  final showSyncing = false.obs;
  static const _minSpin = Duration(milliseconds: 1600);
  DateTime? _spinStartedAt;

  void _beginSpin() {
    _spinStartedAt = DateTime.now();
    showSyncing.value = true;
  }

  Future<void> _endSpin() async {
    final started = _spinStartedAt;
    if (started != null) {
      final elapsed = DateTime.now().difference(started);
      if (elapsed < _minSpin) {
        await Future.delayed(_minSpin - elapsed);
      }
    }
    _spinStartedAt = null;
    showSyncing.value = false;
  }

  final lastSyncTime = Rxn<DateTime>();
  final totalEntries = 0.obs;
  final workCount = 0.obs;
  final financeCount = 0.obs;

  /// 自动同步开关（持久化到 config.json）
  final autoSync = false.obs;
  Timer? _autoSyncTimer;
  Timer? _localBackupTimer;

  /// 最近一次成功同步时的数据指纹（[StorageService.syncSignature] 的 hashCode），
  /// 用于跳过“数据没变”的重复上传，值为 0 表示尚未同步过。
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
    _loadLocalBackupState();
    // 本地自动备份默认开启：还没有任何备份时，启动先存一份
    if (LocalBackupService.autoEnabled &&
        LocalBackupService.lastTime == null) {
      LocalBackupService.backupNow().then((_) => _loadLocalBackupState());
    }
    refreshStats();
  }

  @override
  void onClose() {
    // 控制器常驻，一般不会触发；仍成对移除监听避免泄漏
    WidgetsBinding.instance.removeObserver(this);
    _autoSyncTimer?.cancel();
    _localBackupTimer?.cancel();
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

  /// 切换自动同步开关。
  /// 开启时把指纹清零，保证接下来的第一次数据变动必定触发一次备份。
  void setAutoSync(bool v) {
    autoSync.value = v;
    _storage.setConfig('auto_sync', v);
    if (v) _lastSyncedHash = 0; // 开启后允许下一次数据变动立即同步
  }

  // ---------- 本地备份（不依赖 GitHub，不随应用数据清理消失） ----------

  final localBackupAuto = false.obs;
  final localBackupLast = Rxn<DateTime>();
  final localBackupPath = RxnString();

  /// 是否正在本地备份（按钮据此禁用，避免连点产生多份）
  final localBackupBusy = false.obs;

  void _loadLocalBackupState() {
    localBackupAuto.value = LocalBackupService.autoEnabled;
    localBackupLast.value = LocalBackupService.lastTime;
    localBackupPath.value = LocalBackupService.lastPath;
  }

  /// 开关自动本地备份：开启时立刻先备份一份
  Future<void> setLocalBackupAuto(bool v) async {
    localBackupAuto.value = v;
    await LocalBackupService.setAuto(v);
    if (!v) return;
    final path = await LocalBackupService.backupNow();
    _loadLocalBackupState();
    Get.snackbar(
      path != null ? '已开启本地自动备份' : '本地备份失败',
      path != null
          ? '已保存到 $path'
          : (LocalBackupService.lastError ?? '请检查存储空间后重试'),
    );
  }

  /// 手动备份到本地公共目录
  Future<void> backupToLocal() async {
    if (localBackupBusy.value) return;
    localBackupBusy.value = true;
    try {
      final path = await LocalBackupService.backupNow();
      _loadLocalBackupState();
      final reused = LocalBackupService.lastReused;
      Get.snackbar(
        path != null
            ? (reused ? '已更新本地备份' : '已备份到本地')
            : '本地备份失败',
        path != null
            ? '已保存到 $path'
            : (LocalBackupService.lastError ?? '请检查存储空间后重试'),
      );
    } finally {
      localBackupBusy.value = false;
    }
  }

  /// 用系统文件管理器打开本地备份目录
  Future<void> openLocalBackupFolder() async {
    final ok = await LocalBackupService.openFolder();
    if (!ok) {
      Get.snackbar('无法打开', '路径：${LocalBackupService.visibleFolder}');
    }
  }

  void _onDataChanged() {
    _notifyUi(); // 后台自动入账等数据变化时刷新前台界面
    // 本地备份与 GitHub 无关：没绑定仓库也能自动镜像一份到公共目录
    if (LocalBackupService.autoEnabled) {
      _localBackupTimer?.cancel();
      _localBackupTimer = Timer(const Duration(seconds: 12), () async {
        await LocalBackupService.autoBackupIfDue();
        _loadLocalBackupState();
      });
    }
    if (!autoSync.value) return;
    // 6 秒防抖：连续写入（如批量导入、合并）只触发最后一次同步；
    // 每次新变更都重置计时，避免同步过程中数据还在变导致上传的是旧快照
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer(const Duration(seconds: 6), _runAutoSync);
  }

  /// 数据变化后主动刷新当前在内存中的业务列表（控制器不存在时忽略）。
  /// 覆盖前台记账、后台自动入账、云端恢复三种数据来源。
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

  /// 防抖到期后执行一次自动备份。
  ///
  /// 三重短路：开关已关 / 正在同步或恢复 / 未绑定仓库 / 数据指纹与上次一致，
  /// 任一满足都直接返回。失败时静默，等待下一次数据变化自然重试。
  Future<void> _runAutoSync() async {
    if (!autoSync.value || isSyncing.value || isRestoring.value) return;
    if (!isConnected) return;
    final hash = _storage.syncSignature.hashCode;
    if (hash == _lastSyncedHash) return; // 数据无变化，跳过上传省流量
    isSyncing.value = true;
    _beginSpin();
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
      await _endSpin();
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
    if (isSyncing.value || isRestoring.value) return;
    if (!isConnected) {
      _promptConfig();
      return;
    }
    isSyncing.value = true;
    _beginSpin();
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
      await _endSpin();
    }
  }

  /// 从 GitHub 恢复（覆盖本地）。
  ///
  /// 流程：`pullBackup` 拉取全部分片并做并集合并 → `restoreAllData` 整体覆盖
  /// 本地数据（含删除墓碑）→ 补恢复预算配置 → 刷新各控制器与统计。
  /// 恢复后本地数据会触发 onDataChanged，可能再次自动备份，属预期行为。
  Future<void> restoreFromGithub() async {
    if (isRestoring.value) return;
    if (!isConnected) {
      _promptConfig();
      return;
    }
    isRestoring.value = true;
    _beginSpin();
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
      await _endSpin();
    }
  }

  /// 导出备份到本地：把整合后的数据按原始分片文件压缩成 `.gongmo` 包，
  /// 并保存到手机公共目录「下载 / 工墨导出」。
  ///
  /// 包内保留 work_entries_2026.json 等原始文件，导入时可原样还原。
  Future<void> exportPackage() async {
    String? source;
    try {
      // 先在应用内生成包，再复制到公共下载目录（用户可见、不被清理）
      source = await BackupPackageService.instance.exportPackage();
      final saved = await LocalBackupService.saveToPublicDownloads(
        source,
        relativeDir: LocalBackupService.exportFolder,
        mime: 'application/gzip',
      );
      if (saved == null) {
        Get.snackbar('导出失败', '写入下载目录失败，请检查存储空间后重试');
        return;
      }
      Get.snackbar('导出成功', '已保存到 $saved');
    } catch (e) {
      Get.snackbar('导出失败', '写入文件失败，请重试');
    } finally {
      // 清理应用内的临时包
      if (source != null) {
        try {
          final tmp = File(source);
          if (await tmp.exists()) await tmp.delete();
        } catch (_) {}
      }
    }
  }

  /// 从本地备份包导入。
  ///
  /// 支持 `.gongmo` 压缩包（本页导出，内含原始分片文件）与旧版 `.json` 导出。
  /// 先弹确认框让用户选择「合并导入」或「覆盖导入」，再执行；合并规则与
  /// 云端同步一致（同 id 取较新，删除墓碑优先），保证多设备数据不会被旧备份整包冲掉。
  Future<void> importFromFile() async {
    if (isSyncing.value || isRestoring.value) return;
    Map<String, dynamic> raw;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gongmo', 'json'],
        withData: false,
      );
      final path = picked?.files.single.path;
      if (path == null) return; // 用户取消
      final data = await BackupPackageService.instance.readBackup(File(path));
      if (data == null) {
        Get.snackbar('导入失败', '文件内容不是有效的备份');
        return;
      }
      raw = data;
    } on FormatException {
      Get.snackbar('导入失败', '备份文件格式不正确');
      return;
    } catch (e) {
      Get.snackbar('导入失败', '读取文件失败，请重试');
      return;
    }
    await importFromData(raw);
  }

  /// 用已解析的备份数据执行导入（供文件选择与本地备份恢复共用）
  Future<void> importFromData(Map<String, dynamic> raw) async {
    if (isSyncing.value || isRestoring.value) return;
    const keys = [
      'workEntries',
      'financeEntries',
      'categories',
      'accounts',
      'timerTags',
      'invoiceProfiles',
    ];
    if (!keys.any((k) => raw[k] is List)) {
      Get.snackbar('导入失败', '备份里没有可导入的数据');
      return;
    }

    final mode = await _confirmImport(raw, keys);
    if (mode == null) return;
    isRestoring.value = true;
    _beginSpin();
    try {
      final bool changed;
      if (mode == 'replace') {
        await _storage.restoreAllData(
          workEntries: _parseList(raw['workEntries'], WorkEntry.fromJson),
          financeEntries:
              _parseList(raw['financeEntries'], FinanceEntry.fromJson),
          categories: _parseList(raw['categories'], Category.fromJson),
          accounts: _parseList(raw['accounts'], Account.fromJson),
          timerTags: _parseList(raw['timerTags'], TimerTag.fromJson),
          invoiceProfiles:
              _parseList(raw['invoiceProfiles'], InvoiceProfile.fromJson),
          tombstones: SyncMerge.parseIntMap(raw['tombstones']),
        );
        // 备份里带了预算配置（如云端分片导出）就一并恢复
        try {
          final dc = Get.find<DashboardController>();
          final bMap = <String, double>{};
          if (raw['budgets'] is Map) {
            (raw['budgets'] as Map).forEach((k, v) {
              final d = double.tryParse('$v');
              if (d != null && d > 0) bMap['$k'] = d;
            });
          }
          final total = double.tryParse('${raw['totalBudget'] ?? 0}') ?? 0;
          if (bMap.isNotEmpty || total > 0) dc.restoreBudgets(bMap, total);
        } catch (_) {}
        changed = true;
      } else {
        changed = await _storage.mergeRemoteData(raw);
      }
      _lastSyncedHash = 0; // 数据已变化，允许下一次自动备份重新上传
      _refreshAllControllers();
      refreshStats();
      Get.snackbar(
        changed ? '导入完成' : '没有新数据',
        changed
            ? (mode == 'replace' ? '已用备份覆盖本地数据' : '已合并备份中的新记录')
            : '本地数据已经是最新的，无需导入',
      );
    } catch (e) {
      Get.snackbar('导入失败', '备份数据解析失败，请确认文件完整');
    } finally {
      isRestoring.value = false;
      await _endSpin();
    }
  }

  /// 导入确认框：展示备份内容统计并选择导入方式
  Future<String?> _confirmImport(
      Map<String, dynamic> raw, List<String> keys) {
    int count(String k) => raw[k] is List ? (raw[k] as List).length : 0;
    final work = count('workEntries');
    final finance = count('financeEntries');
    final others =
        count('categories') + count('accounts') + count('timerTags') +
            count('invoiceProfiles');
    return Get.dialog<String>(
      AlertDialog(
        title: const Text('导入备份'),
        content: Text(
          '备份包含：\n'
          '· 计时记录 $work 条\n'
          '· 账目记录 $finance 条\n'
          '· 分类/账户/标签等 $others 条\n\n'
          '「合并导入」同一条保留较新的，删除过的记录不会恢复（推荐）；\n'
          '「覆盖导入」会用备份内容替换本地数据，请谨慎操作。',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: 'replace'),
            child: const Text('覆盖导入'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: 'merge'),
            child: const Text('合并导入'),
          ),
        ],
      ),
    );
  }

  /// 把云端返回的 dynamic 列表安全解析为模型列表；字段缺失或类型不符时跳过。
  List<T> _parseList<T>(
      dynamic raw, T Function(Map<String, dynamic>) fromJson) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 恢复完成后让各业务控制器重新从 StorageService 读数据（tag 不匹配则忽略）
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

  /// 未绑定仓库时的统一提示，附带“去设置”快捷按钮
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
