// ============================================================
// 每日记账提醒服务（data/services）
// 职责：用本地通知在每天固定时间提醒记账（默认 21:00）
// 关联：StorageService（reminder_* 配置）、tz_setup（时区初始化）、
//       设置页与 main.dart 启动时确保调度存在
// ============================================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/tz_setup.dart';
import 'storage_service.dart';

/// 每日记账提醒：在设定时间发送本地通知（默认关闭）
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const _notifId = 1001;
  static const _testNotifId = 1002;
  static const _channelId = 'daily_bookkeeping_reminder';
  static const _kEnabled = 'reminder_enabled';
  static const _kHour = 'reminder_hour';
  static const _kMinute = 'reminder_minute';

  static const defaultHour = 21;
  static const defaultMinute = 0;

  /// 通知小图标：必须是不带透明背景的白色 drawable，
  /// 用 @mipmap/ic_launcher（自适应图标）会导致部分 ROM（如小米）通知发不出来
  static const _smallIcon = 'ic_stat_gongmo';

  final StorageService _storage = StorageService();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get enabled => _storage.getConfig(_kEnabled) == true;

  int get hour =>
      (_storage.getConfig(_kHour) as num?)?.toInt() ?? defaultHour;

  int get minute =>
      (_storage.getConfig(_kMinute) as num?)?.toInt() ?? defaultMinute;

  String get timeText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          '每日记账提醒',
          channelDescription: '每天定时提醒记录收支',
          importance: Importance.high,
          priority: Priority.high,
          icon: _smallIcon,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// 初始化通知插件与时区数据（幂等）
  Future<void> init() async {
    if (_initialized) return;
    await ensureTimezonesInitialized();
    const android = AndroidInitializationSettings(_smallIcon);
    const ios = DarwinInitializationSettings();
    try {
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
    } catch (_) {}
    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// 开关提醒
  Future<void> setEnabled(bool v) async {
    await _storage.setConfig(_kEnabled, v);
    if (v) {
      await scheduleDaily();
    } else {
      await cancel();
    }
  }

  /// 设置提醒时间（时/分）
  Future<void> setTime(int h, int m) async {
    await _storage.setConfig(_kHour, h);
    await _storage.setConfig(_kMinute, m);
    if (enabled) await scheduleDaily();
  }

  /// 精确闹钟是否可用（Android 12+ 需用户在系统设置中授权；
  /// 未授权时用非精确调度，小米等机型可能延迟较大）
  Future<bool> canScheduleExact() async {
    await init();
    try {
      final ok = await _android?.canScheduleExactNotifications();
      return ok ?? true;
    } catch (_) {
      return false;
    }
  }

  /// 申请精确闹钟权限（Android 12+ 会跳转系统设置页），返回是否已授权
  Future<bool> requestExactAlarmPermission() async {
    await init();
    try {
      final android = _android;
      if (android == null) return true;
      if (await android.canScheduleExactNotifications() ?? false) return true;
      await android.requestExactAlarmsPermission();
      return await android.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 调度每天固定时间的提醒
  Future<void> scheduleDaily() async {
    await init();
    await cancel();
    // 优先用精确闹钟：小米等 ROM 对非精确闹钟的延迟/拦截很激进
    final exact = await canScheduleExact();
    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    try {
      await _plugin.zonedSchedule(
        _notifId,
        '记得记账',
        '今天还没有记录账目，花一分钟记一笔吧',
        next,
        _details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  /// 立即发一条测试通知，用于确认通知权限与渠道是否正常
  Future<void> showTest() async {
    await init();
    try {
      await _plugin.show(
        _testNotifId,
        '记账提醒测试',
        '能看到这条通知说明提醒权限正常；若定时提醒仍未到，请检查系统「自启动」与省电策略。',
        _details,
      );
    } catch (_) {}
  }

  Future<void> cancel() async {
    await init();
    try {
      await _plugin.cancel(_notifId);
    } catch (_) {}
  }

  /// 申请通知权限（Android 13+ 需要）；返回是否已授权
  Future<bool> requestPermission() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        if (granted == false) return false;
      }
    } catch (_) {}
    return true;
  }
}
