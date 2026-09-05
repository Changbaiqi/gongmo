import 'package:get/get.dart';
import '../../data/services/github_sync_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/models/category.dart';

class SettingsController extends GetxController {
  final StorageService _storage = StorageService();
  final GithubSyncService _sync = GithubSyncService.instance;

  final githubRepoUrl = ''.obs;
  final githubToken = ''.obs;
  final isGithubConnected = false.obs;

  List<Category> get categories => _storage.categories;

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

  void addCategory(Category category) {
    _storage.addCategory(category);
    update();
  }

  void removeCategory(String id) {
    _storage.removeCategory(id);
    update();
  }
}
