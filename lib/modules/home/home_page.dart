import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/icon_utils.dart';
import '../../core/widgets/count_up_text.dart';
import '../../core/widgets/swipe_action_card.dart';
import '../../data/models/category.dart';
import '../../data/models/finance_entry.dart';
import '../../data/models/work_entry.dart';
import '../dashboard/dashboard_controller.dart';
import '../work/work_controller.dart';
import '../work/work_page.dart';
import '../finance/finance_controller.dart';
import '../stats/stats_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final DashboardController _dc =
      Get.put(DashboardController(), tag: 'dashboard');
  final PageController _pageCtrl = PageController();
  int _financeSubIndex = 0;
  int _financePlayKey = 0; // 切回记账页时自增，触发金额滚动动效

  @override
  void initState() {
    super.initState();
    Get.put(FinanceController());
    Get.put(WorkController());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (index == 0) _financePlayKey++; // 切回记账页触发金额滚动动效
    setState(() => _currentIndex = index);
  }

  void _onNavTapped(int index) {
    setState(() => _currentIndex = index);
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? '工墨记账' : '工墨时钟'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_outlined),
            onPressed: () => Get.toNamed('/sync'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Get.toNamed('/settings'),
          ),
        ],
      ),
      body: PageView(
        controller: _pageCtrl,
        onPageChanged: _onPageChanged,
        children: [
          _buildFinanceTab(),
          const WorkPage(),
        ],
      ),
      floatingActionButton: _currentIndex == 0 && _financeSubIndex == 0
          ? FloatingActionButton(
              onPressed: _showQuickFinance,
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.account_balance_wallet_rounded,
                  label: '记账',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.timer_outlined,
                  label: '时钟',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isActive = _currentIndex == index;
    final cs = Theme.of(context).colorScheme;
    final color = isActive ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: () => _onNavTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? cs.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceTab() {
    return Column(
      children: [
        const SizedBox(height: 8),
        _buildFinanceSubToggle(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey(_financeSubIndex),
              child: _financeSubIndex == 0
                  ? _buildBookkeeping()
                  : const StatsView(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinanceSubToggle() {
    final cs = Theme.of(context).colorScheme;
    Widget segment(String label, int index) {
      final active = _financeSubIndex == index;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_financeSubIndex == index) return;
          HapticFeedback.selectionClick();
          setState(() {
            _financeSubIndex = index;
            if (index == 0) _financePlayKey++;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: ShapeDecoration(
            color:
                active ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  color: active
                      ? cs.primary
                      : cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                )),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Expanded(child: segment('记账', 0)),
            Expanded(child: segment('统计', 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildBookkeeping() {
    final fc = Get.find<FinanceController>();

    return RefreshIndicator(
      onRefresh: () async => _dc.refreshData(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 12),
          _buildActiveTimerBanner(),
          const SizedBox(height: 4),
          _buildFinanceHeader(),
          const SizedBox(height: 8),
          _buildFinanceListContent(fc),
        ],
      ),
    );
  }

  Widget _buildFinanceHeader() {
    return Text('全部账目',
        style: Theme.of(context).textTheme.titleSmall);
  }

  Widget _buildBalanceCard() {
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      final income = _dc.monthIncome.value;
      final expense = _dc.monthExpense.value;
      final balance = income - expense;
      final onPrimary = cs.onPrimary;
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary,
              Color.lerp(cs.primary, onPrimary, 0.22)!,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    color: onPrimary.withValues(alpha: 0.8), size: 16),
                const SizedBox(width: 6),
                Text('本月结余',
                    style: TextStyle(
                        color: onPrimary.withValues(alpha: 0.85),
                        fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            CountUpText(
              value: balance,
              restartKey: _financePlayKey,
              formatter: (v) => '¥${v.toStringAsFixed(2)}',
              style: TextStyle(
                color: onPrimary,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _balanceSubItem(
                    cs: cs,
                    icon: Icons.arrow_outward_rounded,
                    label: '本月收入',
                    value: income,
                    restartKey: _financePlayKey,
                  ),
                ),
                Container(
                  width: 1,
                  height: 26,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: onPrimary.withValues(alpha: 0.25),
                ),
                Expanded(
                  child: _balanceSubItem(
                    cs: cs,
                    icon: Icons.south_west_rounded,
                    label: '本月支出',
                    value: expense,
                    restartKey: _financePlayKey,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _balanceSubItem({
    required ColorScheme cs,
    required IconData icon,
    required String label,
    required double value,
    required int restartKey,
  }) {
    final onPrimary = cs.onPrimary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: onPrimary.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: onPrimary),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: onPrimary.withValues(alpha: 0.7),
                    fontSize: 11)),
            CountUpText(
              value: value,
              restartKey: restartKey,
              formatter: (v) => '¥${v.toStringAsFixed(2)}',
              style: TextStyle(
                  color: onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveTimerBanner() {
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      if (!_dc.hasActiveTimer.value) return const SizedBox.shrink();
      final entry = _dc.activeTimerEntry.value;
      if (entry == null) return const SizedBox.shrink();
      // 依赖每秒跳动的 todayWorkDuration，让横幅实时刷新
      _dc.todayWorkDuration.value;
      final elapsed = DateHelper.formatDurationShort(entry.liveElapsed);
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.tertiaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_rounded, color: cs.tertiary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('计时中 · ${entry.projectName}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(elapsed,
                      style: TextStyle(
                          color: cs.tertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _confirmStopActiveTimer(entry),
              style: TextButton.styleFrom(
                foregroundColor: cs.error,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('停止', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    });
  }

  /// 横幅"停止"按钮：二次确认后结束打卡或计时
  void _confirmStopActiveTimer(WorkEntry entry) {
    final isClock = entry.mode == 'clock';
    Get.dialog(
      AlertDialog(
        title: Text(isClock ? '结束打卡' : '结束计时'),
        content: Text(isClock
            ? '确定结束本次打卡吗？结束后将记录工时。'
            : '确定结束「${entry.projectName}」的本次计时吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              final wc = Get.find<WorkController>();
              if (isClock) {
                wc.clockOut();
              } else {
                wc.stopTimer();
              }
              _dc.refreshData();
            },
            child: const Text('确定结束', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceListContent(FinanceController fc) {
    return Obx(() {
      final entries = fc.entries;

      if (entries.isEmpty) {
        return _buildEmptyState(
          icon: Icons.receipt_long_outlined,
          message: '还没有账目，点击 + 记一笔吧',
        );
      }

      final groups = <String, List<FinanceEntry>>{};
      final order = <String>[];
      for (final e in entries) {
        final key = DateHelper.formatDate(e.date);
        if (!groups.containsKey(key)) {
          groups[key] = [];
          order.add(key);
        }
        groups[key]!.add(e);
      }

      return Column(
        children: [
          for (final key in order) ...[
            _buildDayHeader(groups[key]!),
            ...groups[key]!.map((entry) => _buildFinanceItemCard(fc, entry)),
          ],
        ],
      );
    });
  }

  Widget _buildDayHeader(List<FinanceEntry> entries) {
    final income = entries
        .where((e) => e.type == FinanceType.income)
        .fold(0.0, (s, e) => s + e.amount);
    final expense = entries
        .where((e) => e.type == FinanceType.expense)
        .fold(0.0, (s, e) => s + e.amount);
    final date = entries.first.date;
    final label = DateHelper.isSameDay(date, DateTime.now())
        ? '今天'
        : DateHelper.isSameDay(
                date, DateTime.now().subtract(const Duration(days: 1)))
            ? '昨天'
            : '${date.month}月${date.day}日';

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          if (income > 0) ...[
            const SizedBox(width: 10),
            Text('收 ¥${income.toStringAsFixed(2)}',
                style: TextStyle(
                    color: Colors.green.shade600, fontSize: 11)),
          ],
          if (expense > 0) ...[
            const SizedBox(width: 8),
            Text('支 ¥${expense.toStringAsFixed(2)}',
                style:
                    TextStyle(color: Colors.red.shade600, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      {required IconData icon, required String message}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(icon, size: 52, color: cs.outlineVariant),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFinanceItemCard(FinanceController fc, FinanceEntry entry) {
    final cs = Theme.of(context).colorScheme;
    final isIncome = entry.type == FinanceType.income;
    Category? cat;
    for (final c in fc.categories) {
      if (c.id == entry.categoryId) {
        cat = c;
        break;
      }
    }
    final catColor = IconUtils.hex(cat?.color,
        isIncome ? Colors.green.shade600 : Colors.orange.shade600);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SwipeActionCard(
        key: ValueKey(entry.id),
        onEdit: () => _showEditFinanceSheet(fc, entry),
        onDelete: () => _confirmDeleteFinance(fc, entry),
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            dense: true,
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconUtils.category(cat?.icon ?? ''),
                size: 18,
                color: catColor,
              ),
            ),
            title: Text(
              entry.description.isNotEmpty
                  ? entry.description
                  : fc.getCategoryName(entry.categoryId),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${fc.getCategoryName(entry.categoryId)} · ${DateHelper.formatDisplay(entry.date)}',
              style: TextStyle(
                  fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
            ),
            trailing: Text(
              '${isIncome ? '+' : '-'}¥${entry.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                color: isIncome ? Colors.green.shade600 : Colors.red.shade600,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteFinance(FinanceController fc, FinanceEntry entry) {
    Get.dialog(AlertDialog(
      title: const Text('删除账目'),
      content: Text(
          '确定删除「${entry.description.isNotEmpty ? entry.description : fc.getCategoryName(entry.categoryId)}」吗？'),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        TextButton(
          onPressed: () {
            fc.deleteEntry(entry.id);
            _dc.refreshData();
            if (mounted) setState(() {});
            Get.back();
          },
          child: const Text('确认删除', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }

  void _showEditFinanceSheet(FinanceController fc, FinanceEntry entry) {
    final cs = Theme.of(context).colorScheme;
    final amountCtrl = TextEditingController(text: entry.amount.toString());
    final noteCtrl = TextEditingController(text: entry.description);
    final isExpense = (entry.type == FinanceType.expense).obs;
    final selectedCatId = entry.categoryId.obs;

    Get.bottomSheet(
      Container(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('修改账目',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()]),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => Row(
                      children: [
                        Expanded(
                          child: _typePill(
                            label: '支出',
                            icon: Icons.south_west_rounded,
                            selected: isExpense.value,
                            color: Colors.red.shade600,
                            onTap: () {
                              isExpense.value = true;
                              _fixCategorySelection(
                                  fc, isExpense, selectedCatId);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _typePill(
                            label: '收入',
                            icon: Icons.north_east_rounded,
                            selected: !isExpense.value,
                            color: Colors.green.shade600,
                            onTap: () {
                              isExpense.value = false;
                              _fixCategorySelection(
                                  fc, isExpense, selectedCatId);
                            },
                          ),
                        ),
                      ],
                    )),
                const SizedBox(height: 14),
                _categoryGrid(
                  fc: fc,
                  cs: cs,
                  isExpense: isExpense,
                  selectedCatId: selectedCatId,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: '备注',
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final amount = double.tryParse(amountCtrl.text);
                      if (amount == null || amount <= 0) {
                        Get.snackbar('提示', '请输入有效金额');
                        return;
                      }
                      entry.amount = amount;
                      entry.type = isExpense.value
                          ? FinanceType.expense
                          : FinanceType.income;
                      entry.categoryId = selectedCatId.value;
                      entry.description = noteCtrl.text;
                      entry.updatedAt = DateTime.now();
                      fc.saveEntry(entry);
                      _dc.refreshData();
                      Get.back();
                    },
                    child: const Text('保存修改'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  /// 切换收支类型后，若当前选中分类不属于该类型则回落到第一个分类
  void _fixCategorySelection(
      FinanceController fc, RxBool isExpense, RxString selectedCatId) {
    final type = isExpense.value ? FinanceType.expense : FinanceType.income;
    final active = fc.categories.where((c) => c.type == type).toList();
    if (active.isEmpty) return;
    if (!active.any((c) => c.id == selectedCatId.value)) {
      selectedCatId.value = active.first.id;
    }
  }

  /// 分类图标网格（记一笔 / 修改账目 共用），尾部带“新增分类”入口
  Widget _categoryGrid({
    required FinanceController fc,
    required ColorScheme cs,
    required RxBool isExpense,
    required RxString selectedCatId,
  }) {
    return Obx(() {
      fc.categoriesRevision.value; // 新增/删除/修改分类后刷新
      final type = isExpense.value ? FinanceType.expense : FinanceType.income;
      final activeCats =
          fc.categories.where((c) => c.type == type).toList();
      if (selectedCatId.value.isEmpty && activeCats.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (selectedCatId.value.isEmpty) {
            selectedCatId.value = activeCats.first.id;
          }
        });
      }
      return GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.95,
        children: [
          _categoryManageTile(fc, cs, isExpense.value, selectedCatId),
          ...activeCats.map((cat) {
            final selected = selectedCatId.value == cat.id;
            final color = IconUtils.hex(cat.color, cs.primary);
            return GestureDetector(
              onTap: () => selectedCatId.value = cat.id,
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
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }),
        ],
      );
    });
  }

  /// “分类管理”网格入口（置于最前）
  Widget _categoryManageTile(FinanceController fc, ColorScheme cs,
      bool isExpense, RxString selectedCatId) {
    return GestureDetector(
      onTap: () => _showCategoryManagerDialog(
          fc: fc, isExpense: isExpense, selectedCatId: selectedCatId),
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
              style:
                  TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  /// 分类管理弹窗：新增 / 修改 / 删除
  void _showCategoryManagerDialog({
    required FinanceController fc,
    required bool isExpense,
    required RxString selectedCatId,
  }) {
    final cs = Theme.of(context).colorScheme;
    Get.dialog(
      AlertDialog(
        title: Text(isExpense ? '支出分类管理' : '收入分类管理'),
        content: SizedBox(
          width: double.maxFinite,
          child: Obx(() {
            fc.categoriesRevision.value;
            final type =
                isExpense ? FinanceType.expense : FinanceType.income;
            final cats =
                fc.categories.where((c) => c.type == type).toList();
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
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.6))),
                        )
                      : ReorderableListView.builder(
                          shrinkWrap: true,
                          buildDefaultDragHandles: false,
                          itemCount: cats.length,
                          itemExtent: 52,
                          onReorder: (oldIndex, newIndex) =>
                              fc.reorderCategory(type, oldIndex, newIndex),
                          itemBuilder: (context, index) {
                            final cat = cats[index];
                            final color =
                                IconUtils.hex(cat.color, cs.primary);
                            final canDelete = cats.length > 1;
                            return ListTile(
                              key: ValueKey(cat.id),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onTap: () => _showEditCategoryDialog(
                                  fc: fc,
                                  cat: cat,
                                  isExpense: isExpense,
                                  selectedCatId: selectedCatId),
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: Icon(
                                        Icons.drag_indicator_rounded,
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
                                        if (selectedCatId.value == cat.id) {
                                          selectedCatId.value = '';
                                        }
                                        fc.deleteCategory(cat.id);
                                      }
                                    : () => Get.snackbar(
                                        '提示', '至少保留一个分类'),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddCategoryDialog(
                        fc: fc,
                        isExpense: isExpense,
                        selectedCatId: selectedCatId),
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
  void _showEditCategoryDialog({
    required FinanceController fc,
    required Category cat,
    required bool isExpense,
    required RxString selectedCatId,
  }) {
    final cs = Theme.of(context).colorScheme;
    final nameCtrl = TextEditingController(text: cat.name);
    final selectedIcon = cat.icon.obs;
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
                _labeledDivider('分类图标', cs),
                Obx(() => GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1,
                      children: _categoryIconKeys.map((key) {
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
                                color: selected
                                    ? Colors.white
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    )),
                const SizedBox(height: 10),
                _labeledDivider('背景颜色', cs),
                Obx(() => Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _randomColorOption(cs, selectedColor),
                        for (final c in _categoryColorPalette)
                          _categoryColorOption(cs, selectedColor, c),
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
              final color =
                  selectedColor.value ?? _randomPleasantColor();
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

  static const _categoryIconKeys = [
    'restaurant', 'directions_car', 'print', 'computer', 'work', 'chat',
    'attach_money', 'more_horiz', 'school', 'favorite', 'sports_esports',
    'savings', 'home', 'flight', 'local_cafe', 'music_note',
  ];

  static const _categoryColorPalette = [
    Color(0xFFE53935), Color(0xFFFB8C00), Color(0xFFFDD835), Color(0xFF43A047),
    Color(0xFF00ACC1), Color(0xFF1E88E5), Color(0xFF8E24AA), Color(0xFFEC407A),
    Color(0xFF6D4C41), Color(0xFF757575),
  ];

  /// 新增分类：名称 + 图标 + 背景颜色（未选择颜色时随机）
  void _showAddCategoryDialog({
    required FinanceController fc,
    required bool isExpense,
    required RxString selectedCatId,
  }) {
    final cs = Theme.of(context).colorScheme;
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
                _labeledDivider('分类图标', cs),
                Obx(() => GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1,
                      children: _categoryIconKeys.map((key) {
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
                                color: selected
                                    ? Colors.white
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    )),
                const SizedBox(height: 10),
                _labeledDivider('背景颜色', cs),
                Obx(() => Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _randomColorOption(cs, selectedColor),
                        for (final c in _categoryColorPalette)
                          _categoryColorOption(cs, selectedColor, c),
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
              final color = selectedColor.value ?? _randomPleasantColor();
              final id = fc.addCategory(
                name: name,
                icon: selectedIcon.value,
                color: color,
                type:
                    isExpense ? FinanceType.expense : FinanceType.income,
              );
              selectedCatId.value = id;
              Get.back();
              Get.snackbar('已添加', '分类「$name」已创建');
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _labeledDivider(String text, ColorScheme cs) {
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

  Widget _randomColorOption(ColorScheme cs, Rxn<Color> selected) {
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
        child:
            Icon(Icons.shuffle_rounded, size: 16, color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _categoryColorOption(
      ColorScheme cs, Rxn<Color> selected, Color color) {
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

  Color _randomPleasantColor() {
    final rnd = Random();
    return HSLColor.fromAHSL(1, rnd.nextDouble() * 360, 0.55, 0.55).toColor();
  }

  void _showQuickFinance() {
    final fc = Get.find<FinanceController>();
    final cs = Theme.of(context).colorScheme;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final isExpense = true.obs;
    final selectedCatId = ''.obs;

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('记一笔',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()]),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 8),
                Obx(() => Row(
                      children: [
                        Expanded(
                          child: _typePill(
                            label: '支出',
                            icon: Icons.south_west_rounded,
                            selected: isExpense.value,
                            color: Colors.red.shade600,
                            onTap: () {
                              isExpense.value = true;
                              _fixCategorySelection(
                                  fc, isExpense, selectedCatId);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _typePill(
                            label: '收入',
                            icon: Icons.north_east_rounded,
                            selected: !isExpense.value,
                            color: Colors.green.shade600,
                            onTap: () {
                              isExpense.value = false;
                              _fixCategorySelection(
                                  fc, isExpense, selectedCatId);
                            },
                          ),
                        ),
                      ],
                    )),
                const SizedBox(height: 14),
                _categoryGrid(
                  fc: fc,
                  cs: cs,
                  isExpense: isExpense,
                  selectedCatId: selectedCatId,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    hintText: '备注（选填）',
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final amount = double.tryParse(amountCtrl.text);
                      if (amount == null || amount <= 0) {
                        Get.snackbar('提示', '请输入有效金额');
                        return;
                      }
                      fc.addEntry(
                        type: isExpense.value
                            ? FinanceType.expense
                            : FinanceType.income,
                        amount: amount,
                        categoryId: selectedCatId.value,
                        description: noteCtrl.text,
                      );
                      _dc.refreshData();
                      Get.back();
                    },
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _typePill({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
