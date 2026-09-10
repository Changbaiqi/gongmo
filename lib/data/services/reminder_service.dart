import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/tz_setup.dart';
import 'storage_service.dart';

/// 每日记账提醒：在设定时间发送本地通知（默认关闭）
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const _notifId = 1001;
  static const _kEnabled = 'reminder_enabled';
  static const _kHour = 'reminder_hour';
  static const _kMinute = 'reminder_minute';

  static const defaultHour = 21;
  static const defaultMinute = 0;

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

  Future<void> init() async {
    if (_initialized) return;
    await ensureTimezonesInitialized();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    try {
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
    } catch (_) {}
    _initialized = true;
  }

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

  /// 调度每天固定时间的提醒
  Future<void> scheduleDaily() async {
    await init();
    await cancel();
    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_bookkeeping_reminder',
        '每日记账提醒',
        channelDescription: '每天定时提醒记录收支',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.zonedSchedule(
        _notifId,
        '记得记账',
        '今天还没有记录账目，花一分钟记一笔吧',
        next,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        // 用非精确调度：无需申请精确闹钟权限，提醒晚几分钟无影响
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
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
