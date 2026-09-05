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

  Future<void> _loadAll() async {
    _workEntries = await _loadList<WorkEntry>(
      'work_entries.json',
      (json) => WorkEntry.fromJson(json),
    );
    _financeEntries = await _loadList<FinanceEntry>(
      'finance_entries.json',
      (json) => FinanceEntry.fromJson(json),
    );
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

  Future<void> saveWorkEntries() =>
      _saveList('work_entries.json', _workEntries);
  Future<void> saveFinanceEntries() =>
      _saveList('finance_entries.json', _financeEntries);
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
    };
  }
}
