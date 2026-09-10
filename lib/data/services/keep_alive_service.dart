import 'package:permission_handler/permission_handler.dart';

/// 后台常驻辅助：电池优化白名单 + 跳转应用设置（自启动/省电策略）
class KeepAliveService {
  KeepAliveService._();
  static final KeepAliveService instance = KeepAliveService._();

  /// 是否已忽略电池优化（已加入白名单）
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await Permission.ignoreBatteryOptimizations.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// 请求忽略电池优化（弹出系统对话框）
  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// 打开本应用的系统设置页（自启动、省电策略等在此设置）
  Future<void> openSystemAppSettings() async {
    try {
      await openAppSettings();
    } catch (_) {}
  }
}
