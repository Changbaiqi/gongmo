import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/finance_entry.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/widgets/calendar_widget.dart';
import '../work/work_controller.dart';
import '../work/work_page.dart';
import '../finance/finance_controller.dart';

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
            icon: const Icon(Icons.sync),
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
      floatingActionButton: _currentIndex == 0
          ? SizedBox(
              width: 56,
              height: 56,
              child: FloatingActionButton(
                onPressed: _showQuickFinance,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, size: 28),
              ),
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
                  activeIcon: Icons.account_balance_wallet_rounded,
                  label: '记账',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.timer_outlined,
                  activeIcon: Icons.timer_sharp,
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
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = _currentIndex == index;
    final color =
        isActive ? Theme.of(context).colorScheme.primary : Colors.grey.shade500;

    return GestureDetector(
      onTap: () => _onNavTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, size: 22, color: color),
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
    final fc = Get.find<FinanceController>();

    return RefreshIndicator(
      onRefresh: () async => _dc.refreshData(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCalendar(),
          const SizedBox(height: 12),
          _buildSummaryCards(),
          const SizedBox(height: 12),
          if (_dc.hasActiveTimer.value) _buildActiveTimerBanner(),
          const SizedBox(height: 4),
          _buildFinanceHeader(),
          const SizedBox(height: 8),
          _buildFinanceListContent(fc),
        ],
      ),
    );
  }

  Widget _buildFinanceHeader() {
    return Obx(() => Row(
          children: [
            Text('全部账目', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            Text('收 ¥${_dc.monthIncome.value.toStringAsFixed(2)}',
                style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            Text('支 ¥${_dc.monthExpense.value.toStringAsFixed(2)}',
                style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ));
  }

  Widget _buildFinanceListContent(FinanceController fc) {
    final entries = fc.entries;
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('暂无账目', style: TextStyle(color: Colors.grey.shade400)),
        ),
      );
    }
    return Column(
      children:
          entries.map((entry) => _buildFinanceItemCard(fc, entry)).toList(),
    );
  }

  Widget _buildCalendar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Obx(() => MonthCalendar(
              markedDates: _dc.entryDates.toSet(),
            )),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  Text('本月收入', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('¥${_dc.monthIncome.value.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  Text('本月支出', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('¥${_dc.monthExpense.value.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTimerBanner() {
    final entry = _dc.activeTimerEntry.value;
    if (entry == null) return const SizedBox.shrink();
    final elapsed = DateHelper.formatDurationShort(
        DateTime.now().difference(entry.startTime));
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.timer, color: Colors.blue, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${entry.projectName}  $elapsed',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () {
                final wc = Get.find<WorkController>();
                wc.stopTimer();
                _dc.refreshData();
              },
              child: const Text('停止', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceItemCard(FinanceController fc, FinanceEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: entry.type == FinanceType.income
              ? Colors.green.shade100
              : Colors.red.shade100,
          child: Icon(
            entry.type == FinanceType.income
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            size: 16,
            color: entry.type == FinanceType.income ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          entry.description.isNotEmpty
              ? entry.description
              : fc.getCategoryName(entry.categoryId),
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(DateHelper.formatDisplay(entry.date),
            style: const TextStyle(fontSize: 12)),
        trailing: Text(
          '${entry.type == FinanceType.income ? '+' : '-'}¥${entry.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 14,
            color: entry.type == FinanceType.income ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        onLongPress: () => _confirmDeleteFinance(fc, entry),
      ),
    );
  }

  void _confirmDeleteFinance(FinanceController fc, FinanceEntry entry) {
    Get.dialog(AlertDialog(
      title: const Text('删除账目'),
      content: const Text('确定删除这条记录吗？'),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        TextButton(
          onPressed: () {
            fc.deleteEntry(entry.id);
            _dc.refreshData();
            Get.back();
          },
          child: const Text('删除', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }

  void _showQuickFinance() {
    final fc = Get.find<FinanceController>();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final isExpense = true.obs;
    final selectedCatId = ''.obs;

    final cats = fc.categories;
    final expCats = cats.where((c) => c.type == FinanceType.expense).toList();
    final incCats = cats.where((c) => c.type == FinanceType.income).toList();

    Get.bottomSheet(
      Container(
        height: 400,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text('记一笔', style: Theme.of(context).textTheme.titleMedium),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        border: InputBorder.none,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text('¥',
                              style:
                                  TextStyle(fontSize: 28, color: Colors.grey)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Obx(() => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ChoiceChip(
                              label: const Text('支出'),
                              selected: isExpense.value,
                              selectedColor: Colors.red.shade100,
                              onSelected: (_) {
                                isExpense.value = true;
                                if (expCats.isNotEmpty) {
                                  selectedCatId.value = expCats.first.id;
                                }
                              },
                            ),
                            const SizedBox(width: 12),
                            ChoiceChip(
                              label: const Text('收入'),
                              selected: !isExpense.value,
                              selectedColor: Colors.green.shade100,
                              onSelected: (_) {
                                isExpense.value = false;
                                if (incCats.isNotEmpty) {
                                  selectedCatId.value = incCats.first.id;
                                }
                              },
                            ),
                          ],
                        )),
                    const SizedBox(height: 8),
                    Obx(() {
                      final activeCats = isExpense.value ? expCats : incCats;
                      if (activeCats.isEmpty) return const SizedBox.shrink();
                      if (selectedCatId.value.isEmpty &&
                          activeCats.isNotEmpty) {
                        selectedCatId.value = activeCats.first.id;
                      }
                      return Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: activeCats.map((cat) {
                          return ChoiceChip(
                            label: Text(cat.name,
                                style: const TextStyle(fontSize: 12)),
                            selected: selectedCatId.value == cat.id,
                            onSelected: (_) => selectedCatId.value = cat.id,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      );
                    }),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        hintText: '备注（选填）',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
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
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}
