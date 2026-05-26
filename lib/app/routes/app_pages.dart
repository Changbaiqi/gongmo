import 'package:get/get.dart';
import '../../modules/home/home_page.dart';
import '../../modules/work/work_page.dart';
import '../../modules/finance/finance_page.dart';
import '../../modules/sync/sync_page.dart';
import '../../modules/settings/settings_page.dart';
import 'app_routes.dart';

class AppPages {
  static final routes = [
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const HomePage(),
    ),
    GetPage(
      name: AppRoutes.work,
      page: () => const WorkPage(),
    ),
    GetPage(
      name: AppRoutes.finance,
      page: () => const FinancePage(),
    ),
    GetPage(
      name: AppRoutes.sync,
      page: () => const SyncPage(),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsPage(),
    ),
  ];
}
