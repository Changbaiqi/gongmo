// ============================================================
// finance/finance_controller.dart（Finance 模块 · 业务逻辑）
// 职责：账目 CRUD、分类 CRUD 与排序，维护账目列表与月度收支的响应式状态。
// 关联：通过 FinanceRepository / StorageService 读写数据（落盘即触发自动云同步），
//       数据变化后主动刷新 DashboardController(tag:'dashboard')；
//       被 HomePage、FinancePage、DashboardPage 使用（无 tag 的全局单例）。
// ============================================================
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/services/storage_service.dart';
import '../../data/models/finance_entry.dart';
import '../../data/models/category.dart';
import '../dashboard/dashboard_controller.dart';

/// 记账控制器：账目与分类的唯一业务入口。
///
/// 生命周期：不加 tag，属于全局单例——首次 `Get.put(FinanceController())`
/// （HomePage.initState / FinancePage / DashboardPage）时创建，之后各处 `Get.find` 复用。
/// 所有写操作都经仓储层落盘；分类增删改通过 [categoriesRevision] 通知 UI 刷新。
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

  /// 重新从仓储加载账目并按时间倒序排列，同时重算本月收支。
  void loadEntries() {
    entries.value = _financeRepo.getAll();
    entries.sort((a, b) => b.date.compareTo(a.date));
    monthIncome.value = _financeRepo.getMonthIncome();
    monthExpense.value = _financeRepo.getMonthExpense();
  }

  /// 新增一笔账目（自动生成 uuid，未传日期用当前时间），
  /// 写盘后刷新自身汇总，并尝试通知 Dashboard 重算。
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

  /// 删除账目（仓储层写删除墓碑，供多设备合并时防止记录被恢复），随后刷新汇总。
  void deleteEntry(String id) {
    _financeRepo.delete(id);
    loadEntries();
    try {
      Get.find<DashboardController>(tag: 'dashboard').refreshData();
    } catch (_) {}
  }

  /// 保存已修改的账目对象；调用方需先更新字段并设置 `updatedAt`（供合并判新）。
  void saveEntry(FinanceEntry entry) {
    _financeRepo.save(entry);
    loadEntries();
    try {
      Get.find<DashboardController>(tag: 'dashboard').refreshData();
    } catch (_) {}
  }

  /// 取分类名；分类已被删除时降级为“未分类”。
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
    // 自定义分类 id 以 cus_ 开头；颜色统一存 #RRGGBB 大写，sortOrder 追加到该类型末尾
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

  /// 删除分类（写墓碑）；历史账目仍保留其 categoryId，展示时会显示为“已删分类”。
  void deleteCategory(String id) {
    _storage.removeCategory(id);
    categoriesRevision.value++;
  }

  /// 调整同一收支类型内分类的先后顺序（只在该类型分组内拖动）。
  void reorderCategory(FinanceType type, int oldIndex, int newIndex) {
    final sameType =
        _storage.categories.where((c) => c.type == type).toList();
    if (oldIndex < 0 || oldIndex >= sameType.length) return;
    // ReorderableListView 的 newIndex 是“移除前”的插入位置：
    // 向下拖时目标位置已包含被拖动项，因此要减 1 才是移除后的真实下标
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex > sameType.length - 1) return;
    final moved = sameType.removeAt(oldIndex);
    sameType.insert(newIndex, moved);
    for (var i = 0; i < sameType.length; i++) {
      sameType[i].sortOrder = i + 1;
    }
    // 另一收支类型的分组整体排在后面，并各自重编 sortOrder
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
