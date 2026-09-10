import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _initialized = false;

/// 初始化时区数据库并把 tz.local 设为设备本地时区（幂等）
Future<void> ensureTimezonesInitialized() async {
  if (_initialized) return;
  tzdata.initializeTimeZones();
  try {
    final name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));
  } catch (_) {
    // 获取失败时退化为东八区
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    } catch (_) {}
  }
  _initialized = true;
}
