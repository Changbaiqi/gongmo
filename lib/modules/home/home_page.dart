// ============================================================
// home/home_page.dart（主界面 · 顶层页面）
// 职责：App 主框架——底部「记账 | 时钟」双 Tab（与 PageView 双向联动）；
//       记账 Tab 内再分「记账 | 统计」子页，分别内嵌记账流水与 StatsView。
// 关联：DashboardController(tag:'dashboard')（结余卡/预算/计时横幅数据）、
//       FinanceController（账目与分类 CRUD）、WorkController（计时）、
//       SyncController（同步状态动画）、StorageService（读取分类配置）、
//       StatsView / WorkPage / TiltCard / CountUpText / SwipeActionCard。
// 结构：结余卡（滚动折叠）→ 进行中计时横幅 → 吸顶筛选行 → 按天分组的账目列表。
// ============================================================
import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/icon_utils.dart';
import '../../core/widgets/count_up_text.dart';
import '../../core/widgets/swipe_action_card.dart';
import '../../core/widgets/tilt_card.dart';
import '../../app/routes/app_routes.dart' show AppRoutes;
import '../../data/models/category.dart';
import '../../data/models/finance_entry.dart';
import '../../data/models/work_entry.dart';
import '../../data/services/attachment_service.dart';
import '../../data/services/storage_service.dart';
import '../dashboard/dashboard_controller.dart';
import '../ocr/photo_bookkeeping.dart';
import '../sync/sync_controller.dart';
import '../work/work_controller.dart';
import '../work/work_page.dart';
import '../finance/finance_controller.dart';
import '../finance/widgets/attachment_editor.dart';
import '../finance/widgets/category_manager.dart';
import '../stats/stats_view.dart';

/// 应用主界面（路由 `/`）：承载记账与时钟两大模块的顶层容器。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // 底部导航当前页：0=记账，1=时钟
  int _currentIndex = 0;

  // 概览聚合控制器：与旧版 DashboardPage 共用同一实例（tag: 'dashboard'）
  final DashboardController _dc =
      Get.put(DashboardController(), tag: 'dashboard');

  // 两个 Tab 的 PageController：与底部导航双向联动（点击 / 滑动都会同步）
  final PageController _pageCtrl = PageController();

  // 记账 Tab 的子页下标：0=记账，1=统计
  int _financeSubIndex = 0;
  int _financePlayKey = 0; // 切回记账页时自增，触发金额滚动动效
  DateTime? _financeMonthFilter; // 记账页月份筛选（null = 全部）
  final ScrollController _financeScroll = ScrollController();

  // 结余卡折叠进度 0..1（由滚动通知驱动）与卡片实测高度（用于折叠计算）
  final ValueNotifier<double> _balanceCollapse = ValueNotifier(0);
  final GlobalKey _balanceKey = GlobalKey();
  double _balanceCardHeight = 320;

  final SyncController _sc = Get.find<SyncController>();
  late final AnimationController _syncSpin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Worker? _syncWorker;

  /// 初始化：注册记账/工时控制器，并把「同步中」状态映射为顶部图标的旋转动画。
  @override
  void initState() {
    super.initState();
    Get.put(FinanceController());
    Get.put(WorkController());
    // 自动备份期间：顶部同步图标旋转；结束后停止
    _syncWorker = ever<bool>(_sc.isSyncing, (v) {
      if (v) {
        _syncSpin.repeat();
      } else {
        _syncSpin.stop();
      }
    });
    if (_sc.isSyncing.value) _syncSpin.repeat();
  }

  /// 释放本页自建的 Worker、动画与 PageController（GetX 控制器不在此销毁）。
  @override
  void dispose() {
    _syncWorker?.dispose();
    _syncSpin.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  /// PageView 滑动完成回调：同步底部导航高亮；切回记账页时触发金额滚动动效。
  void _onPageChanged(int index) {
    if (index == 0) _financePlayKey++; // 切回记账页触发金额滚动动效
    setState(() => _currentIndex = index);
  }

  /// 底部导航点击：先更新高亮，再动画滚动 PageView 到对应页。
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      // 标题随 Tab 切换；右侧：同步状态按钮 + 设置入口
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? '工墨记账' : '工墨时钟'),
        centerTitle: true,
        actions: [
          Obx(() {
            final backing = _sc.isSyncing.value;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale:
                      Tween<double>(begin: 0.6, end: 1.0).animate(anim),
                  child: child,
                ),
              ),
              child: backing
                  ? Container(
                      key: const ValueKey('backing'),
                      width: 58,
                      height: 46,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RotationTransition(
                            turns: _syncSpin,
                            child: Icon(Icons.sync_rounded,
                                size: 20, color: cs.primary),
                          ),
                          const SizedBox(height: 1),
                          Text('备份中',
                              style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary)),
                        ],
                      ),
                    )
                  : IconButton(
                      key: const ValueKey('idle'),
                      icon: const Icon(Icons.sync_outlined),
                      onPressed: () => Get.toNamed('/sync'),
                    ),
            );
          }),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Get.toNamed('/settings'),
          ),
        ],
      ),
      // 双 Tab 主体：记账页为自建 Column（内嵌子切换），时钟页直接复用 WorkPage
      body: PageView(
        controller: _pageCtrl,
        onPageChanged: _onPageChanged,
        children: [
          _buildFinanceTab(),
          const WorkPage(),
        ],
      ),
      // FAB 只在「记账 Tab 的记账子页」出现，统计子页与时钟 Tab 不显示；
      // 长按触发拍照识别记账（识别方式与截屏记账共用）
      floatingActionButton: _currentIndex == 0 && _financeSubIndex == 0
          ? GestureDetector(
              onLongPress: _capturePhotoBookkeeping,
              child: FloatingActionButton(
                onPressed: _showQuickFinance,
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

  /// 记账 Tab 外壳：顶部「记账 | 统计」胶囊 + AnimatedSwitcher 切换子页。
  /// KeyedSubtree 以子页下标为 key，切换时旧页销毁、新页重建
  /// （统计页因此会重新聚合一次数据）。
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

  /// 「记账 | 统计」胶囊切换；点回记账时自增 [_financePlayKey] 重播金额动画。
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

  /// 记账子页：结余卡 + 计时横幅 + 吸顶筛选行 + 按天分组的账目列表。
  ///
  /// 用 CustomScrollView + Sliver 组合让筛选行能吸顶；外层滚动通知把垂直
  /// 滚动量换算成结余卡折叠进度，见 [_balanceCollapse]。
  Widget _buildBookkeeping() {
    final fc = Get.find<FinanceController>();

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // 滚动量 / 卡片高度 => 0..1 折叠进度；下拉回弹的负值不参与
        if (n.metrics.axis == Axis.vertical &&
            _balanceCardHeight > 0 &&
            n.metrics.pixels >= 0) {
          _balanceCollapse.value =
              (n.metrics.pixels / _balanceCardHeight).clamp(0.0, 1.0);
        }
        return false;
      },
      child: CustomScrollView(
        controller: _financeScroll,
        slivers: [
          // ① 结余卡：滚动时向上翻折收起
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: ValueListenableBuilder<double>(
                valueListenable: _balanceCollapse,
                builder: (context, t, _) {
                  // 静止时直接渲染卡片：高度由内容决定，
                  // 预算区展开/收起时下方内容会平滑跟随移动。
                  if (t < 0.01 || _balanceCardHeight <= 0) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      final h = _balanceKey.currentContext?.size?.height;
                      if (h != null && h > 0) _balanceCardHeight = h;
                    });
                    return _buildBalanceCard(key: _balanceKey);
                  }
                  // 滚动折叠：卡片正常高度由内容撑开，直接改高度会因内容重排而抖动；
                  // 这里固定外层高度，内部用 OverflowBox 保留原尺寸再做 3D 翻折
                  final visibleH = max(0.0, _balanceCardHeight * (1 - t));
                  if (visibleH < 0.5) return const SizedBox.shrink();
                  // 折叠过程中额外保留一层柔和外阴影（随折叠渐隐）：
                  // 卡片内容被裁剪时外阴影会被一起裁掉，磨砂卡片会显得突然变亮
                  final shadowFade = (1 - t / 0.35).clamp(0.0, 1.0);
                  final projH = _balanceCardHeight *
                      cos(t * pi / 2) *
                      (1.0 - 0.06 * t);
                  return LayoutBuilder(
                    builder: (context, cons) {
                      return SizedBox(
                        height: visibleH,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (shadowFade > 0)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(
                                  child: Container(
                                    height: projH.clamp(
                                        0.0, _balanceCardHeight),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                              alpha: 0.26 * shadowFade),
                                          blurRadius: 16,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ClipRRect(
                              // 圆角裁剪：折叠过程中也不会在底部露出直角切口
                              borderRadius: BorderRadius.circular(20),
                              child: OverflowBox(
                                alignment: Alignment.topCenter,
                                minWidth: 0,
                                maxWidth: cons.maxWidth,
                                minHeight: 0,
                                maxHeight: _balanceCardHeight + 160,
                                // 注意：这里不能包 Opacity——它会让卡片与代理阴影
                                // 分到不同图层，磨砂 BackdropFilter 采样不到阴影，
                                // 卡片下半部分就会突然变亮
                                child: Transform(
                                  alignment: Alignment.topCenter,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.001) // 透视
                                    ..rotateX(
                                        t * pi / 2) // 绕顶边向内翻折（视觉收缩）
                                    ..scale(1.0 - 0.06 * t),
                                  child: _buildBalanceCard(
                                      key: _balanceKey, showShadow: false),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          // ② 进行中计时横幅（无进行中记录时高度为 0）
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _buildActiveTimerBanner()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 4)),
          // ③ 吸顶筛选行：固定高度 40，上滚时停留在顶部
          SliverPersistentHeader(
            pinned: true,
            delegate: _FinanceHeaderDelegate(
              builder: () => _buildFinanceHeader(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          // ④ 账目列表：按天分组（底部留 96 给 FAB 与导航栏让位）
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            sliver: SliverToBoxAdapter(child: _buildFinanceListContent(fc)),
          ),
        ],
      ),
    );
  }

  /// 吸顶筛选行：左侧当前筛选状态（可一键清除），右侧年月选择入口。
  Widget _buildFinanceHeader() {
    final cs = Theme.of(context).colorScheme;
    final filter = _financeMonthFilter;
    final now = DateTime.now();
    final viewMonth = filter ?? DateTime(now.year, now.month);
    return Row(
      children: [
        Text(
          filter == null
              ? '全部账目'
              : '${filter.year}年${filter.month}月 账目',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (filter != null) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _financeMonthFilter = null),
            child: Icon(Icons.cancel_rounded,
                size: 16, color: cs.onSurfaceVariant),
          ),
        ],
        const Spacer(),
        // 右侧日期显示：点击弹出年月选择底部窗口
        GestureDetector(
          onTap: _showFinanceMonthPicker,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('${viewMonth.year}年${viewMonth.month}月',
                    style: TextStyle(
                        fontSize: 11.5, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 月份筛选：Material 日期选择器（中文），取所选日期的年月
  Future<void> _showFinanceMonthPicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _financeMonthFilter ?? DateTime(now.year, now.month),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: '选择年月',
    );
    if (picked != null) {
      setState(
          () => _financeMonthFilter = DateTime(picked.year, picked.month));
    }
  }

  /// 本月预算：总预算（可选）+ 分类预算管理
  void _showBudgetDialog() {
    final cs = Theme.of(context).colorScheme;
    final totalCtrl = TextEditingController(
      text: _dc.totalBudget.value > 0
          ? _dc.totalBudget.value.toStringAsFixed(0)
          : '',
    );

    // 应用总预算输入：留空视为 0（清除，自动回落为分类之和）；
    // 非空时校验不能低于已分配的分类预算之和
    // 返回 null 表示成功；否则返回错误提示（不弹 snackbar）
    String? applyTotal() {
      final raw = totalCtrl.text.trim();
      final v = raw.isEmpty ? 0.0 : double.tryParse(raw);
      if (v == null) {
        return '请输入有效的总预算金额';
      }
      if (v > 0 && v < _dc.allocatedBudget) {
        return '总预算（¥${v.toStringAsFixed(2)}）不能低于分类预算之和（¥${_dc.allocatedBudget.toStringAsFixed(2)}）';
      }
      _dc.setTotalBudget(v);
      return null;
    }

    var closing = false; // 是否通过「完成」正常关闭，避免 whenComplete 重复应用

    Get.dialog(
      AlertDialog(
        title: const Text('本月预算'),
        content: Obx(
          () => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: totalCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  final err = applyTotal();
                  if (err != null) Get.snackbar('无法保存', err);
                },
                decoration: const InputDecoration(
                  labelText: '总预算额度 (¥，留空自动按分类之和)',
                  prefixText: '¥ ',
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text('设置后分类预算之和不能超过总预算',
                    style: TextStyle(
                        fontSize: 10.5,
                        color:
                            cs.onSurfaceVariant.withValues(alpha: 0.7))),
              ),
              const SizedBox(height: 12),
              Center(
                child: AnimatedBuilder(
                  animation: totalCtrl,
                  builder: (context, _) {
                    final typed = double.tryParse(totalCtrl.text.trim());
                    final preview = (typed != null && typed > 0)
                        ? typed
                        : _dc.totalBudgetAmount;
                    final used = _dc.monthExpense.value;
                    final ratio = preview > 0 ? used / preview : 0.0;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: ratio),
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => _BudgetRing(
                            progress: value,
                            progressColor: cs.primary,
                            trackColor: cs.surfaceContainerHighest,
                            center: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  preview > 0
                                      ? '¥${preview.toStringAsFixed(0)}'
                                      : '--',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSurface),
                                ),
                                const SizedBox(height: 2),
                                Text('总预算',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: cs.onSurfaceVariant
                                            .withValues(alpha: 0.8))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preview > 0
                              ? '已使用 ¥${used.toStringAsFixed(2)}（${(ratio * 100).round()}%）'
                              : '输入额度后显示使用情况',
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant
                                  .withValues(alpha: 0.85)),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              _labeledDivider('分类预算', cs),
              const SizedBox(height: 4),
              if (_dc.budgets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text('尚未设置分类预算，点击下方按钮添加',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant
                                .withValues(alpha: 0.7))),
                  ),
                )
              else
                ..._dc.budgets.entries.map((e) {
                  final used = _dc.categoryExpense[e.key] ?? 0;
                  final p = e.value > 0 ? (used / e.value) : 0.0;
                  final cat = _categoryById(e.key);
                  final name = cat?.name ?? '已删分类';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                                IconUtils.category(cat?.icon ?? ''),
                                size: 14,
                                color: cs.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            Text(
                                '${used.toStringAsFixed(0)} / ${e.value.toStringAsFixed(0)}',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: cs.onSurfaceVariant,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ])),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showBudgetEditDialog(
                                  existingCatId: e.key,
                                  existingAmount: e.value),
                              child: Icon(Icons.edit_rounded,
                                  size: 16,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.8)),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _dc.setBudgetFor(e.key, 0),
                              child: Icon(Icons.delete_outline_rounded,
                                  size: 16,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 分类进度条：从 0 动画到使用率（超 100% 截断，颜色由阈值决定）
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(
                                begin: 0, end: p.clamp(0.0, 1.0)),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) =>
                                LinearProgressIndicator(
                              value: value,
                              minHeight: 5,
                              backgroundColor: cs.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation(
                                  _budgetBarColor(p)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showBudgetEditDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('添加分类预算'),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text('为支出分类设置每月额度，结余卡会显示各分类进度',
                    style: TextStyle(
                        fontSize: 10.5,
                        color:
                            cs.onSurfaceVariant.withValues(alpha: 0.7))),
              ),
            ],
          ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (closing) return;
              final err = applyTotal();
              if (err != null) {
                Get.snackbar('无法保存', err);
                return;
              }
              closing = true;
              Get.closeCurrentSnackbar();
              Get.back();
            },
            child: const Text('完成'),
          ),
        ],
      ),
    ).whenComplete(() {
      // 若通过点空白处/返回键关闭（未点「完成」），也把输入的额度应用上
      if (!closing) {
        final err = applyTotal();
        if (err != null) Get.snackbar('无法保存', err);
      }
    });
  }

  /// 添加/编辑某分类的预算额度
  void _showBudgetEditDialog(
      {String? existingCatId, double? existingAmount}) {
    final cs = Theme.of(context).colorScheme;
    // 新增时只列出尚未设置预算的支出分类；编辑时保留当前分类（即使已设预算）
    final expenseCats = StorageService()
        .categories
        .where((c) =>
            c.type == FinanceType.expense &&
            (existingCatId != null || !_dc.budgets.containsKey(c.id)))
        .toList();
    final selCat =
        (existingCatId ?? (expenseCats.isNotEmpty ? expenseCats.first.id : ''))
            .obs;
    final amountCtrl = TextEditingController(
        text: existingAmount != null && existingAmount > 0
            ? existingAmount.toStringAsFixed(0)
            : '');

    Get.dialog(
      AlertDialog(
        title: Text(existingCatId == null ? '添加分类预算' : '编辑分类预算'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              if (expenseCats.isEmpty) {
                return Text('所有支出分类都已设置预算',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurfaceVariant
                            .withValues(alpha: 0.8)));
              }
              return DropdownButtonFormField<String>(
                value: selCat.value,
                decoration: const InputDecoration(
                  labelText: '选择支出分类',
                ),
                items: expenseCats
                    .map((c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Row(
                            children: [
                              Icon(IconUtils.category(c.icon),
                                  size: 16,
                                  color: IconUtils.hex(c.color)),
                              const SizedBox(width: 8),
                              Text(c.name,
                                  style:
                                      const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) => selCat.value = v ?? '',
              );
            }),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '每月额度 (¥)',
                prefixText: '¥ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final catId = existingCatId ?? selCat.value;
              if (catId.isEmpty) {
                Get.snackbar('提示', '请选择分类');
                return;
              }
              final v = double.tryParse(amountCtrl.text);
              if (v == null || v <= 0) {
                Get.snackbar('提示', '请输入有效的预算金额');
                return;
              }
              // 校验：其他分类已分配额度 + 本次额度 不能超过总预算
              //（编辑时先扣除该分类原有额度，避免把自己算两遍）
              final others = _dc.allocatedBudget -
                  (existingCatId != null
                      ? (_dc.budgets[existingCatId] ?? 0)
                      : 0);
              if (_dc.totalBudget.value > 0 &&
                  others + v > _dc.totalBudget.value) {
                Get.snackbar('无法保存',
                    '分类预算之和（¥${(others + v).toStringAsFixed(2)}）不能超过总预算（¥${_dc.totalBudget.value.toStringAsFixed(2)}）');
                return;
              }
              _dc.setBudgetFor(catId, v);
              Get.closeCurrentSnackbar();
              Get.back();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 预算进度条颜色：随占用率变化（绿 → 橙 → 红）
  Color _budgetBarColor(double pct) {
    if (pct >= 1.0) return const Color(0xFFEF9A9A);
    if (pct >= 0.9) return const Color(0xFFFFCC80);
    return const Color(0xFFA5D6A7);
  }

  Category? _categoryById(String id) {
    for (final c in StorageService().categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Widget _budgetStatRow(String label, String value, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: cs.onSurfaceVariant)),
          Text(value,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }

  /// 结余卡快捷菜单
  static const _balanceMenuItems = <(IconData, String)>[
    (Icons.receipt_long_rounded, '账单'),
    (Icons.savings_rounded, '预算'),
    (Icons.account_balance_rounded, '资产管家'),
    (Icons.more_horiz_rounded, '更多'),
  ];

  /// 结余卡：毛玻璃渐变 + 倾斜高光，展示本月结余/收支、快捷菜单与预算进度。
  /// key 由外部传入（_balanceKey）用于测量卡片实际高度。
  Widget _buildBalanceCard({Key? key, bool showShadow = true}) {
    final cs = Theme.of(context).colorScheme;
    return Obx(
      key: key,
      () {
      final income = _dc.monthIncome.value;
      final expense = _dc.monthExpense.value;
      final balance = income - expense;
      final onPrimary = cs.onPrimary;
      return TiltCard(
        borderRadius: 20,
        // 折叠时由外层（未被裁剪的）代理阴影负责，卡片自身不再画阴影，
        // 避免被 ClipRRect 硬切出一条亮边
        shadowColor: showShadow
            ? Colors.black.withValues(alpha: 0.26)
            : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          // 磨砂玻璃：半透明主色渐变 + 背景模糊 + 玻璃描边
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: 0.72),
              Color.lerp(cs.primary, onPrimary, 0.22)!
                  .withValues(alpha: 0.58),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.22), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 12),
            Container(height: 1, color: onPrimary.withValues(alpha: 0.18)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (icon, label) in _balanceMenuItems) ...[
                  Expanded(
                    child: _balanceMenuButton(
                      cs,
                      icon,
                      label,
                      onTap: () {
                        switch (label) {
                          case '预算':
                            _showBudgetDialog();
                          case '更多':
                            Get.toNamed(AppRoutes.more);
                          default:
                            Get.snackbar('提示', '「$label」功能开发中，敬请期待');
                        }
                      },
                    ),
                  ),
                  if (label != _balanceMenuItems.last.$2)
                    const SizedBox(width: 8),
                ],
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !(_dc.budgets.isNotEmpty ||
                      _dc.totalBudget.value > 0)
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      children: [
              const SizedBox(height: 12),
              Container(height: 1, color: onPrimary.withValues(alpha: 0.18)),
              const SizedBox(height: 12),
              // 分段式预算条：每个分类占一段（宽度=预算占比），
              // 段内按使用率以分类色填充；仅设总预算时为单一进度段；
              // 点击打开预算管理
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showBudgetDialog,
                child: Obx(() {
                  final hasTotal = _dc.totalBudget.value > 0;
                  final segments = <(Color, double, double, String)>[];
                  for (final e in _dc.budgets.entries) {
                    final cat = _categoryById(e.key);
                    segments.add((
                      cat != null
                          ? IconUtils.hex(cat.color)
                          : onPrimary.withValues(alpha: 0.6),
                      e.value,
                      _dc.categoryExpense[e.key] ?? 0,
                      cat?.name ?? '已删分类',
                    ));
                  }
                  // 已设总预算且有分类段时：剩余额度作为"其他"段
                  if (hasTotal && segments.isNotEmpty) {
                    final allocated =
                        segments.fold(0.0, (s, e) => s + e.$2);
                    final used = segments.fold(0.0, (s, e) => s + e.$3);
                    if (_dc.totalBudget.value > allocated) {
                      segments.add((
                        onPrimary.withValues(alpha: 0.45),
                        _dc.totalBudget.value - allocated,
                        (_dc.monthExpense.value - used)
                            .clamp(0.0, double.infinity),
                        '其他',
                      ));
                    }
                  }
                  // 仅设置总预算时：整条为单一"总预算"段
                  if (hasTotal && segments.isEmpty) {
                    segments.add((
                      onPrimary.withValues(alpha: 0.55),
                      _dc.totalBudget.value,
                      _dc.monthExpense.value,
                      '总预算',
                    ));
                  }
                  final totalBudget = hasTotal
                      ? _dc.totalBudget.value
                      : segments.fold(0.0, (s, e) => s + e.$2);
                  final totalUsed = hasTotal
                      ? _dc.monthExpense.value
                      : segments.fold(0.0, (s, e) => s + e.$3);
                  final pct = totalBudget > 0
                      ? (totalUsed / totalBudget)
                      : 0.0;
                  final hasCats = _dc.budgets.isNotEmpty;
                  final totalPct = totalBudget > 0
                      ? ((totalUsed / totalBudget) * 100).toStringAsFixed(0)
                      : '0';
                  return Column(
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: SizedBox(
                              height: 18,
                              child: Row(
                                children: [
                                  for (final seg in segments)
                                    // Expanded 的 flex 必须是正整数：
                                    // 金额放大 1000 倍取整，并保证最小为 1
                                    Expanded(
                                      flex: (seg.$2 * 1000)
                                          .round()
                                          .clamp(1, 1 << 30),
                                      child: Stack(
                                        children: [
                                          Container(
                                            color: onPrimary
                                                .withValues(alpha: 0.16),
                                          ),
                                          TweenAnimationBuilder<double>(
                                            tween: Tween(
                                                begin: 0,
                                                end: (seg.$3 / seg.$2)
                                                    .clamp(0.0, 1.0)),
                                            duration: const Duration(
                                                milliseconds: 700),
                                            curve: Curves.easeOutCubic,
                                            builder: (context, value, _) =>
                                                FractionallySizedBox(
                                              alignment:
                                                  Alignment.centerLeft,
                                              widthFactor: value,
                                              child:
                                                  Container(color: seg.$1),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Center(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: pct),
                                duration:
                                    const Duration(milliseconds: 700),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) => Text(
                                  '已使用 ${(value * 100).round()}%',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: onPrimary),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 图例：总预算信息 + 各分段（名称 占比 已用/预算）
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          if (hasCats)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                      color: onPrimary
                                          .withValues(alpha: 0.9),
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '总预算 $totalPct% · ¥${totalUsed.toStringAsFixed(0)}/¥${totalBudget.toStringAsFixed(0)}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: onPrimary),
                                ),
                              ],
                            ),
                          for (final seg in segments)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                      color: seg.$1, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${seg.$4} ${(seg.$3 / seg.$2 * 100).toStringAsFixed(0)}% · ¥${seg.$3.toStringAsFixed(0)}/¥${seg.$2.toStringAsFixed(0)}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: onPrimary
                                          .withValues(alpha: 0.85)),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  );
                }),
              ),
                      ],
                    ),
            ),
          ],
        ),
        ),
        ),
        ),
      );
    });
  }

  Widget _balanceMenuButton(
      ColorScheme cs, IconData icon, String label,
      {VoidCallback? onTap}) {
    final onPrimary = cs.onPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () => Get.snackbar('提示', '「$label」功能开发中，敬请期待'),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: onPrimary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: onPrimary),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    color: onPrimary.withValues(alpha: 0.92))),
          ],
        ),
      ),
    );
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

  /// 进行中计时横幅：有进行中记录时淡入显示（AnimatedSwitcher 靠不同 key 切换）。
  Widget _buildActiveTimerBanner() {
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      final entry = _dc.activeTimerEntry.value;
      final active = _dc.hasActiveTimer.value && entry != null;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-0.06, 0),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: active
            ? _activeTimerBannerContent(cs, entry)
            : const SizedBox.shrink(key: ValueKey('no_timer')),
      );
    });
  }

  Widget _activeTimerBannerContent(ColorScheme cs, WorkEntry entry) {
    // 故意读取每秒跳动的 todayWorkDuration：为 Obx 建立依赖，让横幅时长实时刷新
    _dc.todayWorkDuration.value;
    final elapsed = DateHelper.formatDurationShort(entry.liveElapsed);
    return Container(
      key: const ValueKey('active_timer'),
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

  /// 账目列表内容：按月份筛选后按天分组渲染，空态给提示。
  Widget _buildFinanceListContent(FinanceController fc) {
    return Obx(() {
      final month = _financeMonthFilter;
      final entries = month == null
          ? fc.entries
          : fc.entries
              .where((e) =>
                  e.date.year == month.year && e.date.month == month.month)
              .toList();

      if (entries.isEmpty) {
        return _StaggeredEntrance(
          key: ValueKey('empty_${month?.year}_${month?.month}'),
          index: 0,
          child: _buildEmptyState(
            icon: Icons.receipt_long_outlined,
            message: month == null
                ? '还没有账目，点击 + 记一笔吧'
                : '${month.year}年${month.month}月暂无账目',
          ),
        );
      }

      // 按“日期文案”分组；order 记录首次出现顺序。
      // entries 已按时间倒序，因此分组天然是倒序，无需再排序
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

      // 交错入场序号跨分组连续自增，整屏条目按顺序逐个出现
      var animIndex = 0;
      return Column(
        children: [
          for (final key in order) ...[
            _StaggeredEntrance(
              key: ValueKey('h_$key'),
              index: animIndex++,
              child: _buildDayHeader(groups[key]!),
            ),
            for (final entry in groups[key]!)
              _StaggeredEntrance(
                key: ValueKey('e_${entry.id}'),
                index: animIndex++,
                child: _buildFinanceItemCard(fc, entry),
              ),
          ],
        ],
      );
    });
  }

  // 日期标题：今天/昨天/x月x日 + 当天收支合计（同一天判断忽略时分秒）
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

  /// 单条账目卡片：分类色图标 + 备注/分类 + 自动记账标签 + 金额；
  /// 外层 SwipeActionCard 负责左滑「修改/删除」。
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
            subtitle: Row(
              children: [
                Flexible(
                  child: Text(
                    '${fc.getCategoryName(entry.categoryId)} · ${DateHelper.formatDisplay(entry.date)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: entry.notificationSrc != null
                        ? cs.primary.withValues(alpha: 0.14)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  // notificationSrc 非空表示这条来自通知自动记账
                  child: Text(
                    entry.notificationSrc != null ? '自动' : '手动',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: entry.notificationSrc != null
                          ? cs.primary
                          : cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
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

  /// 左滑删除的二次确认；删除后刷新 Dashboard 并重建列表。
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

  /// 编辑账目底部表单：保存时原地更新字段并写入 `updatedAt`（供多设备合并判新），
  /// 再交给 FinanceController.saveEntry 落盘。
  void _showEditFinanceSheet(FinanceController fc, FinanceEntry entry) {
    final cs = Theme.of(context).colorScheme;
    final amountCtrl = TextEditingController(text: entry.amount.toString());
    final noteCtrl = TextEditingController(text: entry.description);
    final isExpense = (entry.type == FinanceType.expense).obs;
    final selectedCatId = entry.categoryId.obs;
    final entryTime = entry.date.obs;
    final attachments = List<String>.of(entry.attachmentPaths);

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
                const SizedBox(height: 12),
                _entryTimeRow(entryTime),
                const SizedBox(height: 12),
                AttachmentEditor(
                  entryId: entry.id,
                  initialPaths: entry.attachmentPaths,
                  onChanged: (list) => attachments
                    ..clear()
                    ..addAll(list),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final amount = double.tryParse(amountCtrl.text);
                      if (amount == null || amount <= 0) {
                        Get.snackbar('提示', '请输入有效的金额');
                        return;
                      }
                      entry.amount = amount;
                      entry.type = isExpense.value
                          ? FinanceType.expense
                          : FinanceType.income;
                      entry.categoryId = selectedCatId.value;
                      entry.description = noteCtrl.text;
                      entry.date = entryTime.value;
                      // 附件：过滤掉已被删除的文件后保存
                      entry.attachmentPaths = attachments
                          .where((p) => AttachmentService.instance.exists(p))
                          .toList();
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

  /// 分类图标网格（记一笔 / 修改账目 共用）。
  /// 复用 [CategoryGridPicker]，与截屏记账确认弹窗共用同一套分类数据。
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
        // 默认选中第一个分类；放到帧后回调，避免 build 期间修改 Rx 状态
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (selectedCatId.value.isEmpty) {
            selectedCatId.value = activeCats.first.id;
          }
        });
      }
      return CategoryGridPicker(
        fc: fc,
        cs: cs,
        type: type,
        getSelectedId: () => selectedCatId.value,
        onSelected: (id) => selectedCatId.value = id,
      );
    });
  }

  /// 账目时间行：点击选择日期与时间（默认当前时间点）。
  Widget _entryTimeRow(Rx<DateTime> entryTime) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _pickEntryTime(entryTime),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Obx(() => Row(
              children: [
                Icon(Icons.event_note_rounded,
                    size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  '时间：${DateHelper.formatDateTime(entryTime.value).substring(0, 16)}',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                Icon(Icons.edit_rounded,
                    size: 14,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
              ],
            )),
      ),
    );
  }

  /// 先选日期再选时间，任一步取消则整体放弃；结果写回传入的 Rx。
  Future<void> _pickEntryTime(Rx<DateTime> entryTime) async {
    final d = await showDatePicker(
      context: context,
      initialDate: entryTime.value,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    final tm = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(entryTime.value),
    );
    if (tm == null) return;
    entryTime.value = DateTime(d.year, d.month, d.day, tm.hour, tm.minute);
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

  /// 长按 + 按钮：拍照识别账单（与常驻通知的「拍照记账」按钮共用）
  Future<void> _capturePhotoBookkeeping() => startPhotoBookkeeping();

  /// 快速记账底部表单：金额/收支 pill/分类网格/备注/时间；
  /// 保存调用 FinanceController.addEntry 并刷新 Dashboard。
  void _showQuickFinance() {
    final fc = Get.find<FinanceController>();
    final cs = Theme.of(context).colorScheme;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final isExpense = true.obs;
    final selectedCatId = ''.obs;
    final entryTime = DateTime.now().obs;
    // 预生成账目 id：附件按该 id 存放，取消时一并清理
    final entryId = const Uuid().v4();
    final attachments = <String>[];
    var saved = false;

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
                const SizedBox(height: 12),
                _entryTimeRow(entryTime),
                const SizedBox(height: 12),
                AttachmentEditor(
                  entryId: entryId,
                  onChanged: (list) => attachments
                    ..clear()
                    ..addAll(list),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final amount = double.tryParse(amountCtrl.text);
                      if (amount == null || amount <= 0) {
                        Get.snackbar('提示', '请输入有效的金额');
                        return;
                      }
                      saved = true;
                      fc.addEntry(
                        type: isExpense.value
                            ? FinanceType.expense
                            : FinanceType.income,
                        amount: amount,
                        categoryId: selectedCatId.value,
                        description: noteCtrl.text,
                        date: entryTime.value,
                        id: entryId,
                        attachmentPaths: List.of(attachments),
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
    ).whenComplete(() {
      // 未保存时清理已选附件，避免留下无用文件
      if (!saved && attachments.isNotEmpty) {
        AttachmentService.instance.deleteAllFor(entryId);
      }
    });
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
/// 首次出现时从左滑入并淡入（按 index 交错延迟）
class _StaggeredEntrance extends StatefulWidget {
  const _StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 45 * widget.index.clamp(0, 10));
    Future.delayed(delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(-0.08, 0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 预算圆环：显示使用进度，中心内容由调用方传入（金额 + 文案）。
class _BudgetRing extends StatelessWidget {
  final double progress; // 0..1（可超过 1，绘制时截断）
  final Color progressColor;
  final Color trackColor;
  final Widget center;

  const _BudgetRing({
    required this.progress,
    required this.progressColor,
    required this.trackColor,
    required this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(130, 130),
            painter: _BudgetRingPainter(
              progress: progress,
              progressColor: progressColor,
              trackColor: trackColor,
            ),
          ),
          center,
        ],
      ),
    );
  }
}

/// 圆环绘制器：先画底环，再从 12 点方向顺时针画进度弧（圆头笔刷）。
class _BudgetRingPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color trackColor;

  _BudgetRingPainter({
    required this.progress,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height)
        .deflate(stroke / 2 + 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawCircle(size.center(Offset.zero), rect.width / 2, track);

    // 超支时 clamp 到 1，避免弧线画过头
    final p = progress.clamp(0.0, 1.0);
    if (p > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = progressColor;
      canvas.drawArc(rect, -pi / 2, p * 2 * pi, false, arc);
    }
  }

  @override
  bool shouldRepaint(covariant _BudgetRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.progressColor != progressColor;
}
/// “全部账目”筛选行：滚动时吸附在顶部
class _FinanceHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget Function() builder; // 每次 build 时调用，实时读取页面筛选状态

  _FinanceHeaderDelegate({required this.builder});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SizedBox(
        height: maxExtent,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: builder(),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 40;

  @override
  double get minExtent => 40;

  // 头部内容依赖页面 State（_financeMonthFilter）而非 Rx，
  // 无法精准判断变化，干脆始终重建以保证筛选状态实时反映
  @override
  bool shouldRebuild(covariant _FinanceHeaderDelegate oldDelegate) => true;
}