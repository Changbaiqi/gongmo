import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/screenshot_menu_service.dart';
import '../../data/services/storage_service.dart';
import 'ocr_confirm_dialog.dart';

/// 拍照识别记账：打开相机拍照后进入 OCR 确认浮层。
/// 由首页长按 + 号、以及常驻通知的「拍照记账」按钮共用。
Future<void> startPhotoBookkeeping() async {
  if (StorageService().getConfig('photo_bookkeeping_enabled') == false) {
    Get.snackbar('未开启', '可在「设置 → 识图记账」中开启拍照记账');
    return;
  }
  HapticFeedback.mediumImpact();
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;
    OcrConfirmDialog.show(
      PendingCapture(path: picked.path, fromCamera: true),
    );
  } catch (_) {
    Get.snackbar('打开相机失败', '请稍后重试');
  }
}

/// 执行常驻通知菜单的动作（冷启动读取 / 前台回调共用）。
/// 目前仅支持拍照记账：photo_bookkeeping
void runMenuAction(String? action) {
  if (action == 'photo_bookkeeping') {
    startPhotoBookkeeping();
  }
}
