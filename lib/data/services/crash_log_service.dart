// ============================================================
// crash_log_service.dart（data/services）
// 职责：读写崩溃日志（Flutter 侧未捕获异常写入 filesDir/crash_log.txt，
//       与原生侧 GongmoApplication 写的是同一个文件）。
// 关联：main.dart 安装异常处理；设置页「关于」提供查看/复制/清空。
// ============================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CrashLogService {
  CrashLogService._();

  static const _fileName = 'crash_log.txt';
  static const _maxBytes = 256 * 1024;

  static Future<File?> _file() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/$_fileName');
    } catch (_) {
      return null;
    }
  }

  /// 读取崩溃日志；无日志时返回空串
  static Future<String> read() async {
    try {
      final f = await _file();
      if (f == null || !await f.exists()) return '';
      return await f.readAsString();
    } catch (_) {
      return '';
    }
  }

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// 追加一条崩溃记录（超过上限先清空，避免无限增长）
  static Future<void> append({
    required String kind,
    required String message,
    StackTrace? stack,
  }) async {
    try {
      final f = await _file();
      if (f == null) return;
      if (await f.exists() && await f.length() > _maxBytes) {
        await f.delete();
      }
      final now = DateTime.now();
      final ts = '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}';
      await f.writeAsString(
        '\n=== $ts ($kind) ===\n$message\n${stack ?? ''}\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  /// 安装 Flutter 侧全局异常记录（在 runApp 前调用）
  static void install() {
    FlutterError.onError = (details) {
      append(
        kind: 'flutter',
        message: details.exceptionAsString(),
        stack: details.stack,
      );
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      append(kind: 'dart', message: error.toString(), stack: stack);
      return true;
    };
  }
}
