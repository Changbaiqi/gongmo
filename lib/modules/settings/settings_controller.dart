import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:get/get.dart';
import '../../data/services/auto_bookkeeping_service.dart';
import '../../data/services/github_sync_service.dart';

class SettingsController extends GetxController {
  final GithubSyncService _sync = GithubSyncService.instance;
  final AutoBookkeepingService _autoBookkeeping =
      AutoBookkeepingService.instance;

  final githubRepoUrl = ''.obs;
  final githubToken = ''.obs;
  final isGithubConnected = false.obs;
  final isClearingCloud = false.obs;

  /// 自动记账
  final autoAccounting = false.obs;
  final autoAccountingHasPermission = false.obs;
  final autoAccountingRunning = false.obs;

  /// 分应用开关（alipay/cmb...），未设置的默认开启
  final autoApps = RxMap<String, bool>();

  @override
  void onInit() {
    super.onInit();
    loadGithubConfig();
    loadAutoAccounting();
  }

  /// 从持久化存储恢复 GitHub 配置
  Future<void> loadGithubConfig() async {
    githubRepoUrl.value = await _sync.getRepoUrl();
    githubToken.value = await _sync.getToken();
    isGithubConnected.value = githubRepoUrl.value.isNotEmpty;
  }

  /// 加载自动记账状态
  Future<void> loadAutoAccounting() async {
    autoAccounting.value = _sync.readConfig('auto_accounting') == true;
    final raw = _sync.readConfig('auto_apps');
    for (final app in AutoBookkeepingService.supportedApps) {
      autoApps[app.key] =
          raw is Map ? raw[app.key] != false : true; // 未配置的应用默认开启
    }
    await refreshAutoAccountingStatus();
  }

  /// 设置单个应用的自动记账开关
  Future<void> setAutoApp(String key, bool v) async {
    autoApps[key] = v;
    final saved = <String, dynamic>{
      for (final e in autoApps.entries) e.key: e.value,
    };
    await _sync.writeConfig('auto_apps', saved);
  }

  /// 刷新权限/服务运行状态
  Future<void> refreshAutoAccountingStatus() async {
    try {
      autoAccountingHasPermission.value =
          await _autoBookkeeping.hasPermission();
      autoAccountingRunning.value =
          autoAccounting.value && await _autoBookkeeping.isRunning();
    } catch (_) {
      autoAccountingHasPermission.value = false;
      autoAccountingRunning.value = false;
    }
  }

  /// 开关自动记账
  Future<void> setAutoAccounting(bool v) async {
    autoAccounting.value = v;
    _sync.writeConfig('auto_accounting', v);
    if (v) {
      final hasPerm = await _autoBookkeeping.hasPermission();
      autoAccountingHasPermission.value = hasPerm;
      if (!hasPerm) {
        await NotificationsListener.openPermissionSettings();
        return;
      }
      try {
        await _autoBookkeeping.start();
        autoAccountingRunning.value = true;
        Get.snackbar('自动记账已开启', '监听到支付宝收支通知后会自动入账');
      } catch (_) {
        Get.snackbar('开启失败', '监听服务启动失败，请重试');
      }
    } else {
      await _autoBookkeeping.stop();
      autoAccountingRunning.value = false;
    }
  }

  Future<void> setGithubRepo(String url) async {
    final normalized = GithubSyncService.normalizeRepo(url) ?? '';
    githubRepoUrl.value = normalized;
    isGithubConnected.value = normalized.isNotEmpty;
    await _sync.saveRepoUrl(normalized);
  }

  Future<void> setGithubToken(String token) async {
    githubToken.value = token.trim();
    await _sync.saveToken(token.trim());
  }

  Future<void> disconnectGithub() async {
    githubRepoUrl.value = '';
    githubToken.value = '';
    isGithubConnected.value = false;
    await _sync.clearConfig();
  }

  /// 清空云端全部备份文件（危险操作，需调用方先做输入确认）
  Future<void> clearCloudBackups() async {
    if (isClearingCloud.value) return;
    if (githubRepoUrl.value.isEmpty || githubToken.value.isEmpty) {
      Get.snackbar('尚未绑定', '请先绑定仓库并填写 Token');
      return;
    }
    isClearingCloud.value = true;
    try {
      final count = await _sync.clearRemoteBackups();
      Get.snackbar('已清空', '共删除 $count 个云端备份文件');
    } on GithubSyncException catch (e) {
      Get.snackbar('清空失败', e.message);
    } catch (e) {
      Get.snackbar('清空失败', '发生未知错误，请重试');
    } finally {
      isClearingCloud.value = false;
    }
  }
}
