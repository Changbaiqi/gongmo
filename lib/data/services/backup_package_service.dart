// ============================================================
// backup_package_service.dart（data/services）
// 职责：把整合后的本地数据按「原始分片文件」打包成 .gongmo（zip 压缩包）导出；
//       导入时解包还原成 StorageService 可合并/覆盖的数据结构。
// 关联：SyncController（导出/导入）；StorageService（dataDir / 文件名常量）。
// 包内结构：meta.json + work_entries_2026.json 等原始文件（config 会剔除密钥）。
// ============================================================
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import 'storage_service.dart';

class BackupPackageService {
  BackupPackageService._();
  static final BackupPackageService instance = BackupPackageService._();

  /// 备份包扩展名（文件本身是 zip，压缩后仅改后缀）
  static const extension = 'gongmo';

  static const _metaName = 'meta.json';
  static const _appTag = 'gongmo';

  /// 不打包的临时文件（自动记账待入账队列等）
  static const _excluded = {'auto_queue.json', _metaName};

  /// 打包时从 config.json 剔除的敏感键（密钥实际存在安全存储，这里双保险）
  static final _secretKey = RegExp(
    r'token|secret|api[_-]?key|password|passwd|credential',
    caseSensitive: false,
  );

  /// 导出 .gongmo 包，返回生成的文件路径
  Future<String> exportPackage() async {
    final dir = StorageService().dataDir;
    final archive = Archive();
    final files = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (_excluded.contains(name)) continue;
      var content = await entity.readAsString();
      if (name == AppConstants.configFile) {
        content = _sanitizeConfig(content);
      }
      archive.addFile(ArchiveFile.string(name, content));
      files.add(name);
    }
    archive.addFile(ArchiveFile.string(
      _metaName,
      const JsonEncoder.withIndent('  ').convert({
        'app': _appTag,
        'version': AppConstants.appVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'files': files,
      }),
    ));

    final bytes = ZipEncoder().encode(archive);
    final docs = await getApplicationDocumentsDirectory();
    // ISO 时间如 2026-09-11T12:34:56，替换冒号以兼容文件名
    final ts = DateTime.now()
        .toIso8601String()
        .substring(0, 19)
        .replaceAll(':', '-');
    final file = File('${docs.path}/gongmo_backup_$ts.$extension');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// 读取备份文件（.gongmo 包或旧版 .json 导出），返回可供
  /// [StorageService.mergeRemoteData] / [StorageService.restoreAllData]
  /// 使用的数据；无法识别时返回 null。
  Future<Map<String, dynamic>?> readBackup(File file) async {
    final bytes = await file.readAsBytes();
    // zip 魔数 PK\x03\x04
    if (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      return _readPackage(bytes);
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) return null;
    final data = decoded['data'];
    return data is Map
        ? Map<String, dynamic>.from(data)
        : Map<String, dynamic>.from(decoded);
  }

  /// 解包 .gongmo：按原始分片文件还原各记录列表与预算配置
  Map<String, dynamic> _readPackage(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final work = <dynamic>[];
    final finance = <dynamic>[];
    final categories = <dynamic>[];
    final accounts = <dynamic>[];
    final tags = <dynamic>[];
    final invoices = <dynamic>[];
    Map<String, dynamic>? config;
    Map<String, dynamic>? tombstones;

    for (final f in archive) {
      if (!f.isFile) continue;
      final name = f.name;
      if (name == _metaName) continue;
      final dynamic decoded;
      try {
        decoded = jsonDecode(utf8.decode(f.content, allowMalformed: true));
      } catch (_) {
        continue;
      }
      if (name == AppConstants.configFile) {
        if (decoded is Map) config = Map<String, dynamic>.from(decoded);
        continue;
      }
      if (name.startsWith('tombstones')) {
        if (decoded is Map) tombstones = Map<String, dynamic>.from(decoded);
        continue;
      }
      if (decoded is! List) continue;
      if (name.startsWith('work_entries') || name == AppConstants.workFile) {
        work.addAll(decoded);
      } else if (name.startsWith('finance_entries') ||
          name == AppConstants.financeFile) {
        finance.addAll(decoded);
      } else if (name.startsWith('categories')) {
        categories.addAll(decoded);
      } else if (name.startsWith('accounts')) {
        accounts.addAll(decoded);
      } else if (name.startsWith('timer_tags')) {
        tags.addAll(decoded);
      } else if (name.startsWith('invoice_profiles')) {
        invoices.addAll(decoded);
      }
    }

    final result = <String, dynamic>{
      'workEntries': work,
      'financeEntries': finance,
      'categories': categories,
      'accounts': accounts,
      'timerTags': tags,
      'invoiceProfiles': invoices,
    };
    if (tombstones != null) result['tombstones'] = tombstones;
    if (config != null) {
      if (config['budgets'] != null) result['budgets'] = config['budgets'];
      if (config['total_budget'] != null) {
        result['totalBudget'] = config['total_budget'];
      }
      final at = config['budgets_updated_at'];
      if (at != null) result['budgetsUpdatedAt'] = at;
    }
    return result;
  }

  /// 去掉配置里的密钥类键，避免备份包泄漏
  String _sanitizeConfig(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return raw;
      final clean = <String, dynamic>{};
      decoded.forEach((k, v) {
        if (_secretKey.hasMatch('$k')) return;
        clean['$k'] = v;
      });
      return jsonEncode(clean);
    } catch (_) {
      return raw;
    }
  }
}
