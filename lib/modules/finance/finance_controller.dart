import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/services/storage_service.dart';
import '../../data/models/finance_entry.dart';
import '../../data/models/category.dart';
import '../dashboard/dashboard_controller.dart';

class FinanceController extends GetxController {
  final FinanceRepository _financeRepo = FinanceRepository();
  final StorageService _storage = StorageService();
  final _uuid = const Uuid();

  final entries = <FinanceEntry>[].obs;
  final monthIncome = 0.0.obs;
  final monthExpense = 0.0.obs;
  final isLoading = false.obs;

  List<Category> get categories => _storage.categories;

  @override
  void onInit() {
    super.onInit();
    loadEntries();
  }

  void loadEntries() {
    entries.value = _financeRepo.getAll();
    entries.sort((a, b) => b.date.compareTo(a.date));
    monthIncome.value = _financeRepo.getMonthIncome();
    monthExpense.value = _financeRepo.getMonthExpense();
  }

  void addEntry({
    required FinanceType type,
    required double amount,
    required String categoryId,
    String description = '',
    DateTime? date,
  }) {
    final entry = FinanceEntry(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      categoryId: categoryId,
      description: description,
      date: date ?? DateTime.now(),
    );
    _financeRepo.save(entry);
    loadEntries();
    try {
      Get.find<DashboardController>(tag: 'dashboard').refreshData();
    } catch (_) {}
  }

  void deleteEntry(String id) {
    _financeRepo.delete(id);
    loadEntries();
    try {
      Get.find<DashboardController>(tag: 'dashboard').refreshData();
    } catch (_) {}
  }

  String getCategoryName(String categoryId) {
    try {
      return categories.firstWhere((c) => c.id == categoryId).name;
    } catch (_) {
      return '未分类';
    }
  }

  String getCategoryIcon(String categoryId) {
    try {
      return categories.firstWhere((c) => c.id == categoryId).icon;
    } catch (_) {
      return 'help_outline';
    }
  }
}
