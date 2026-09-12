import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

/// 账目附件：图片 / PDF 等文件，存放于应用私有目录。
/// 账目中保存**相对路径**（`<entryId>/<文件名>`），便于云端备份与跨设备恢复。
class AttachmentService {
  AttachmentService._();
  static final AttachmentService instance = AttachmentService._();

  /// 单个附件大小上限：100MB
  static const int maxFileBytes = 100 * 1024 * 1024;

  static const String _rootName = 'gongmo_attachments';

  /// 与原生 MainActivity 的 settings 通道通信（打开附件用）
  static const MethodChannel _channel =
      MethodChannel('com.gongmo.cbq.gongmo/settings');

  Directory? _root;

  /// 应用启动时调用一次，之后 absolutePathSync 可直接使用
  Future<void> init() async {
    await _rootDir();
  }

  Future<Directory> _rootDir() async {
    final cached = _root;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_rootName');
    if (!await dir.exists()) await dir.create(recursive: true);
    _root = dir;
    return dir;
  }

  /// 相对路径 → 本地绝对路径（需已 init）
  String absolutePathSync(String relative) {
    final root = _root;
    if (root == null) return relative;
    return '${root.path}/$relative';
  }

  /// 选择文件并复制到附件目录，返回新增的相对路径；
  /// 超过 100MB 的文件会提示「文件过大」并跳过
  Future<List<String>> pickAndStore(String entryId) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false,
      );
    } catch (_) {
      Get.snackbar('选择文件失败', '请稍后重试');
      return [];
    }
    if (result == null || result.files.isEmpty) return [];

    final root = await _rootDir();
    final entryDir = Directory('${root.path}/$entryId');
    if (!await entryDir.exists()) await entryDir.create(recursive: true);

    final added = <String>[];
    for (final f in result.files) {
      final path = f.path;
      if (path == null) continue;
      if (f.size > maxFileBytes) {
        Get.snackbar('文件过大', '「${f.name}」超过 100MB，无法添加为附件');
        continue;
      }
      var name = f.name;
      var dest = File('${entryDir.path}/$name');
      if (await dest.exists()) {
        // 同名文件加时间戳，避免覆盖
        name = '${DateTime.now().millisecondsSinceEpoch}-$name';
        dest = File('${entryDir.path}/$name');
      }
      try {
        await File(path).copy(dest.path);
        added.add('$entryId/$name');
      } catch (_) {
        Get.snackbar('添加失败', '「${f.name}」复制失败');
      }
    }
    return added;
  }

  /// 删除单个附件（相对路径）
  Future<void> delete(String relative) async {
    try {
      final f = File(absolutePathSync(relative));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// 删除某笔账目的全部附件（删除账目时调用）
  Future<void> deleteAllFor(String entryId) async {
    try {
      final root = await _rootDir();
      final dir = Directory('${root.path}/$entryId');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  bool exists(String relative) {
    try {
      return File(absolutePathSync(relative)).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// 附件根目录（备份上传用）
  Future<Directory> rootDirectory() => _rootDir();

  /// 显示名（去掉 entryId 前缀）
  String displayName(String relative) {
    final i = relative.indexOf('/');
    return i >= 0 ? relative.substring(i + 1) : relative;
  }

  int sizeOf(String relative) {
    try {
      final f = File(absolutePathSync(relative));
      return f.existsSync() ? f.lengthSync() : 0;
    } catch (_) {
      return 0;
    }
  }

  bool isImage(String relative) {
    final n = relative.toLowerCase();
    return n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.png') ||
        n.endsWith('.gif') ||
        n.endsWith('.webp') ||
        n.endsWith('.bmp') ||
        n.endsWith('.heic');
  }

  bool isPdf(String relative) => relative.toLowerCase().endsWith('.pdf');

  bool isText(String relative) {
    final n = relative.toLowerCase();
    return n.endsWith('.txt') ||
        n.endsWith('.md') ||
        n.endsWith('.log') ||
        n.endsWith('.csv');
  }

  /// 是否支持在应用内预览
  bool canPreviewInline(String relative) =>
      isImage(relative) || isText(relative);

  String mimeOf(String relative) {
    final n = relative.toLowerCase();
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.bmp')) return 'image/bmp';
    if (n.endsWith('.heic')) return 'image/heic';
    if (isText(relative)) return 'text/plain';
    return '*/*';
  }

  /// 调用系统应用打开附件（PDF 等）
  Future<bool> openWithSystem(String relative) async {
    try {
      return await _channel.invokeMethod<bool>('openAttachment', {
            'path': absolutePathSync(relative),
            'mime': mimeOf(relative),
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  String formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB';
    return '$bytes B';
  }
}
