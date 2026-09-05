import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_controller.dart';
import 'data/services/storage_service.dart';
import 'modules/sync/sync_controller.dart';

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
  Get.put(ThemeController());
  Get.put(SyncController()); // 注册自动同步引擎

  runApp(const GongMoApp());
}

class GongMoApp extends StatelessWidget {
  const GongMoApp({super.key});

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
        initialRoute: AppRoutes.dashboard,
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
