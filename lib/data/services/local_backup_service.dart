// ============================================================
// local_backup_service.dart（data/services）
// 职责：把数据「原样」镜像到公共「下载/工墨数据备份/<时间戳>/」目录，
//       不打包（数据大时也很快），不依赖 GitHub，
//       也不会随应用数据清理而消失（走 MediaStore）。
// 关联：BackupPackageService（文件名/解析）、SyncController（自动镜像）、
//       数据备份页（手动备份 / 本地恢复 / 打开备份目录）。
// ============================================================
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app_log_service.dart';
import 'backup_package_service.dart';
import 'storage_service.dart';

class LocalBackupService {
  LocalBackupService._();

  static const _channel = MethodChannel('com.gongmo.cbq.gongmo/settings');
  static const _keyAuto = 'local_backup_auto';
  static const _keyLastAt = 'local_backup_last_at';
  static const _keyLastPath = 'local_backup_last_path';

  /// 自动备份最小间隔：每天最多一份（数据变动时检查，距上次不足 24 小时则跳过）
  static const _autoInterval = Duration(hours: 24);

  /// 用户可见的备份目录（公共下载目录下）
  static const folderName = '工墨数据备份';

  /// 手动导出的 .gongmo 数据包目录（公共下载目录下，独立于自动快照）
  static const exportFolder = '工墨导出';

  /// 复制文件到公共下载目录（relativeDir 相对「下载」目录），返回可见路径
  static Future<String?> saveToPublicDownloads(
    String sourcePath, {
    String? relativeDir,
    String? mime,
  }) async {
    try {
      return await _channel.invokeMethod<String>('saveToDownloads', {
        'source': sourcePath,
        'name': sourcePath.split(Platform.pathSeparator).last,
        'mime': mime ?? 'application/octet-stream',
        'relativeDir': relativeDir ?? folderName,
      });
    } catch (_) {
      return null;
    }
  }

  /// 自动本地备份默认开启（未显式关闭即生效）
  static bool get autoEnabled =>
      StorageService().getConfig(_keyAuto) != false;

  static Future<void> setAuto(bool v) =>
      StorageService().setConfig(_keyAuto, v);

  static DateTime? get lastTime {
    final raw = StorageService().getConfig(_keyLastAt);
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  static String? get lastPath {
    final raw = StorageService().getConfig(_keyLastPath);
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  /// 软件数据目录（应用私有）
  static String get dataDirPath => StorageService().dataDir.path;

  /// 备份目录的用户可见路径
  static String get visibleFolder => '下载/$folderName';

  static String _stamp(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)}_${_two(t.hour)}${_two(t.minute)}';

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// 最近一次失败原因（界面提示 + 日志排查用）
  static String? lastError;

  /// 短时间内重复备份视为「更新同一份快照」而不是新建
  static const _reuseWindow = Duration(minutes: 5);

  /// 是否正在备份（界面用它禁用按钮，避免连点）
  static bool running = false;

  /// 是否本次是覆盖（复用上一份快照）
  static bool lastReused = false;

  /// 立即镜像一份到公共目录，返回用户可见目录；失败返回 null。
  ///
  /// 不打包：数据目录里的每个原始文件直接逐个复制过去，数据大时也不慢。
  /// 距上次备份不足 [_reuseWindow] 时直接覆盖同一份快照，避免连点产生多份。
  static Future<String?> backupNow() async {
    if (running) {
      lastError = '正在备份中，请稍候';
      return null;
    }
    running = true;
    lastError = null;
    lastReused = false;
    try {
      final names = BackupPackageService.instance.dataFileNames();
      if (names.isEmpty) {
        lastError = '数据目录为空，没有可备份的文件';
        return null;
      }
      // 刚备份过就覆盖同一份快照，否则新建时间戳目录
      final last = lastTime;
      final lastFolder = _folderOf(lastPath);
      final reuse = last != null &&
          lastFolder != null &&
          DateTime.now().difference(last) < _reuseWindow;
      final stamp = reuse ? lastFolder : _stamp(DateTime.now());
      final relativeDir = '$folderName/$stamp';
      if (reuse) {
        // 先清掉旧快照里的文件，避免 MediaStore 重名变成 "xxx (1).json"
        try {
          await _channel.invokeMethod<bool>(
              'deleteLocalDir', {'relativeDir': relativeDir});
        } catch (_) {}
        lastReused = true;
      }
      // config.json 需要剔除密钥：改写一份临时文件再复制
      Directory? tmpDir;
      File? tmpConfig;
      var copied = 0;
      String? firstError;
      for (final name in names) {
        var sourcePath = '$dataDirPath/$name';
        if (name == 'config.json') {
          final sanitized =
              await BackupPackageService.instance.readSanitized(name);
          if (sanitized == null) continue;
          final base = await getApplicationSupportDirectory();
          tmpDir ??= Directory('${base.path}/local_backup_tmp');
          if (!await tmpDir.exists()) await tmpDir.create(recursive: true);
          tmpConfig = File('${tmpDir.path}/$name');
          await tmpConfig.writeAsString(sanitized, flush: false);
          sourcePath = tmpConfig.path;
        }
        final saved = await _channel.invokeMethod<String>('saveToDownloads', {
          'source': sourcePath,
          'name': name,
          'mime': 'application/json',
          'relativeDir': relativeDir,
        });
        if (saved != null) {
          copied++;
        } else {
          firstError ??= name;
        }
      }
      // 清理临时文件
      try {
        if (tmpDir != null && await tmpDir.exists()) {
          await tmpDir.delete(recursive: true);
        }
      } catch (_) {}
      if (copied == 0) {
        lastError = firstError == null
            ? '没有可写入的文件'
            : '第一个写入失败的文件：$firstError';
        AppLogService.write('BACKUP', '本地备份失败：$lastError');
        return null;
      }
      // 只保留最近几份快照，避免公共目录越攒越多
      try {
        await _channel.invokeMethod<bool>('pruneLocalBackups');
      } catch (_) {}
      await StorageService().setConfig(
          _keyLastAt, DateTime.now().toIso8601String());
      await StorageService().setConfig(_keyLastPath, '下载/$relativeDir');
      AppLogService.write('BACKUP',
          '本地备份完成${lastReused ? '（覆盖）' : ''}：下载/$relativeDir'
          '（成功 $copied/${names.length} 个文件）');
      return '下载/$relativeDir';
    } catch (e, s) {
      lastError = '$e';
      AppLogService.write('BACKUP', '本地备份异常：$e\n$s');
      return null;
    } finally {
      running = false;
    }
  }

  /// 从可见路径里取出快照目录名（下载/工墨数据备份/2026-09-20_2130）
  static String? _folderOf(String? visiblePath) {
    if (visiblePath == null) return null;
    final parts = visiblePath.split('/').where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.last;
  }

  /// 数据变化后调用：按开关与节流间隔自动镜像一份
  static Future<void> autoBackupIfDue() async {
    if (!autoEnabled) return;
    final last = lastTime;
    if (last != null && DateTime.now().difference(last) < _autoInterval) {
      return;
    }
    await backupNow();
  }

  /// 选择本地快照目录并解析（也兼容选择 .gongmo/.json 文件）
  static Future<Map<String, dynamic>?> pickBackupDir() async {
    try {
      final dirPath = await FilePicker.platform.getDirectoryPath();
      if (dirPath == null || dirPath.isEmpty) return null;
      final dir = Directory(dirPath);
      if (!await dir.exists()) return null;
      return await BackupPackageService.instance.readBackupDir(dir);
    } catch (_) {
      return null;
    }
  }

  /// 用系统文件管理器打开备份目录
  static Future<bool> openFolder() async {
    try {
      return await _channel.invokeMethod<bool>(
            'openFolder',
            {'relativeDir': folderName},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 列出公共备份目录里的文件（按快照目录分组展示用）
  static Future<List<LocalBackupFile>> listSnapshots() async {
    try {
      final raw =
          await _channel.invokeMethod<List<dynamic>>('listLocalBackups');
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((e) => LocalBackupFile(
                folder: '${e['folder'] ?? ''}',
                name: '${e['name'] ?? ''}',
                size: (e['size'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

/// 公共备份目录里的一个文件
class LocalBackupFile {
  const LocalBackupFile({
    required this.folder,
    required this.name,
    required this.size,
  });

  /// 快照目录名；空字符串表示直接放在根目录的旧版备份
  final String folder;
  final String name;
  final int size;
}
