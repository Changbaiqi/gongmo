import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/theme/app_theme.dart';
import 'data/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('zh_CN');
  await StorageService().init();

  runApp(const GongMoApp());
}

class GongMoApp extends StatelessWidget {
  const GongMoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '工墨',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.dashboard,
      getPages: AppPages.routes,
    );
  }
}
