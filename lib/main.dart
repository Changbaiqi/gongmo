// ============================================================
// 应用入口（lib/main.dart）
// 职责：初始化存储/主题/应用锁/同步/提醒/自动记账等全局单例，
//       构建 GetMaterialApp，并监听前后台切换实现回前台自动重锁
// 关联：StorageService、ThemeController、LockController、SyncController、
//       ReminderService、AutoBookkeepingService
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_controller.dart';
import 'data/services/auto_bookkeeping_service.dart';
import 'data/services/reminder_service.dart';
import 'data/services/storage_service.dart';
import 'modules/lock/lock_controller.dart';
import 'modules/sync/sync_controller.dart';

/// 应用启动流程（顺序有意义）：
/// 1. 锁定竖屏 + 透明状态栏；
/// 2. 初始化中文日期格式与本地存储；
/// 3. 消费后台引擎（通知监听）在 App 关闭期间写入的自动记账队列；
/// 4. 注册主题/应用锁/同步控制器；
/// 5. 恢复每日提醒调度、按开关启动通知监听服务；
/// 最后 runApp。任何一步失败都不应阻塞启动（关键处已有容错）。
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  await initializeDateFormatting('zh_CN');
  final storage = StorageService();
  await storage.init();
  // 启动时处理自动记账队列（后台引擎在 App 关闭期间捕获的收支）
  await AutoBookkeepingService.instance.processQueue();
  Get.put(ThemeController());
  final lock = Get.put(LockController(), permanent: true); // 应用锁（图案/指纹）
  await lock.init();
  Get.put(SyncController()); // 注册自动同步引擎
  // 每日记账提醒：启动时确保定时调度存在
  try {
    await ReminderService.instance.init();
    if (ReminderService.instance.enabled) {
      await ReminderService.instance.scheduleDaily();
    }
  } catch (_) {}
  AutoBookkeepingService.instance.startIfNeeded(); // 若开关开启则启动监听服务

  runApp(const GongMoApp());
}

/// 根组件：用 Obx 监听主题变化构建 MaterialApp，
/// 并作为 WidgetsBindingObserver 处理前后台生命周期
class GongMoApp extends StatefulWidget {
  const GongMoApp({super.key});

  @override
  State<GongMoApp> createState() => _GongMoAppState();
}

class _GongMoAppState extends State<GongMoApp> with WidgetsBindingObserver {
  /// 应用进入后台的时刻；回到前台时用于判断是否超过重锁间隔
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 前后台切换：后台记录时间；回前台若超过 LockController 的重锁间隔，
  /// 且当前不在锁屏/启动页时，跳转到解锁页
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt == null) return;
      final lock = Get.find<LockController>();
      if (!lock.needsRelock) return;
      final route = Get.currentRoute;
      if (route == AppRoutes.lock || route == AppRoutes.splash) return;
      Get.toNamed(AppRoutes.lock);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = Get.find<ThemeController>();
    return Obx(() {
      final preset = tc.preset.value;
      final useBackground = tc.hasBackground;
      return GetMaterialApp(
        title: '工墨',
        theme: AppTheme.build(
          brightness: Brightness.light,
          preset: preset,
          background: useBackground,
        ),
        darkTheme: AppTheme.build(
          brightness: Brightness.dark,
          preset: preset,
          background: useBackground,
        ),
        themeMode: tc.mode.value,
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        initialRoute: AppRoutes.splash,
        getPages: AppPages.routes,
        builder: useBackground
            ? (context, child) => _AppBackground(
                  path: tc.backgroundPath.value,
                  child: child,
                )
            : null,
      );
    });
  }
}

/// 自定义背景图：铺在所有路由之下
class _AppBackground extends StatelessWidget {
  final String path;
  final Widget? child;

  const _AppBackground({required this.path, this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(path),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        if (child != null) child!,
      ],
    );
  }
}
