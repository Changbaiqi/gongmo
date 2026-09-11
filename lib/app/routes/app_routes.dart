// ============================================================
// 路由常量（app/routes）
// 职责：集中定义所有页面的命名路由路径
// 关联：AppPages.routes（路由表）、main.dart（initialRoute）、各处 Get.toNamed
// ============================================================

/// 路由路径常量。
///
/// 命名说明：[dashboard] 为历史命名，实际指向 '/'（主界面 HomePage），
/// 独立的 DashboardPage 未注册路由；[work]、[finance] 是从主界面内嵌页面
/// 拆分出的独立路由，当前保留备用。
class AppRoutes {
  static const String splash = '/splash';
  static const String lock = '/lock';
  static const String patternSetup = '/pattern-setup';
  static const String dashboard = '/';
  static const String work = '/work';
  static const String finance = '/finance';
  static const String sync = '/sync';
  static const String settings = '/settings';
  static const String more = '/more';
  static const String timeMore = '/time-more';
  static const String stopwatch = '/stopwatch';
  static const String timezones = '/timezones';
  static const String tzConverter = '/tz-converter';
  static const String invoice = '/invoice';
  static const String exchange = '/exchange';
  static const String salary = '/salary';
}
