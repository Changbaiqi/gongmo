import 'package:get/get.dart';
import '../../data/services/storage_service.dart';
import '../../data/models/category.dart';

class SettingsController extends GetxController {
  final StorageService _storage = StorageService();

  final githubRepoUrl = ''.obs;
  final githubToken = ''.obs;
  final isGithubConnected = false.obs;

  List<Category> get categories => _storage.categories;

  void setGithubRepo(String url) {
    githubRepoUrl.value = url;
    if (url.isNotEmpty) {
      isGithubConnected.value = true;
    }
  }

  void setGithubToken(String token) {
    githubToken.value = token;
  }

  void disconnectGithub() {
    githubRepoUrl.value = '';
    githubToken.value = '';
    isGithubConnected.value = false;
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
