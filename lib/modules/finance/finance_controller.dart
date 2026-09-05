import 'package:flutter/material.dart';
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

  /// 分类列表版本号：新增分类后自增，驱动分类网格刷新
  final categoriesRevision = 0.obs;

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

  void saveEntry(FinanceEntry entry) {
    _financeRepo.save(entry);
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

  /// 新增自定义分类，返回新分类 id
  String addCategory({
    required String name,
    required String icon,
    required Color color,
    required FinanceType type,
  }) {
    final cat = Category(
      id: 'cus_${_uuid.v4().substring(0, 8)}',
      name: name,
      type: type,
      icon: icon,
      color:
          '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}'.toUpperCase(),
      sortOrder: _storage.categories.where((c) => c.type == type).length + 1,
    );
    _storage.addCategory(cat);
    categoriesRevision.value++;
    return cat.id;
  }

  /// 修改分类（名称/图标/颜色）
  void updateCategory({
    required String id,
    required String name,
    required String icon,
    required Color color,
  }) {
    for (final cat in _storage.categories) {
      if (cat.id == id) {
        cat.name = name;
        cat.icon = icon;
        cat.color =
            '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}'.toUpperCase();
        _storage.updateCategory(cat);
        categoriesRevision.value++;
        return;
      }
    }
  }

  /// 删除分类
  void deleteCategory(String id) {
    _storage.removeCategory(id);
    categoriesRevision.value++;
  }

  /// 调整同一收支类型内分类的先后顺序
  void reorderCategory(FinanceType type, int oldIndex, int newIndex) {
    final sameType =
        _storage.categories.where((c) => c.type == type).toList();
    if (oldIndex < 0 || oldIndex >= sameType.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex > sameType.length - 1) return;
    final moved = sameType.removeAt(oldIndex);
    sameType.insert(newIndex, moved);
    for (var i = 0; i < sameType.length; i++) {
      sameType[i].sortOrder = i + 1;
    }
    final others =
        _storage.categories.where((c) => c.type != type).toList();
    for (var i = 0; i < others.length; i++) {
      others[i].sortOrder = i + 1;
    }
    _storage.categories
      ..clear()
      ..addAll(sameType)
      ..addAll(others);
    _storage.saveCategories();
    categoriesRevision.value++;
  }

  String getCategoryIcon(String categoryId) {
    try {
      return categories.firstWhere((c) => c.id == categoryId).icon;
    } catch (_) {
      return 'help_outline';
    }
  }
}
