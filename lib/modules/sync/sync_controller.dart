import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/account.dart';
import '../../data/models/category.dart';
import '../../data/models/finance_entry.dart';
import '../../data/models/timer_tag.dart';
import '../../data/models/work_entry.dart';
import '../../data/services/github_sync_service.dart';
import '../../data/services/storage_service.dart';
import '../dashboard/dashboard_controller.dart';
import '../finance/finance_controller.dart';
import '../settings/settings_controller.dart';
import '../work/work_controller.dart';

class SyncController extends GetxController {
  final StorageService _storage = StorageService();
  final GithubSyncService _sync = GithubSyncService.instance;

  final isSyncing = false.obs;
  final isRestoring = false.obs;
  final lastSyncTime = Rxn<DateTime>();
  final totalEntries = 0.obs;
  final workCount = 0.obs;
  final financeCount = 0.obs;

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
    Get.put(SettingsController());
    refreshStats();
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
      refreshStats();
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
      );
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
