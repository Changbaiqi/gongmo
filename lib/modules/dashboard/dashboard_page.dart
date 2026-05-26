import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/finance_entry.dart';
import '../../data/models/work_entry.dart';
import '../dashboard/dashboard_controller.dart';
import '../dashboard/widgets/calendar_widget.dart';
import '../work/work_controller.dart';
import '../finance/finance_controller.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late DashboardController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(DashboardController(), tag: 'dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('工墨'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => Get.toNamed('/sync'),
          ),
        ],
      ),
      body: Obx(() => RefreshIndicator(
            onRefresh: () async => _ctrl.refreshData(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCalendar(),
                const SizedBox(height: 12),
                _buildSummaryCards(),
                const SizedBox(height: 12),
                if (_ctrl.hasActiveTimer.value) _buildActiveTimerCard(),
                const SizedBox(height: 12),
                _buildRecentEntries(),
              ],
            ),
          )),
      floatingActionButton: SizedBox(
        width: 56,
        height: 56,
        child: FloatingActionButton(
          onPressed: _showAddSheet,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Obx(() => MonthCalendar(
              markedDates: _ctrl.entryDates.toSet(),
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
                  Text('¥${_ctrl.monthIncome.value.toStringAsFixed(2)}',
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
                  Text('¥${_ctrl.monthExpense.value.toStringAsFixed(2)}',
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

  Widget _buildActiveTimerCard() {
    final entry = _ctrl.activeTimerEntry.value;
    if (entry == null) return const SizedBox.shrink();
    final elapsed = DateHelper.formatDurationShort(
        DateTime.now().difference(entry.startTime));
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.timer, color: Colors.blue, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '计时中: ${entry.projectName}  $elapsed',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Colors.red, size: 28),
              onPressed: () => _stopTimer(),
            ),
          ],
        ),
      ),
    );
  }

  void _stopTimer() {
    final wc = Get.find<WorkController>();
    wc.stopTimer();
    _ctrl.refreshData();
  }

  Widget _buildRecentEntries() {
    final entries = _ctrl.recentEntries;
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('暂无记录', style: TextStyle(color: Colors.grey.shade400)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('最近记录', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        ...entries.take(5).map((entry) {
          if (entry is WorkEntry) return _buildWorkItem(entry);
          if (entry is FinanceEntry) return _buildFinanceItem(entry);
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  Widget _buildWorkItem(WorkEntry entry) {
    final duration = entry.duration != null
        ? DateHelper.formatDuration(entry.duration!)
        : '进行中';
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: entry.status == WorkStatus.completed
            ? Colors.green.shade100
            : Colors.blue.shade100,
        child: Icon(
          entry.status == WorkStatus.completed ? Icons.check : Icons.timer,
          size: 16,
        ),
      ),
      title: Text(entry.projectName.isNotEmpty ? entry.projectName : '未命名',
          style: const TextStyle(fontSize: 14)),
      subtitle: Text(DateHelper.formatDisplay(entry.startTime),
          style: const TextStyle(fontSize: 12)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(duration, style: const TextStyle(fontSize: 12)),
          if (entry.income != null)
            Text('¥${entry.income!.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: Colors.green)),
        ],
      ),
    );
  }

  Widget _buildFinanceItem(FinanceEntry entry) {
    final isIncome = entry.type == FinanceType.income;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
        child: Icon(
          isIncome ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          color: isIncome ? Colors.green : Colors.red,
        ),
      ),
      title: Text(entry.description.isNotEmpty ? entry.description : '未备注',
          style: const TextStyle(fontSize: 14)),
      subtitle: Text(DateHelper.formatDisplay(entry.date),
          style: const TextStyle(fontSize: 12)),
      trailing: Text(
        '${isIncome ? '+' : '-'}¥${entry.amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 14,
          color: isIncome ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showAddSheet() {
    final FinanceController fc = Get.put(FinanceController());
    final WorkController wc = Get.put(WorkController());

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final projectCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '150');
    final isExpense = true.obs;
    final selectedCatId = ''.obs;
    final tabIndex = 0.obs;

    Get.bottomSheet(
      Container(
        height: 420,
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
            const SizedBox(height: 8),
            Obx(() => Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => tabIndex.value = 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: tabIndex.value == 0
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text('记 账',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: tabIndex.value == 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: tabIndex.value == 0
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                              )),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => tabIndex.value = 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: tabIndex.value == 1
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text('计时打卡',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: tabIndex.value == 1
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: tabIndex.value == 1
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                              )),
                        ),
                      ),
                    ),
                  ],
                )),
            Expanded(
              child: Obx(() => IndexedStack(
                    index: tabIndex.value,
                    children: [
                      _buildFinanceTab(
                          fc, amountCtrl, noteCtrl, isExpense, selectedCatId),
                      _buildWorkTab(wc, projectCtrl, rateCtrl),
                    ],
                  )),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildFinanceTab(
    FinanceController fc,
    TextEditingController amountCtrl,
    TextEditingController noteCtrl,
    RxBool isExpense,
    RxString selectedCatId,
  ) {
    final cats = fc.categories;
    final expCats = cats.where((c) => c.type == FinanceType.expense).toList();
    final incCats = cats.where((c) => c.type == FinanceType.income).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: '0.00',
              border: InputBorder.none,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('¥',
                    style: TextStyle(fontSize: 28, color: Colors.grey)),
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
            if (selectedCatId.value.isEmpty && activeCats.isNotEmpty) {
              selectedCatId.value = activeCats.first.id;
            }
            return Wrap(
              spacing: 6,
              runSpacing: 4,
              children: activeCats.map((cat) {
                return ChoiceChip(
                  label: Text(cat.name, style: const TextStyle(fontSize: 12)),
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
                type:
                    isExpense.value ? FinanceType.expense : FinanceType.income,
                amount: amount,
                categoryId: selectedCatId.value,
                description: noteCtrl.text,
              );
              _ctrl.refreshData();
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkTab(
    WorkController wc,
    TextEditingController projectCtrl,
    TextEditingController rateCtrl,
  ) {
    return Obx(() {
      if (wc.isTimerRunning.value) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer, size: 48, color: Colors.blue),
              const SizedBox(height: 12),
              Text(wc.currentTimerEntry.value?.projectName ?? '计时中',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(wc.formattedElapsed,
                  style: const TextStyle(
                      fontSize: 36,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              SizedBox(
                width: 160,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    wc.stopTimer();
                    _ctrl.refreshData();
                    Get.back();
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('结束计时'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('切换到工墨时钟页面开始计时', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    });
  }
}
