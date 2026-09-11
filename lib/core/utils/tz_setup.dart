// ============================================================
// 时区数据库初始化（core/utils）
// 职责：幂等地初始化 timezone 数据库，并把 tz.local 设为设备当前时区
// 关联：ReminderService（本地通知定时依赖 tz.local）、时区转换/重叠工具页
// ============================================================

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
