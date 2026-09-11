// ============================================================
// 主题控制器（app/theme）
// 职责：管理深色模式、配色预设、自定义背景图，并持久化到 config.json
// 关联：main.dart 中 Get.put 后由 GongMoApp 用 Obx 监听重建 MaterialApp；
//       设置页「外观」分组读写
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/services/storage_service.dart';
import 'app_theme.dart';

/// 主题状态：三个响应式字段（mode/preset/backgroundPath）变化后
/// 会触发 MaterialApp 重建主题；写操作同时落盘 config.json
class ThemeController extends GetxController {
  final mode = ThemeMode.system.obs;
  final preset = AppThemePreset.green.obs;
  final backgroundPath = ''.obs;

  StorageService get _storage => StorageService();

  /// 是否设置了自定义背景图（有背景图时 Scaffold 背景半透明）
  bool get hasBackground => backgroundPath.value.isNotEmpty;

  /// 从 config.json 恢复上次的主题选择
  @override
  void onInit() {
    super.onInit();
    final m = _storage.getConfig('theme_mode');
    if (m is String) {
      mode.value = ThemeMode.values
          .firstWhere((e) => e.name == m, orElse: () => ThemeMode.system);
    }
    final p = _storage.getConfig('theme_preset');
    if (p is String) {
      preset.value = AppThemePreset.values
          .firstWhere((e) => e.name == p, orElse: () => AppThemePreset.green);
    }
    final bg = _storage.getConfig('theme_bg');
    if (bg is String) {
      backgroundPath.value = bg;
    }
  }

  void setMode(ThemeMode value) {
    mode.value = value;
    _storage.setConfig('theme_mode', value.name);
  }

  void setPreset(AppThemePreset value) {
    preset.value = value;
    _storage.setConfig('theme_preset', value.name);
  }

  void setBackgroundImage(String path) {
    backgroundPath.value = path;
    _storage.setConfig('theme_bg', path);
  }

  void clearBackground() {
    backgroundPath.value = '';
    _storage.setConfig('theme_bg', '');
  }
}
