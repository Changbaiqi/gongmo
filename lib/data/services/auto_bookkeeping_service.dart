import 'dart:async';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:uuid/uuid.dart';
import '../models/finance_entry.dart';
import '../repositories/finance_repository.dart';
import 'storage_service.dart';

/// 插件要求：事件回调必须为顶层函数（后台引擎通过 CallbackHandle 调用）。
/// 事件运行在服务的后台引擎中，因此这里只把解析结果写入队列文件，
/// 由主引擎（App 启动/回到前台时）处理入账，避免多引擎写文件互相覆盖。
@pragma('vm:entry-point')
Future<void> autoBookkeepingNotificationHandler(NotificationEvent evt) async {
  await AutoBookkeepingService.instance.handleEvent(evt);
}

/// 支持自动记账的应用
class SupportedApp {
  final String key;
  final String name;
  final String packageName;
  const SupportedApp(this.key, this.name, this.packageName);
}

/// 自动记账服务
///
/// 通过 Android 通知使用权限监听支付宝/招商银行等应用的通知，
/// 解析其中的收支金额后自动创建账目。
/// 依赖常驻前台服务（通知监听服务）以保证后台可用。
class AutoBookkeepingService {
  AutoBookkeepingService._();
  static final AutoBookkeepingService instance = AutoBookkeepingService._();

  static const _maxAmount = 1000000.0;
  static const _dedupeKeep = 60;

  /// 目前支持的应用（key 对应 config.json 中 auto_apps 的开关键）
  static const supportedApps = <SupportedApp>[
    SupportedApp('alipay', '支付宝', 'com.eg.android.AlipayGphone'),
    SupportedApp('cmb', '招商银行', 'com.cmbchina.ccd.pluto.cmbActivity'),
  ];

  SupportedApp? _appByPackage(String pkg) {
    for (final a in supportedApps) {
      if (a.packageName == pkg) return a;
    }
    return null;
  }

  final StorageService _storage = StorageService();
  final FinanceRepository _financeRepo = FinanceRepository();
  final _uuid = const Uuid();
  bool _listening = false;

  bool get enabled => _storage.getConfig('auto_accounting') == true;

  Future<bool> hasPermission() async =>
      await NotificationsListener.hasPermission ?? false;

  Future<bool> isRunning() async =>
      _listening && (await NotificationsListener.isRunning ?? false);

  /// 应用启动时调用：开关开启则确保监听服务运行，并处理待入队账目
  Future<void> startIfNeeded() async {
    if (!enabled) return;
    await processQueue();
    try {
      await start();
    } catch (_) {}
  }

  /// 开启监听（需已授予通知使用权限）
  Future<void> start() async {
    if (_listening) return;
    await NotificationsListener.initialize(
      callbackHandle: autoBookkeepingNotificationHandler,
    );
    await NotificationsListener.registerEventHandle(
        autoBookkeepingNotificationHandler);
    await NotificationsListener.startService(
      foreground: true,
      title: '工墨自动记账',
      subTitle: '正在监听通知并自动记录收支',
      showWhen: false,
    );
    _listening = true;
  }

  Future<void> stop() async {
    _listening = false;
    try {
      await NotificationsListener.stopService();
    } catch (_) {}
  }

  /// 处理一条通知事件（运行在后台引擎）
  Future<void> handleEvent(NotificationEvent evt) async {
    try {
      await _storage.init(); // 后台引擎中需要自行初始化存储
      await _storage.reloadConfig(); // 读取最新的开关设置
      if (!enabled) return;

      // 按包名匹配支持的应用，并检查该应用的独立开关
      final pkg = evt.packageName ?? '';
      SupportedApp? app = _appByPackage(pkg);
      if (app == null) return;
      final raw = _storage.getConfig('auto_apps');
      if (raw is Map && raw[app.key] != true) return;

      final text = (evt.text ?? '').trim();
      if (text.isEmpty) return;

      final parsed = parseNotification(app.key, text);
      if (parsed == null) return;
      final (type, amount) = parsed;

      // 去重：同一笔交易常发多条通知（横幅 + 常驻）
      final dedupKey =
          '$pkg|$text|${DateTime.now().millisecondsSinceEpoch ~/ 60000}';
      final queue = await _storage.readAutoQueue();
      if (queue.any((e) => e['dedupKey'] == dedupKey)) return;
      while (queue.length >= _dedupeKeep) {
        queue.removeAt(0);
      }
      final entry = FinanceEntry(
        id: _uuid.v4(),
        type: type,
        amount: amount,
        categoryId: type == FinanceType.expense ? 'exp_5' : 'inc_3',
        description: '自动记账 · ${app.name}',
        date: DateTime.now(),
        notificationSrc: app.key,
      );
      final map = entry.toJson();
      map['dedupKey'] = dedupKey;
      queue.add(map);
      await _storage.writeAutoQueue(queue);
    } catch (_) {
      // 单条通知处理失败不影响监听
    }
  }

  /// 主引擎：处理待入队账目（覆盖本地数据，随自动同步/手动同步上传）
  Future<void> processQueue() async {
    await _storage.init();
    final queue = await _storage.readAutoQueue();
    if (queue.isEmpty) return;
    await _storage.writeAutoQueue(const []);
    for (final map in queue) {
      try {
        final entry = FinanceEntry.fromJson(map);
        _financeRepo.save(entry);
      } catch (_) {}
    }
  }

  /// 解析应用通知文本，返回 (类型, 金额)
  static (FinanceType, double)? parseNotification(String appKey, String text) {
    if (appKey == 'cmb') {
      // 招商银行：如"您尾号9058的账户入账人民币1.00元"
      final income =
          RegExp(r'入账人民币\s*([0-9]+(?:\.[0-9]+)?)\s*元').firstMatch(text);
      if (income != null) {
        final v = double.tryParse(income.group(1) ?? '');
        if (v != null && v > 0 && v < _maxAmount) {
          return (FinanceType.income, v);
        }
      }
      final expense = RegExp(r'(?:支出|消费)人民币\s*([0-9]+(?:\.[0-9]+)?)\s*元')
          .firstMatch(text);
      if (expense != null) {
        final v = double.tryParse(expense.group(1) ?? '');
        if (v != null && v > 0 && v < _maxAmount) {
          return (FinanceType.expense, v);
        }
      }
      return null;
    }
    return parseAlipay(text);
  }

  /// 解析支付宝通知文本，返回 (类型, 金额)
  static (FinanceType, double)? parseAlipay(String text) {
    final expense =
        RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*元(?:的)?支出').firstMatch(text);
    if (expense != null) {
      final v = double.tryParse(expense.group(1) ?? '');
      if (v != null && v > 0 && v < _maxAmount) {
        return (FinanceType.expense, v);
      }
    }
    final income = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*元(?:的)?收入')
            .firstMatch(text) ??
        RegExp(r'成功收款\s*([0-9]+(?:\.[0-9]+)?)\s*元').firstMatch(text) ??
        RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*元的转账').firstMatch(text);
    if (income != null) {
      final v = double.tryParse(income.group(1) ?? '');
      if (v != null && v > 0 && v < _maxAmount) {
        return (FinanceType.income, v);
      }
    }
    return null;
  }
}
