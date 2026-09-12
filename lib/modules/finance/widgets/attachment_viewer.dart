import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/services/attachment_service.dart';
import '../../../data/services/github_sync_service.dart';

/// 打开附件：
/// - 图片 / 文本：应用内预览页
/// - PDF 等：交给系统应用（通过 FileProvider）
Future<void> openAttachment(String relativePath) async {
  final svc = AttachmentService.instance;
  if (!svc.exists(relativePath)) {
    // 可能是云端已备份但本地未下载：尝试重新拉取一次
    final fetched =
        await GithubSyncService.instance.downloadAttachment(relativePath);
    if (!fetched || !svc.exists(relativePath)) {
      Get.snackbar('打开失败', '附件文件不存在（可能已被清理或尚未同步到本机）');
      return;
    }
  }
  if (svc.canPreviewInline(relativePath)) {
    Get.to(() => AttachmentViewerPage(relativePath: relativePath));
    return;
  }
  final ok = await svc.openWithSystem(relativePath);
  if (!ok) {
    Get.snackbar('无法打开', '未找到可打开该文件的应用');
  }
}

/// 附件预览页：图片支持缩放拖动，文本直接阅读
class AttachmentViewerPage extends StatefulWidget {
  const AttachmentViewerPage({super.key, required this.relativePath});

  final String relativePath;

  @override
  State<AttachmentViewerPage> createState() => _AttachmentViewerPageState();
}

class _AttachmentViewerPageState extends State<AttachmentViewerPage> {
  final AttachmentService _svc = AttachmentService.instance;

  String? _text;
  bool _loadingText = false;

  bool get _isImage => _svc.isImage(widget.relativePath);

  @override
  void initState() {
    super.initState();
    if (!_isImage) _loadText();
  }

  Future<void> _loadText() async {
    setState(() => _loadingText = true);
    try {
      final file = File(_svc.absolutePathSync(widget.relativePath));
      final bytes = await file.readAsBytes();
      // 允许非法字节（GBK 等编码中文会显示为替换符，但不影响阅读其它内容）
      final text = utf8.decode(bytes, allowMalformed: true);
      if (mounted) setState(() => _text = text);
    } catch (_) {
      if (mounted) setState(() => _text = '（无法读取文件内容）');
    } finally {
      if (mounted) setState(() => _loadingText = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = _svc.displayName(widget.relativePath);
    return Scaffold(
      appBar: AppBar(
        title: Text(name, style: const TextStyle(fontSize: 15)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '用其它应用打开',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () async {
              final ok = await _svc.openWithSystem(widget.relativePath);
              if (!ok) Get.snackbar('无法打开', '未找到可打开该文件的应用');
            },
          ),
        ],
      ),
      backgroundColor: _isImage ? Colors.black : null,
      body: _isImage ? _buildImage() : _buildText(cs),
    );
  }

  Widget _buildImage() {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image.file(
          File(_svc.absolutePathSync(widget.relativePath)),
          errorBuilder: (_, __, ___) => const Text('图片加载失败',
              style: TextStyle(color: Colors.white70)),
        ),
      ),
    );
  }

  Widget _buildText(ColorScheme cs) {
    if (_loadingText) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _text ?? '（空文件）',
        style: TextStyle(
          fontSize: 13.5,
          height: 1.6,
          color: cs.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
