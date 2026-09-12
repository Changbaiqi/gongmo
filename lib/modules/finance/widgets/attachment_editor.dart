import 'package:flutter/material.dart';

import '../../../data/services/attachment_service.dart';
import 'attachment_viewer.dart';

/// 附件编辑区：展示已关联附件（可删除）+「添加附件」按钮。
/// 宿主页面保存时通过 [onChanged] 拿到最新的相对路径列表。
class AttachmentEditor extends StatefulWidget {
  const AttachmentEditor({
    super.key,
    required this.entryId,
    required this.onChanged,
    this.initialPaths = const [],
  });

  /// 账目 id（附件按 `<entryId>/<文件名>` 存放）
  final String entryId;
  final List<String> initialPaths;
  final ValueChanged<List<String>> onChanged;

  @override
  State<AttachmentEditor> createState() => _AttachmentEditorState();
}

class _AttachmentEditorState extends State<AttachmentEditor> {
  late final List<String> _paths = List.of(widget.initialPaths);
  bool _busy = false;

  @override
  void didUpdateWidget(covariant AttachmentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部追加附件（如拍照/截屏自动挂载）时同步显示
    for (final p in widget.initialPaths) {
      if (!_paths.contains(p)) _paths.add(p);
    }
  }

  Future<void> _add() async {
    if (_busy) return;
    setState(() => _busy = true);
    final added =
        await AttachmentService.instance.pickAndStore(widget.entryId);
    if (!mounted) return;
    setState(() {
      _paths.addAll(added);
      _busy = false;
    });
    if (added.isNotEmpty) widget.onChanged(List.of(_paths));
  }

  /// 直接拍照作为附件
  Future<void> _capture() async {
    if (_busy) return;
    setState(() => _busy = true);
    final added =
        await AttachmentService.instance.captureAndStore(widget.entryId);
    if (!mounted) return;
    setState(() {
      _paths.addAll(added);
      _busy = false;
    });
    if (added.isNotEmpty) widget.onChanged(List.of(_paths));
  }

  Future<void> _remove(String path) async {
    setState(() => _paths.remove(path));
    widget.onChanged(List.of(_paths));
    await AttachmentService.instance.delete(path);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_paths.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [for (final p in _paths) _chip(cs, p)],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _add,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file_rounded, size: 16),
                label: const Text('添加附件（图片 / PDF 等，单个 ≤100MB）',
                    style: TextStyle(fontSize: 12.5)),
              ),
            ),
            const SizedBox(width: 8),
            // 直接拍照作为附件
            SizedBox(
              height: 40,
              child: OutlinedButton(
                onPressed: _busy ? null : _capture,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Icon(Icons.photo_camera_outlined, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(ColorScheme cs, String rel) {
    final svc = AttachmentService.instance;
    final size = svc.sizeOf(rel);
    final icon = svc.isImage(rel)
        ? Icons.image_outlined
        : (svc.isPdf(rel)
            ? Icons.picture_as_pdf_outlined
            : Icons.insert_drive_file_outlined);
    return InputChip(
      avatar: Icon(icon, size: 16, color: cs.primary),
      label: Text(
        size > 0
            ? '${svc.displayName(rel)} · ${svc.formatSize(size)}'
            : svc.displayName(rel),
        style: const TextStyle(fontSize: 12),
      ),
      // 点击打开查看（图片/文本内置预览，PDF 等交给系统应用）
      onPressed: () => openAttachment(rel),
      onDeleted: () => _remove(rel),
      deleteIcon: const Icon(Icons.close_rounded, size: 14),
      visualDensity: VisualDensity.compact,
    );
  }
}
