import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../models/work_entry.dart';
import '../models/finance_entry.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../models/timer_tag.dart';

class StorageService {
  static final StorageService _instance = StorageService._();
  factory StorageService() => _instance;
  StorageService._();

  late Directory _dataDir;
  bool _initialized = false;

  List<WorkEntry> _workEntries = [];
  List<FinanceEntry> _financeEntries = [];
  List<Category> _categories = [];
  List<Account> _accounts = [];
  List<TimerTag> _timerTags = [];
  Map<String, dynamic> _config = {};

  List<WorkEntry> get workEntries => _workEntries;
  List<FinanceEntry> get financeEntries => _financeEntries;
  List<Category> get categories => _categories;
  List<Account> get accounts => _accounts;
  List<TimerTag> get timerTags => _timerTags;

  Future<void> init() async {
    if (_initialized) return;
    final appDir = await getApplicationDocumentsDirectory();
    _dataDir = Directory('${appDir.path}/gongmo_data');
    if (!await _dataDir.exists()) {
      await _dataDir.create(recursive: true);
    }
    await _loadAll();
    _initialized = true;
  }

  static const _workPrefix = 'work_entries';
  static const _financePrefix = 'finance_entries';

  Future<void> _loadAll() async {
    // 按年分片加载：work_entries_2025.json / work_entries_2026.json ...
    _workEntries =
        await _loadYearSplit<WorkEntry>(_workPrefix, WorkEntry.fromJson);
    _financeEntries = await _loadYearSplit<FinanceEntry>(
        _financePrefix, FinanceEntry.fromJson);
    // 旧版本单文件自动迁移到分片
    await _migrateLegacy();
    _categories = await _loadList<Category>(
      'categories.json',
      (json) => Category.fromJson(json),
    );
    _accounts = await _loadList<Account>(
      'accounts.json',
      (json) => Account.fromJson(json),
    );
    _timerTags = await _loadList<TimerTag>(
      'timer_tags.json',
      (json) => TimerTag.fromJson(json),
    );

    if (_categories.isEmpty) {
      _categories = [
        ...Category.defaultIncomeCategories(),
        ...Category.defaultExpenseCategories(),
      ];
      await _saveList('categories.json', _categories);
    }
    if (_accounts.isEmpty) {
      _accounts = Account.defaultAccounts();
      await _saveList('accounts.json', _accounts);
    }
    if (_timerTags.isEmpty) {
      _timerTags = TimerTag.defaults();
      await _saveList('timer_tags.json', _timerTags);
    }
    await _loadConfig();
  }

  /// 旧版本单文件迁移到按年分片后删除
  Future<void> _migrateLegacy() async {
    final legacyFiles = {
      '$_workPrefix.json': false, // false → 计时记录
      '$_financePrefix.json': true, // true → 账目记录
    };
    for (final entry in legacyFiles.entries) {
      final file = File('${_dataDir.path}/${entry.key}');
      if (!await file.exists()) continue;
      try {
        final content = await file.readAsString();
        final list = json.decode(content) as List<dynamic>;
        final maps = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (entry.value) {
          final ids = _financeEntries.map((e) => e.id).toSet();
          _financeEntries.addAll(maps
              .map((e) => FinanceEntry.fromJson(e))
              .where((e) => !ids.contains(e.id)));
          await saveFinanceEntries();
        } else {
          final ids = _workEntries.map((e) => e.id).toSet();
          _workEntries.addAll(maps
              .map((e) => WorkEntry.fromJson(e))
              .where((e) => !ids.contains(e.id)));
          await saveWorkEntries();
        }
        await file.delete();
      } catch (_) {
        // 迁移失败时保留原文件，下次启动重试
      }
    }
  }

  /// 按年分片加载
  Future<List<T>> _loadYearSplit<T>(
    String prefix,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final result = <T>[];
    try {
      for (final entity in _dataDir.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('${prefix}_') || !name.endsWith('.json')) continue;
        final yearStr = name.substring(prefix.length + 1, name.length - 5);
        if (int.tryParse(yearStr) == null) continue;
        try {
          final content = await entity.readAsString();
          final list = json.decode(content) as List<dynamic>;
          result.addAll(list.map((e) => fromJson(e as Map<String, dynamic>)));
        } catch (_) {
          // 单个分片损坏时跳过，不影响其他年份数据
        }
      }
    } catch (_) {}
    return result;
  }

  /// 读取轻量配置项（存储在 config.json）
  dynamic getConfig(String key) => _config[key];

  /// 写入轻量配置项
  Future<void> setConfig(String key, dynamic value) async {
    _config[key] = value;
    final file = File('${_dataDir.path}/${AppConstants.configFile}');
    await file.writeAsString(json.encode(_config));
  }

  Future<void> _loadConfig() async {
    final file = File('${_dataDir.path}/${AppConstants.configFile}');
    if (!await file.exists()) return;
    try {
      final content = await file.readAsString();
      final decoded = json.decode(content);
      if (decoded is Map<String, dynamic>) {
        _config = decoded;
      }
    } catch (_) {
      _config = {};
    }
  }

  Future<List<T>> _loadList<T>(
    String filename,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final file = File('${_dataDir.path}/$filename');
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content) as List<dynamic>;
      return jsonList.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveList(String filename, List<dynamic> list) async {
    final file = File('${_dataDir.path}/$filename');
    final jsonStr =
        json.encode(list.map((e) => (e as dynamic).toJson()).toList());
    await file.writeAsString(jsonStr);
  }

  Future<void> saveWorkEntries() => _saveYearSplit<WorkEntry>(
        _workPrefix,
        _workEntries,
        (e) => e.startTime.year,
        (e) => e.toJson(),
      );

  Future<void> saveFinanceEntries() => _saveYearSplit<FinanceEntry>(
        _financePrefix,
        _financeEntries,
        (e) => e.date.year,
        (e) => e.toJson(),
      );
  Future<void> saveCategories() => _saveList('categories.json', _categories);
  Future<void> saveAccounts() => _saveList('accounts.json', _accounts);
  Future<void> saveTimerTags() => _saveList('timer_tags.json', _timerTags);

  void addWorkEntry(WorkEntry entry) {
    _workEntries.add(entry);
    saveWorkEntries();
  }

  void updateWorkEntry(WorkEntry entry) {
    final index = _workEntries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _workEntries[index] = entry;
      saveWorkEntries();
    }
  }

  void removeWorkEntry(String id) {
    _workEntries.removeWhere((e) => e.id == id);
    saveWorkEntries();
  }

  void addFinanceEntry(FinanceEntry entry) {
    _financeEntries.add(entry);
    saveFinanceEntries();
  }

  void updateFinanceEntry(FinanceEntry entry) {
    final index = _financeEntries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _financeEntries[index] = entry;
      saveFinanceEntries();
    }
  }

  void removeFinanceEntry(String id) {
    _financeEntries.removeWhere((e) => e.id == id);
    saveFinanceEntries();
  }

  void addCategory(Category category) {
    _categories.add(category);
    saveCategories();
  }

  void updateCategory(Category category) {
    final index = _categories.indexWhere((e) => e.id == category.id);
    if (index != -1) {
      _categories[index] = category;
      saveCategories();
    }
  }

  void removeCategory(String id) {
    _categories.removeWhere((e) => e.id == id);
    saveCategories();
  }

  void addAccount(Account account) {
    _accounts.add(account);
    saveAccounts();
  }

  void removeAccount(String id) {
    _accounts.removeWhere((e) => e.id == id);
    saveAccounts();
  }

  void addTimerTag(TimerTag tag) {
    _timerTags.add(tag);
    saveTimerTags();
  }

  void updateTimerTag(TimerTag tag) {
    final index = _timerTags.indexWhere((e) => e.id == tag.id);
    if (index != -1) {
      _timerTags[index] = tag;
      saveTimerTags();
    }
  }

  void removeTimerTag(String id) {
    _timerTags.removeWhere((e) => e.id == id);
    saveTimerTags();
  }

  Map<String, dynamic> exportAllData() {
    return {
      'workEntries': _workEntries.map((e) => e.toJson()).toList(),
      'financeEntries': _financeEntries.map((e) => e.toJson()).toList(),
      'categories': _categories.map((e) => e.toJson()).toList(),
      'accounts': _accounts.map((e) => e.toJson()).toList(),
      'timerTags': _timerTags.map((e) => e.toJson()).toList(),
    };
  }

  /// 按年分片保存：每个年份一个文件（work_entries_2026.json），
  /// 单个文件体量可控；无数据的年份分片会被清理
  Future<void> _saveYearSplit<T>(
    String prefix,
    List<T> items,
    int Function(T) yearOf,
    Map<String, dynamic> Function(T) toJ,
  ) async {
    final byYear = <int, List<Map<String, dynamic>>>{};
    for (final item in items) {
      byYear.putIfAbsent(yearOf(item), () => []).add(toJ(item));
    }
    // 清理已无数据的年份分片
    try {
      for (final entity in _dataDir.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('${prefix}_') || !name.endsWith('.json')) continue;
        final yearStr = name.substring(prefix.length + 1, name.length - 5);
        final year = int.tryParse(yearStr);
        if (year == null || !byYear.containsKey(year)) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
    for (final entry in byYear.entries) {
      final file = File('${_dataDir.path}/${prefix}_${entry.key}.json');
      await file.writeAsString(json.encode(entry.value));
    }
  }

  /// 按年份导出数据（用于分片备份，避免单文件超过 GitHub 100MB 限制）
  Map<int, Map<String, dynamic>> exportDataByYear() {
    final years = <int>{};
    for (final e in _workEntries) {
      years.add(e.startTime.year);
    }
    for (final f in _financeEntries) {
      years.add(f.date.year);
    }
    final result = <int, Map<String, dynamic>>{};
    for (final y in years) {
      result[y] = {
        'workEntries': _workEntries
            .where((e) => e.startTime.year == y)
            .map((e) => e.toJson())
            .toList(),
        'financeEntries': _financeEntries
            .where((f) => f.date.year == y)
            .map((f) => f.toJson())
            .toList(),
      };
    }
    return result;
  }

  /// 估算本地数据总量（字节），用于体积监控
  int estimateDataSize() {
    var bytes = 0;
    for (final e in _workEntries) {
      bytes += json.encode(e.toJson()).length;
    }
    for (final f in _financeEntries) {
      bytes += json.encode(f.toJson()).length;
    }
    return bytes;
  }

  /// 用备份数据整体覆盖本地数据（空列表保留本地默认值）
  Future<void> restoreAllData({
    required List<WorkEntry> workEntries,
    required List<FinanceEntry> financeEntries,
    required List<Category> categories,
    required List<Account> accounts,
    required List<TimerTag> timerTags,
  }) async {
    _workEntries = workEntries;
    _financeEntries = financeEntries;
    if (categories.isNotEmpty) _categories = categories;
    if (accounts.isNotEmpty) _accounts = accounts;
    if (timerTags.isNotEmpty) _timerTags = timerTags;
    await saveWorkEntries();
    await saveFinanceEntries();
    await saveCategories();
    await saveAccounts();
    await saveTimerTags();
  }
}
