import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/services/storage_service.dart';
import 'app_theme.dart';

/// 主题状态管理：深色模式、配色方案、自定义背景
class ThemeController extends GetxController {
  final mode = ThemeMode.system.obs;
  final preset = AppThemePreset.green.obs;
  final backgroundPath = ''.obs;

  StorageService get _storage => StorageService();

  bool get hasBackground => backgroundPath.value.isNotEmpty;

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
