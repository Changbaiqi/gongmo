class AppConstants {
  static const String appName = '工墨';
  static const String appVersion = '1.0.0';

  static const String dataDirName = 'gongmo_data';
  static const String workFile = 'work_entries.json';
  static const String financeFile = 'finance_entries.json';
  static const String categoriesFile = 'categories.json';
  static const String accountsFile = 'accounts.json';
  static const String configFile = 'config.json';

  static const Duration autoSyncInterval = Duration(minutes: 15);
  static const int maxRetries = 3;
  static const String githubApiBase = 'https://api.github.com';
}
