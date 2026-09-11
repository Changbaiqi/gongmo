// ============================================================
// 后台保活辅助服务（data/services）
// 职责：引导用户加入电池优化白名单、跳转系统设置，保障通知监听常驻
// 关联：设置页「后台保活」分组；Android MethodChannel
//       com.gongmo.cbq.gongmo/settings（MainActivity 侧实现）
// ============================================================

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// 后台常驻辅助：电池优化白名单 + 跳转应用设置（自启动/省电策略）
class KeepAliveService {
  KeepAliveService._();
  static final KeepAliveService instance = KeepAliveService._();

  static const _channel = MethodChannel('com.gongmo.cbq.gongmo/settings');

  /// 是否已忽略电池优化（已加入白名单）
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await Permission.ignoreBatteryOptimizations.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// 请求忽略电池优化（弹出系统对话框）。
  /// 部分机型不会弹出对话框，这里加超时兜底，避免一直等待。
  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations
          .request()
          .timeout(const Duration(seconds: 10),
              onTimeout: () => PermissionStatus.denied);
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// 打开本应用的系统设置页（自启动、省电策略等在此设置）。
  /// 优先用原生实现，失败再退回 permission_handler。
  Future<bool> openSystemAppSettings() async {
    try {
      final ok = await _channel.invokeMethod<bool>('openAppSettings');
      if (ok == true) return true;
    } catch (_) {}
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// 打开电池优化设置列表（部分机型不会弹对话框时的兜底入口）
  Future<bool> openBatterySettings() async {
    try {
      final ok = await _channel.invokeMethod<bool>('openBatterySettings');
      if (ok == true) return true;
    } catch (_) {}
    return openSystemAppSettings();
  }
}
