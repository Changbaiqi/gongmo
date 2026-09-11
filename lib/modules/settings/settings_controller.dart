// ============================================================
// settings_controller.dart（设置模块 · 业务控制器）
// 职责：管理设置页的响应式状态——GitHub 连接配置、自动记账开关与分应用
//       开关、通知权限/服务运行状态，以及“清空云端备份”危险操作。
// 关联：依赖 GithubSyncService（读写配置、云端清理）与
//       AutoBookkeepingService（权限检查、启停通知监听）；由 SettingsPage 使用。
// ============================================================
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:get/get.dart';
import '../../data/services/auto_bookkeeping_service.dart';
import '../../data/services/github_sync_service.dart';

/// 设置页控制器：集中托管设置页所有可变状态与用户操作。
///
/// 生命周期：随设置页首次 `Get.put` 创建后常驻内存，页面销毁不会回收；
/// 所有状态用 `.obs` 暴露给界面 `Obx` 订阅。GitHub 地址/Token 的最终落盘
/// 由 GithubSyncService 负责，本类只维护内存值并转发调用。
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

  /// 是否自动记录退款
  final autoRefund = true.obs;

  /// 分应用开关（alipay/cmb...），未设置的默认开启
  final autoApps = RxMap<String, bool>();

  @override
  void onInit() {
    super.onInit();
    loadGithubConfig();
    loadAutoAccounting();
  }

  /// 从持久化存储恢复 GitHub 配置（进入设置页时调用一次）
  Future<void> loadGithubConfig() async {
    githubRepoUrl.value = await _sync.getRepoUrl();
    githubToken.value = await _sync.getToken();
    isGithubConnected.value = githubRepoUrl.value.isNotEmpty;
  }

  /// 加载自动记账状态：开关、退款开关、分应用开关，并顺带刷新运行状态
  Future<void> loadAutoAccounting() async {
    autoAccounting.value = _sync.readConfig('auto_accounting') == true;
    autoRefund.value = _sync.readConfig('auto_refund') != false;
    final raw = _sync.readConfig('auto_apps');
    for (final app in AutoBookkeepingService.supportedApps) {
      autoApps[app.key] =
          raw is Map ? raw[app.key] != false : true; // 未配置的应用默认开启
    }
    await refreshAutoAccountingStatus();
  }

  /// 设置是否自动记录退款
  Future<void> setAutoRefund(bool v) async {
    autoRefund.value = v;
    await _sync.writeConfig('auto_refund', v);
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

  /// 开关自动记账：开启前检查通知使用权限，未授权则跳转系统设置；
  /// 授权成功后启动通知监听服务，失败用 Snackbar 提示。
  /// 副作用：写盘 auto_accounting、切换前台服务、可能打开系统设置页。
  Future<void> setAutoAccounting(bool v) async {
    autoAccounting.value = v;
    _sync.writeConfig('auto_accounting', v);
    if (v) {
      final hasPerm = await _autoBookkeeping.hasPermission();
      autoAccountingHasPermission.value = hasPerm;
      if (!hasPerm) {
        // 先引导用户去系统里授予“通知使用权”，回到前台后由卡片自行续启服务
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

  /// 保存仓库地址：先做规范化（补全 https、提取 owner/repo），
  /// 非空但格式非法时用空串覆盖，界面据此显示“未绑定”。
  Future<void> setGithubRepo(String url) async {
    final normalized = GithubSyncService.normalizeRepo(url) ?? '';
    githubRepoUrl.value = normalized;
    isGithubConnected.value = normalized.isNotEmpty;
    await _sync.saveRepoUrl(normalized);
  }

  /// 保存 Personal Access Token（自动去除首尾空格，写入安全存储）
  Future<void> setGithubToken(String token) async {
    githubToken.value = token.trim();
    await _sync.saveToken(token.trim());
  }

  /// 断开 GitHub：清空内存配置并删除本地保存的地址与 Token
  Future<void> disconnectGithub() async {
    githubRepoUrl.value = '';
    githubToken.value = '';
    isGithubConnected.value = false;
    await _sync.clearConfig();
  }

  /// 清空云端全部备份文件（危险操作，需调用方先做输入确认）
  Future<void> clearCloudBackups() async {
    if (isClearingCloud.value) return; // 防止连点导致重复删除
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
