// ============================================================
// app_log_service.dart（data/services）
// 职责：收集 App 运行日志（框架输出、未捕获异常、print），只保留最近 5 小时，
//       需要反馈时打包成 tar.gz（含原生崩溃日志与 logcat）。
// 关联：main.dart 安装全局钩子；GongmoApplication 写 crash_log.txt；
//       设置页「日志收集」调用 exportToTarGz / clear。
// ============================================================
import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';

class AppLogService {
  AppLogService._();

  /// 只保留最近 5 小时的日志
  static const maxAge = Duration(hours: 5);

  /// 日志文件超过该大小就先裁剪一次
  static const _maxBytes = 512 * 1024;

  static const _fileName = 'app.log';

  /// 串行写入队列，避免多来源日志交叉写坏文件
  static Future<void> _queue = Future.value();

  // ---------------- 目录与文件 ----------------

  static Future<Directory> _logDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/logs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _logFile() async =>
      File('${(await _logDir()).path}/$_fileName');

  static String _stamp(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)} '
      '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}.'
      '${t.millisecond.toString().padLeft(3, '0')}';

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// 解析日志行时间戳；解析失败返回 null
  static DateTime? _parseLineTime(String line, DateTime now) {
    // 格式一：2026-09-20 21:30:12.345
    final full = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})')
        .firstMatch(line);
    if (full != null) {
      return DateTime(
        int.parse(full.group(1)!),
        int.parse(full.group(2)!),
        int.parse(full.group(3)!),
        int.parse(full.group(4)!),
        int.parse(full.group(5)!),
        int.parse(full.group(6)!),
      );
    }
    // 格式二（原生崩溃日志）：=== 09-20 21:30:12 (native/...)
    final short = RegExp(r'(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})')
        .firstMatch(line);
    if (short != null) {
      var t = DateTime(
        now.year,
        int.parse(short.group(1)!),
        int.parse(short.group(2)!),
        int.parse(short.group(3)!),
        int.parse(short.group(4)!),
        int.parse(short.group(5)!),
      );
      // 跨年（日志月份比当前大很多）时按去年算
      if (t.isAfter(now.add(const Duration(days: 1)))) {
        t = DateTime(t.year - 1, t.month, t.day, t.hour, t.minute, t.second);
      }
      return t;
    }
    return null;
  }

  /// 只保留 [maxAge] 内的日志行（无法解析时间的行保留，通常是堆栈上下文）
  static String _filterByAge(String content, DateTime now) {
    final cutoff = now.subtract(maxAge);
    final out = <String>[];
    for (final line in content.split('\n')) {
      final t = _parseLineTime(line, now);
      if (t == null || !t.isBefore(cutoff)) out.add(line);
    }
    return out.join('\n');
  }

  // ---------------- 写入 ----------------

  static void write(String tag, String message) {
    if (message.trim().isEmpty) return;
    final line = '${_stamp(DateTime.now())} [$tag] $message\n';
    _queue = _queue.then((_) async {
      try {
        final f = await _logFile();
        await f.writeAsString(line, mode: FileMode.append, flush: false);
        if (await f.length() > _maxBytes) await prune();
      } catch (_) {}
    });
  }

  /// 裁剪过期日志
  static Future<void> prune() async {
    try {
      final f = await _logFile();
      if (!await f.exists()) return;
      final now = DateTime.now();
      final kept = _filterByAge(await f.readAsString(), now);
      await f.writeAsString(kept, flush: false);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final dir = await _logDir();
      for (final entity in dir.listSync()) {
        if (entity is File) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
      final base = await getApplicationSupportDirectory();
      final crash = File('${base.path}/crash_log.txt');
      if (await crash.exists()) await crash.delete();
    } catch (_) {}
  }

  // ---------------- 全局安装 ----------------

  /// 安装全局日志钩子：框架输出、print、未捕获异常全部落盘
  static void install() {
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      original(message, wrapWidth: wrapWidth);
      if (message != null) write('UI', message);
    };
    FlutterError.onError = (details) {
      write('FLUTTER', '${details.exceptionAsString()}\n${details.stack ?? ''}');
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      write('DART', '$error\n$stack');
      return true;
    };
  }

  /// 供 runZonedGuarded 使用：捕获普通 print()
  static ZoneSpecification get zoneSpec => ZoneSpecification(
        print: (self, parent, zone, line) {
          parent.print(zone, line);
          write('PRINT', line);
        },
      );

  /// 供 runZonedGuarded 捕获 zone 内未处理异常
  static void writeError(Object error, StackTrace stack) =>
      write('ZONE', '$error\n$stack');

  // ---------------- 打包导出 ----------------

  /// 收集近 [maxAge] 的日志（应用日志 + 崩溃日志 + logcat + 设备信息），
  /// 打包成 tar.gz 并返回文件路径；失败返回 null。
  static Future<String?> exportToTarGz() async {
    try {
      await _queue; // 等待未完成的写入
      // 先让原生尽力抓一份本应用 logcat（无权限时自动跳过）
      try {
        await const MethodChannel('com.gongmo.cbq.gongmo/settings')
            .invokeMethod<bool>('dumpLogcat');
      } catch (_) {}
      await prune();
      final now = DateTime.now();
      final dir = await _logDir();
      final base = await getApplicationSupportDirectory();
      final archive = Archive();

      Future<void> addFile(String name, File file) async {
        try {
          if (!await file.exists()) return;
          final content = _filterByAge(await file.readAsString(), now);
          archive.addFile(ArchiveFile.string(name, content));
        } catch (_) {}
      }

      await addFile('app.log', File('${dir.path}/$_fileName'));
      await addFile('logcat.txt', File('${dir.path}/logcat.txt'));
      await addFile('crash_log.txt', File('${base.path}/crash_log.txt'));
      archive.addFile(ArchiveFile.string(
        'device_info.txt',
        'app: ${AppConstants.appName} v${AppConstants.appVersion}\n'
            'platform: ${Platform.operatingSystem} '
            '${Platform.operatingSystemVersion}\n'
            'logWindow: 近 ${maxAge.inHours} 小时\n'
            'exportedAt: ${now.toIso8601String()}\n',
      ));

      final tar = TarEncoder().encode(archive);
      final gz = GZipEncoder().encode(tar);
      final docs = await getApplicationDocumentsDirectory();
      final ts = now
          .toIso8601String()
          .substring(0, 19)
          .replaceAll(':', '-');
      final out = File('${docs.path}/gongmo_logs_$ts.tar.gz');
      await out.writeAsBytes(gz, flush: true);
      write('APP', '日志已打包：${out.path}（${gz.length ~/ 1024} KB）');
      return out.path;
    } catch (e) {
      write('APP', '日志打包失败：$e');
      return null;
    }
  }
}
