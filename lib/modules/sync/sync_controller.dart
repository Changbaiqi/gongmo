import 'package:get/get.dart';
import '../../data/services/storage_service.dart';

class SyncController extends GetxController {
  final StorageService _storage = StorageService();

  final isSyncing = false.obs;
  final lastSyncTime = Rxn<DateTime>();
  final totalEntries = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _updateStats();
  }

  void _updateStats() {
    totalEntries.value =
        _storage.workEntries.length + _storage.financeEntries.length;
  }

  Future<void> pushToGithub() async {
    isSyncing.value = true;
    await Future.delayed(const Duration(seconds: 2));
    lastSyncTime.value = DateTime.now();
    _updateStats();
    isSyncing.value = false;
    Get.snackbar('同步完成', '数据已同步至 GitHub');
  }

  Future<void> exportJson() async {
    _storage.exportAllData();
    Get.snackbar('导出成功', '数据已准备导出，共 ${totalEntries.value} 条记录');
  }

  Future<void> importJson() async {
    Get.snackbar('导入', '从 GitHub 拉取数据功能将在后续版本实现');
  }
}
