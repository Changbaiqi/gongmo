import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/services/github_sync_service.dart';

class SettingsController extends GetxController {
  final GithubSyncService _sync = GithubSyncService.instance;

  final githubRepoUrl = ''.obs;
  final githubToken = ''.obs;
  final isGithubConnected = false.obs;
  final isClearingCloud = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadGithubConfig();
  }

  /// 从持久化存储恢复 GitHub 配置
  Future<void> loadGithubConfig() async {
    githubRepoUrl.value = await _sync.getRepoUrl();
    githubToken.value = await _sync.getToken();
    isGithubConnected.value = githubRepoUrl.value.isNotEmpty;
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
