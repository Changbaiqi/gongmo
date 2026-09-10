import 'package:get/get.dart';
import '../../modules/home/home_page.dart';
import '../../modules/lock/lock_page.dart';
import '../../modules/lock/pattern_setup_page.dart';
import '../../modules/more/exchange_rate_page.dart';
import '../../modules/more/invoice_page.dart';
import '../../modules/more/more_page.dart';
import '../../modules/more/salary_page.dart';
import '../../modules/splash/splash_page.dart';
import '../../modules/work/stopwatch_page.dart';
import '../../modules/work/time_more_page.dart';
import '../../modules/work/timezone_converter_page.dart';
import '../../modules/work/timezone_overlap_page.dart';
import '../../modules/work/work_page.dart';
import '../../modules/finance/finance_page.dart';
import '../../modules/sync/sync_page.dart';
import '../../modules/settings/settings_page.dart';
import 'app_routes.dart';

class AppPages {
  static final routes = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashPage(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.lock,
      page: () => const LockPage(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.patternSetup,
      page: () => const PatternSetupPage(),
    ),
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
    GetPage(
      name: AppRoutes.more,
      page: () => const MorePage(),
    ),
    GetPage(
      name: AppRoutes.invoice,
      page: () => const InvoicePage(),
    ),
    GetPage(
      name: AppRoutes.exchange,
      page: () => const ExchangeRatePage(),
    ),
    GetPage(
      name: AppRoutes.salary,
      page: () => const SalaryPage(),
    ),
    GetPage(
      name: AppRoutes.timeMore,
      page: () => const TimeMorePage(),
    ),
    GetPage(
      name: AppRoutes.stopwatch,
      page: () => const StopwatchPage(),
    ),
    GetPage(
      name: AppRoutes.timezones,
      page: () => const TimezoneOverlapPage(),
    ),
    GetPage(
      name: AppRoutes.tzConverter,
      page: () => const TimezoneConverterPage(),
    ),
  ];
}
