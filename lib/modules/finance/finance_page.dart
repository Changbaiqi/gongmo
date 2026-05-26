import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/finance_entry.dart';
import 'finance_controller.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final FinanceController _ctrl = Get.put(FinanceController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账目'),
        centerTitle: true,
      ),
      body: Obx(() {
        final entries = _ctrl.entries;
        return Column(
          children: [
            _buildSummaryHeader(),
            Expanded(
              child: entries.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('暂无账目记录'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: entries.length,
                      itemBuilder: (context, index) =>
                          _buildEntryItem(entries[index]),
                    ),
            ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(),
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text('本月收入', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Obx(() => Text(
                      '¥${_ctrl.monthIncome.value.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                    )),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: Column(
              children: [
                Text('本月支出', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Obx(() => Text(
                      '¥${_ctrl.monthExpense.value.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryItem(FinanceEntry entry) {
    final isIncome = entry.type == FinanceType.income;
    final categoryName = _ctrl.getCategoryName(entry.categoryId);
    final iconName = _ctrl.getCategoryIcon(entry.categoryId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncome ? Colors.green.shade50 : Colors.red.shade50,
          child: Icon(
            _getIconData(iconName),
            color: isIncome ? Colors.green : Colors.red,
          ),
        ),
        title: Text(categoryName),
        subtitle: Text(
          entry.description.isNotEmpty
              ? entry.description
              : DateHelper.formatDate(entry.date),
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}¥${entry.amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: isIncome ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onLongPress: () => _showDeleteConfirm(entry),
      ),
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'work':
        return Icons.work;
      case 'chat':
        return Icons.chat;
      case 'attach_money':
        return Icons.attach_money;
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'print':
        return Icons.print;
      case 'computer':
        return Icons.computer;
      case 'more_horiz':
        return Icons.more_horiz;
      default:
        return Icons.help_outline;
    }
  }

  void _showAddSheet() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final isExpense = true.obs;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('记一笔',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Obx(() => Row(
                    children: [
                      Expanded(
                        child: _typeButton('支出', !isExpense.value,
                            () => isExpense.value = true, Colors.red),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _typeButton('收入', isExpense.value,
                            () => isExpense.value = false, Colors.green),
                      ),
                    ],
                  )),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '金额',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: '备注',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Obx(() {
                final categories = isExpense.value
                    ? _ctrl.categories
                        .where((c) => c.type == FinanceType.expense)
                        .toList()
                    : _ctrl.categories
                        .where((c) => c.type == FinanceType.income)
                        .toList();
                final selectedCategoryId =
                    categories.isNotEmpty ? categories.first.id.obs : ''.obs;
                return Wrap(
                  spacing: 8,
                  children: categories.map((cat) {
                    return Obx(() => ChoiceChip(
                          label: Text(cat.name),
                          selected: selectedCategoryId.value == cat.id,
                          onSelected: (_) => selectedCategoryId.value = cat.id,
                        ));
                  }).toList(),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(amountCtrl.text);
                    if (amount == null || amount <= 0) {
                      Get.snackbar('错误', '请输入有效金额');
                      return;
                    }
                    final type = isExpense.value
                        ? FinanceType.expense
                        : FinanceType.income;
                    final categories = isExpense.value
                        ? _ctrl.categories
                            .where((c) => c.type == FinanceType.expense)
                            .toList()
                        : _ctrl.categories
                            .where((c) => c.type == FinanceType.income)
                            .toList();
                    _ctrl.addEntry(
                      type: type,
                      amount: amount,
                      categoryId:
                          categories.isNotEmpty ? categories.first.id : '',
                      description: descCtrl.text,
                    );
                    Get.back();
                  },
                  child: const Text('保存'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeButton(
      String label, bool isSelected, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.2) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  void _showDeleteConfirm(FinanceEntry entry) {
    Get.dialog(
      AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定删除这条账目记录吗？'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          TextButton(
            onPressed: () {
              _ctrl.deleteEntry(entry.id);
              Get.back();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
