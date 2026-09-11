// ============================================================
// category_manager.dart（finance/widgets · 分类共用 UI）
// 职责：记账分类的选择网格与「分类管理」（新增/编辑/删除/排序）弹窗，
//       由「记一笔」「修改账目」与「截屏记账确认弹窗」共用，
//       保证各入口的分类与记账功能实时同步。
// 关联：FinanceController（分类增删改与排序）、IconUtils、Category。
// ============================================================
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/icon_utils.dart';
import '../../../data/models/category.dart';
import '../../../data/models/finance_entry.dart';
import '../finance_controller.dart';

/// 可选内置图标（与 [IconUtils.category] 的 key 对应）
const List<String> categoryIconKeys = [
  'restaurant', 'directions_car', 'print', 'computer', 'work', 'chat',
  'attach_money', 'more_horiz', 'school', 'favorite', 'sports_esports',
  'savings', 'home', 'flight', 'local_cafe', 'music_note',
];

/// 预设分类色板（与“随机”选项配合使用）
const List<Color> categoryColorPalette = [
  Color(0xFFE53935), Color(0xFFFB8C00), Color(0xFFFDD835), Color(0xFF43A047),
  Color(0xFF00ACC1), Color(0xFF1E88E5), Color(0xFF8E24AA), Color(0xFFEC407A),
  Color(0xFF6D4C41), Color(0xFF757575),
];

/// 分类选择网格：4 列图标网格 + 首位「分类管理」入口。
///
/// - 数据来自 [FinanceController]，与记账表单完全一致；
/// - [getSelectedId] / [onSelected] 用于读写当前选中分类，
///   删除当前选中分类时管理弹窗会回调空字符串，由调用方回落到默认分类。
class CategoryGridPicker extends StatelessWidget {
  final FinanceController fc;
  final ColorScheme cs;
  final FinanceType type;
  final String? Function() getSelectedId;
  final ValueChanged<String> onSelected;

  const CategoryGridPicker({
    super.key,
    required this.fc,
    required this.cs,
    required this.type,
    required this.getSelectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      fc.categoriesRevision.value; // 新增/删除/修改分类后刷新
      final selectedId = getSelectedId();
      final cats = fc.categories.where((c) => c.type == type).toList();
      return GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.95,
        children: [
          _manageTile(),
          ...cats.map((cat) => _categoryTile(cat, selectedId)),
        ],
      );
    });
  }

  /// “分类管理”网格入口（置于分类网格最前）
  Widget _manageTile() {
    return GestureDetector(
      onTap: () => showCategoryManagerDialog(
        fc: fc,
        type: type,
        cs: cs,
        getSelectedId: getSelectedId,
        onSelected: onSelected,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cs.outlineVariant, width: 1.4),
            ),
            child:
                Icon(Icons.tune_rounded, size: 20, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 5),
          Text('分类管理',
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _categoryTile(Category cat, String? selectedId) {
    final selected = selectedId == cat.id;
    final color = IconUtils.hex(cat.color, cs.primary);
    return GestureDetector(
      onTap: () => onSelected(cat.id),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              IconUtils.category(cat.icon),
              size: 20,
              color: selected ? Colors.white : color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            cat.name,
            style: TextStyle(
              fontSize: 11.5,
              color: selected ? color : cs.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// 分类管理弹窗：新增 / 修改 / 删除 / 拖动排序
void showCategoryManagerDialog({
  required FinanceController fc,
  required FinanceType type,
  required ColorScheme cs,
  required String? Function() getSelectedId,
  required ValueChanged<String> onSelected,
}) {
  final isExpense = type == FinanceType.expense;
  Get.dialog(
    AlertDialog(
      title: Text(isExpense ? '支出分类管理' : '收入分类管理'),
      content: SizedBox(
        width: double.maxFinite,
        child: Obx(() {
          fc.categoriesRevision.value;
          final cats = fc.categories.where((c) => c.type == type).toList();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('长按拖动调整先后顺序，点击条目可修改',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8))),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: cats.isEmpty
                    ? Center(
                        child: Text('暂无分类，点击下方按钮添加',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: 0.6))),
                      )
                    : ReorderableListView.builder(
                        shrinkWrap: true,
                        // 关闭整行长按拖动，改用行首拖拽图标精确控制
                        buildDefaultDragHandles: false,
                        itemCount: cats.length,
                        itemExtent: 52,
                        onReorder: (oldIndex, newIndex) =>
                            fc.reorderCategory(type, oldIndex, newIndex),
                        itemBuilder: (context, index) {
                          final cat = cats[index];
                          final color = IconUtils.hex(cat.color, cs.primary);
                          // 至少保留一个分类：仅剩 1 个时禁用删除
                          final canDelete = cats.length > 1;
                          return ListTile(
                            key: ValueKey(cat.id),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onTap: () => showEditCategoryDialog(
                              fc: fc,
                              cat: cat,
                              cs: cs,
                            ),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Icon(Icons.drag_indicator_rounded,
                                      size: 18,
                                      color: cs.onSurfaceVariant
                                          .withValues(alpha: 0.6)),
                                ),
                                const SizedBox(width: 2),
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.13),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    IconUtils.category(cat.icon),
                                    size: 17,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                            title: Text(cat.name,
                                style: const TextStyle(fontSize: 14)),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: canDelete
                                    ? cs.onSurfaceVariant
                                        .withValues(alpha: 0.7)
                                    : cs.outlineVariant,
                              ),
                              onPressed: canDelete
                                  ? () {
                                      HapticFeedback.selectionClick();
                                      // 删除的正是当前选中分类时先清空，避免表单指向已删分类
                                      if (getSelectedId() == cat.id) {
                                        onSelected('');
                                      }
                                      fc.deleteCategory(cat.id);
                                    }
                                  : () =>
                                      Get.snackbar('提示', '至少保留一个分类'),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showAddCategoryDialog(
                    fc: fc,
                    type: type,
                    cs: cs,
                    onSelected: onSelected,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('添加分类'),
                ),
              ),
            ],
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('完成'),
        ),
      ],
    ),
  );
}

/// 编辑分类：名称 / 图标 / 颜色
void showEditCategoryDialog({
  required FinanceController fc,
  required Category cat,
  required ColorScheme cs,
}) {
  final nameCtrl = TextEditingController(text: cat.name);
  final selectedIcon = cat.icon.obs;
  // 颜色为 null 表示“随机”，保存时才生成随机色
  final selectedColor = Rxn<Color>(IconUtils.hex(cat.color));

  Get.dialog(
    AlertDialog(
      title: const Text('编辑分类'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '分类名称',
                ),
              ),
              const SizedBox(height: 12),
              labeledDivider('分类图标', cs),
              Obx(() => GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1,
                    children: categoryIconKeys.map((key) {
                      final selected = selectedIcon.value == key;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          selectedIcon.value = key;
                        },
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: selected
                                  ? cs.primary
                                  : cs.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? cs.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              IconUtils.category(key),
                              size: 20,
                              color:
                                  selected ? Colors.white : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )),
              const SizedBox(height: 10),
              labeledDivider('背景颜色', cs),
              Obx(() => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      randomColorOption(cs, selectedColor),
                      for (final c in categoryColorPalette)
                        categoryColorOption(cs, selectedColor, c),
                    ],
                  )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              Get.snackbar('提示', '请输入分类名称');
              return;
            }
            final color = selectedColor.value ?? randomPleasantColor();
            fc.updateCategory(
              id: cat.id,
              name: name,
              icon: selectedIcon.value,
              color: color,
            );
            Get.back();
            Get.snackbar('已修改', '分类「$name」已更新');
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

/// 新增分类：名称 + 图标 + 背景颜色（未选择颜色时随机）
void showAddCategoryDialog({
  required FinanceController fc,
  required FinanceType type,
  required ColorScheme cs,
  required ValueChanged<String> onSelected,
}) {
  final isExpense = type == FinanceType.expense;
  final nameCtrl = TextEditingController();
  final selectedIcon = 'restaurant'.obs;
  final selectedColor = Rxn<Color>(); // null = 随机

  Get.dialog(
    AlertDialog(
      title: Text(isExpense ? '新增支出分类' : '新增收入分类'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '分类名称',
                ),
              ),
              const SizedBox(height: 12),
              labeledDivider('分类图标', cs),
              Obx(() => GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1,
                    children: categoryIconKeys.map((key) {
                      final selected = selectedIcon.value == key;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          selectedIcon.value = key;
                        },
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: selected
                                  ? cs.primary
                                  : cs.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? cs.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              IconUtils.category(key),
                              size: 20,
                              color:
                                  selected ? Colors.white : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )),
              const SizedBox(height: 10),
              labeledDivider('背景颜色', cs),
              Obx(() => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      randomColorOption(cs, selectedColor),
                      for (final c in categoryColorPalette)
                        categoryColorOption(cs, selectedColor, c),
                    ],
                  )),
              const SizedBox(height: 4),
              Center(
                child: Text('未选择颜色时将随机分配',
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              Get.snackbar('提示', '请输入分类名称');
              return;
            }
            final color = selectedColor.value ?? randomPleasantColor();
            final id = fc.addCategory(
              name: name,
              icon: selectedIcon.value,
              color: color,
              type: type,
            );
            onSelected(id);
            Get.back();
            Get.snackbar('已添加', '分类「$name」已创建');
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

/// “标签 + 分割线”小标题（分类弹窗共用）
Widget labeledDivider(String text, ColorScheme cs) {
  return Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant.withValues(alpha: 0.8))),
      ),
      const Expanded(child: Divider()),
    ],
  );
}

/// “随机”色块：selected 为 null 时高亮，表示保存时随机分配颜色
Widget randomColorOption(ColorScheme cs, Rxn<Color> selected) {
  final isRandom = selected.value == null;
  return GestureDetector(
    onTap: () => selected.value = null,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(
            color: isRandom ? cs.primary : cs.outlineVariant, width: 2),
      ),
      child: Icon(Icons.shuffle_rounded, size: 16, color: cs.onSurfaceVariant),
    ),
  );
}

Widget categoryColorOption(ColorScheme cs, Rxn<Color> selected, Color color) {
  final isSelected = selected.value == color;
  return GestureDetector(
    onTap: () => selected.value = color,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
            color: isSelected ? cs.primary : Colors.transparent, width: 2.5),
      ),
    ),
  );
}

/// 随机生成柔和的颜色：固定饱和度/亮度、只随机色相，避免刺眼。
Color randomPleasantColor() {
  final rnd = Random();
  return HSLColor.fromAHSL(1, rnd.nextDouble() * 360, 0.55, 0.55).toColor();
}
