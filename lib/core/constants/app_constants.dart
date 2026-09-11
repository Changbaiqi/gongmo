// ============================================================
// 应用常量（core/constants）
// 职责：集中定义全局共享常量（应用信息、数据目录/文件名、GitHub API 地址）
// 关联：StorageService（config.json 等文件名）、GithubSyncService（API 地址）
// ============================================================

/// 应用级常量集合，避免各模块散落硬编码
class AppConstants {
  static const String appName = '工墨';
  static const String appVersion = '1.0.0';

  /// 本地数据目录名（位于应用私有 Documents 下，见 StorageService.init）
  static const String dataDirName = 'gongmo_data';

  /// 旧版单文件文件名；现数据已按年分片（work_entries_2026.json 等），
  /// 这两个名字仅用于旧数据迁移识别
  static const String workFile = 'work_entries.json';
  static const String financeFile = 'finance_entries.json';

  static const String categoriesFile = 'categories.json';
  static const String accountsFile = 'accounts.json';

  /// 轻量配置文件名（主题、GitHub、提醒等键值，见 StorageService）
  static const String configFile = 'config.json';

  /// 预留：自动同步间隔常量（当前自动同步由 SyncController 的 6 秒防抖驱动）
  static const Duration autoSyncInterval = Duration(minutes: 15);

  /// 预留：网络失败重试次数
  static const int maxRetries = 3;

  /// GitHub REST API 根地址（Contents API 备份/恢复使用）
  static const String githubApiBase = 'https://api.github.com';
}
