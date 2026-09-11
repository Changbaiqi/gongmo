// ============================================================
// 通知自动记账服务（data/services）
// 职责：监听支付宝/微信/招商银行通知，解析收支金额并生成账目
// 关联：flutter_notification_listener 后台引擎（写队列 auto_queue.json）、
//       FinanceRepository（主引擎消费队列入账）、SettingsController（开关）
// ============================================================

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
    SupportedApp('wechat', '微信', 'com.tencent.mm'),
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

  /// 是否自动记录退款（默认开启）
  bool get refundEnabled => _storage.getConfig('auto_refund') != false;

  /// 是否已授予「通知使用权限」（监听通知的前提）
  Future<bool> hasPermission() async =>
      await NotificationsListener.hasPermission ?? false;

  /// 监听服务是否正在运行
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

  /// 停止监听（关闭开关时调用）
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
      // 仅当配置中显式关闭该应用时才忽略（新增应用默认开启）
      if (raw is Map && raw.containsKey(app.key) && raw[app.key] != true) {
        return;
      }

      final title = (evt.title ?? '').trim();
      final text = (evt.text ?? '').trim();
      final message = (evt.message ?? '').trim();
      // 有的通知正文只在 title / message（大文本）里，合并后再解析
      final full = '$title $text $message'.trim();
      if (full.isEmpty) return;

      // 微信：仅处理通知中带"微信"来源字样（标题通常为"微信支付"）的
      // 支付/收款通知，避免把聊天消息误记账
      if (app.key == 'wechat' &&
          !title.contains('微信') &&
          !text.contains('微信')) {
        return;
      }

      final parsed = parseNotification(app.key, full);
      if (parsed == null) return;
      final (type, amount, merchant) = parsed;

      // 退款：按开关决定是否记录
      final isRefund = full.contains('退款') || full.contains('退回');
      if (isRefund && !refundEnabled) return;

      // 去重：同一笔交易常发多条通知（横幅 + 常驻）
      final dedupKey =
          '$pkg|$full|${DateTime.now().millisecondsSinceEpoch ~/ 60000}';
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
        description: isRefund
            ? '自动记账 · 退款'
            : merchant != null
                ? '自动记账 · $merchant'
                : '自动记账 · ${app.name}',
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

  /// 解析应用通知文本，返回 (类型, 金额, 商户名?)
  static (FinanceType, double, String?)? parseNotification(
      String appKey, String text) {
    if (appKey == 'cmb') {
      // 招商银行：如"您尾号9058的账户入账人民币1.00元"
      final income =
          RegExp(r'入账人民币\s*([0-9]+(?:\.[0-9]+)?)\s*元').firstMatch(text);
      if (income != null) {
        final v = double.tryParse(income.group(1) ?? '');
        if (v != null && v > 0 && v < _maxAmount) {
          return (FinanceType.income, v, null);
        }
      }
      final expense = RegExp(r'(?:支出|消费)人民币\s*([0-9]+(?:\.[0-9]+)?)\s*元')
          .firstMatch(text);
      if (expense != null) {
        final v = double.tryParse(expense.group(1) ?? '');
        if (v != null && v > 0 && v < _maxAmount) {
          return (FinanceType.expense, v, null);
        }
      }
      return null;
    }
    if (appKey == 'wechat') return parseWechat(text);
    return parseAlipay(text);
  }

  /// 解析微信支付/收款通知，返回 (类型, 金额, 商户名?)
  ///
  /// 常见文案：
  /// - 支出："已支付￥24.81" / "已成功支付24.81元" / "向XX付款￥24.81"
  /// - 收入："微信支付收款12.34元" / "已收款￥24.81"
  static (FinanceType, double, String?)? parseWechat(String text) {
    // 支出（带商户名）：向 XX 付款/支付/转账 ￥xx
    final toMerchant =
        RegExp(r'向(.{1,30}?)(?:付款|支付|转账)\s*[￥¥]?\s*([0-9]+(?:\.[0-9]+)?)')
            .firstMatch(text);
    if (toMerchant != null) {
      final v = double.tryParse(toMerchant.group(2) ?? '');
      if (v != null && v > 0 && v < _maxAmount) {
        return (FinanceType.expense, v, toMerchant.group(1)?.trim());
      }
    }
    // 支出：已支付￥24.81 / 支付成功 ¥24.81 / 已成功支付24.81元
    for (final re in [
      RegExp(
          r'(?:已支付|支付成功|付款成功|已付款|支付)[：:\s]*[￥¥]\s*([0-9]+(?:\.[0-9]+)?)'),
      RegExp(r'[￥¥]\s*([0-9]+(?:\.[0-9]+)?)\s*(?:已支付|支付成功)'),
      RegExp(r'已(?:成功)?(?:支付|付款|转账)\s*([0-9]+(?:\.[0-9]+)?)\s*元'),
    ]) {
      final m = re.firstMatch(text);
      if (m != null) {
        final v = double.tryParse(m.group(1) ?? '');
        if (v != null && v > 0 && v < _maxAmount) {
          return (FinanceType.expense, v, null);
        }
      }
    }
    // 退款：如"微信支付退款到账￥24.81" / "退款￥24.81已原路退回"
    if ((text.contains('退款') || text.contains('退回')) &&
        !text.contains('失败')) {
      for (final re in [
        RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*元的?退款'),
        RegExp(r'退款[^0-9]{0,8}[￥¥]?\s*([0-9]+(?:\.[0-9]+)?)'),
        RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*元[^0-9]{0,8}(?:原路退回|已退回)'),
        RegExp(r'[￥¥]\s*([0-9]+(?:\.[0-9]+)?)[^0-9]{0,8}(?:退款|退回)'),
      ]) {
        final m = re.firstMatch(text);
        if (m != null) {
          final v = double.tryParse(m.group(1) ?? '');
          if (v != null && v > 0 && v < _maxAmount) {
            return (FinanceType.income, v, null);
          }
        }
      }
      // 兜底：含退款字样且能取到 "X元" 的金额
      final m = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*元').firstMatch(text);
      if (m != null) {
        final v = double.tryParse(m.group(1) ?? '');
        if (v != null && v > 0 && v < _maxAmount) {
          return (FinanceType.income, v, null);
        }
      }
    }
    // 收入（带对方名）：已收到 XX 的转账/红包/收款 ￥xx
    final fromOthers = RegExp(
            r'(?:已收到|收到)(.{1,30}?)的(?:转账|付款|红包|收款)\s*[￥¥]?\s*([0-9]+(?:\.[0-9]+)?)')
        .firstMatch(text);
    if (fromOthers != null) {
      final v = double.tryParse(fromOthers.group(2) ?? '');
      if (v != null && v > 0 && v < _maxAmount) {
        return (FinanceType.income, v, fromOthers.group(1)?.trim());
      }
    }
    // 收入：微信支付收款12.34元 / 已收款￥24.81 / 收款到账24.81元
    for (final re in [
      RegExp(
          r'(?:已收款|收款到账|收款成功|已到账|入账)\s*[￥¥]?\s*([0-9]+(?:\.[0-9]+)?)'),
      RegExp(r'收款\s*([0-9]+(?:\.[0-9]+)?)\s*元'),
      RegExp(r'[￥¥]\s*([0-9]+(?:\.[0-9]+)?)\s*(?:已收款|收款到账|已到账)'),
    ]) {
      final m = re.firstMatch(text);
      if (m != null) {
        final v = double.tryParse(m.group(1) ?? '');
        if (v != null && v > 0 && v < _maxAmount) {
          return (FinanceType.income, v, null);
        }
      }
    }
    return null;
  }

  /// 解析支付宝通知文本，返回 (类型, 金额, 商户名?)
  static (FinanceType, double, String?)? parseAlipay(String text) {
    // 去掉千分位，避免 "1,234.50元" 只匹配到 "234.50"
    final t = text.replaceAll(',', '');
    // 免密/自动扣款：如"你在luckincoffee有一笔16.9元的免密/自动扣款支付"
    final deduct = RegExp(
            r'在(.{1,30}?)有一笔([0-9]+(?:\.[0-9]+)?)元的免密(?:/自动)?扣款')
        .firstMatch(t);
    if (deduct != null) {
      final v = double.tryParse(deduct.group(2) ?? '');
      if (v != null && v > 0 && v < _maxAmount) {
        return (FinanceType.expense, v, deduct.group(1));
      }
    }
    // 支出：金额在关键词之前，如"你有一笔1.50元的支出，领立减1.08元权益。"
    for (final re in [
      RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*元(?:的)?(?:支出|消费|付款|扣款|交易|账单)'),
      // 关键词在金额之前，如"支出1.50元" / "消费人民币1.50元"
      RegExp(
          r'(?:支出|消费|付款|扣款|已支付|支付)\s*(?:人民币)?\s*([0-9]+(?:\.[0-9]+)?)\s*元'),
    ]) {
      final m = re.firstMatch(t);
      if (m != null) {
        final v = double.tryParse(m.group(1) ?? '');
        if (v != null && v > 0 && v < _maxAmount) {
          return (FinanceType.expense, v, null);
        }
      }
    }
    // 退款：如"你有一笔1.50元的退款" / "你收到一笔16.9元退款，点击查看账单详情！"
    if ((t.contains('退款') || t.contains('退回')) && !t.contains('失败')) {
      for (final re in [
        RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*元的?退款'),
        RegExp(r'退款[^0-9]{0,8}[￥¥]?\s*([0-9]+(?:\.[0-9]+)?)'),
        RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*元[^0-9]{0,8}(?:原路退回|已退回)'),
        RegExp(r'[￥¥]\s*([0-9]+(?:\.[0-9]+)?)[^0-9]{0,8}(?:退款|退回)'),
      ]) {
        final m = re.firstMatch(t);
        if (m != null) {
          final v = double.tryParse(m.group(1) ?? '');
          if (v != null && v > 0 && v < _maxAmount) {
            return (FinanceType.income, v, null);
          }
        }
      }
      // 兜底：含退款字样且能取到 "X元" 的金额
      final m = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*元').firstMatch(t);
      if (m != null) {
        final v = double.tryParse(m.group(1) ?? '');
        if (v != null && v > 0 && v < _maxAmount) {
          return (FinanceType.income, v, null);
        }
      }
    }
    // 收入
    for (final re in [
      RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*元(?:的)?(?:收入|收款|入账|退款)'),
      RegExp(r'成功收款\s*([0-9]+(?:\.[0-9]+)?)\s*元'),
      RegExp(r'(?:收款|入账|退款|收入)\s*([0-9]+(?:\.[0-9]+)?)\s*元'),
      RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*元的转账'),
    ]) {
      final m = re.firstMatch(t);
      if (m != null) {
        final v = double.tryParse(m.group(1) ?? '');
        if (v != null && v > 0 && v < _maxAmount) {
          return (FinanceType.income, v, null);
        }
      }
    }
    return null;
  }
}
