import 'package:flutter/services.dart';

/// 待处理截图：由原生透明中转页写入，主引擎读取后进入识别确认页。
class PendingCapture {
  final String? path;

  /// 失败原因：accessibility_disabled / capture_failed 等
  final String? error;

  /// 是否来自拍照（拍照时弹窗不使用图片作全屏背景）
  final bool fromCamera;

  const PendingCapture({this.path, this.error, this.fromCamera = false});

  bool get hasImage => path != null && path!.isNotEmpty;

  factory PendingCapture.fromMap(Map<dynamic, dynamic> map) {
    final path = map['path'] as String?;
    final error = map['error'] as String?;
    return PendingCapture(
      path: (path == null || path.isEmpty) ? null : path,
      error: (error == null || error.isEmpty) ? null : error,
    );
  }
}

/// 截屏记账的常驻通知菜单：开关通知服务、查询无障碍状态、读取待处理截图。
///
/// 原生实现见 android/app/src/main/kotlin/.../MenuNotificationService.kt、
/// GongmoAccessibilityService.kt、OcrBridgeActivity.kt。
/// 非 Android 平台所有方法安全降级（返回 false/null）。
class ScreenshotMenuService {
  ScreenshotMenuService._();
  static final ScreenshotMenuService instance = ScreenshotMenuService._();

  static const MethodChannel _channel =
      MethodChannel('com.gongmo.cbq.gongmo/screenshot');

  void Function()? _captureReadyHandler;
  void Function(String? action)? _menuActionHandler;
  bool _handlerInstalled = false;

  /// 原生 → Flutter 的统一回调入口（截屏完成 / 通知菜单动作）
  void _installHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onCaptureReady':
          _captureReadyHandler?.call();
        case 'onMenuAction':
          _menuActionHandler?.call(call.arguments as String?);
      }
    });
  }

  /// 原生截屏完成（MainActivity onNewIntent）时回调
  void setCaptureReadyHandler(void Function()? handler) {
    _captureReadyHandler = handler;
    _installHandler();
  }

  /// 常驻通知菜单按钮动作回调（如 photo_bookkeeping）
  void setMenuActionHandler(void Function(String? action)? handler) {
    _menuActionHandler = handler;
    _installHandler();
  }

  /// 读取并清空待处理的菜单动作（App 冷启动时使用）
  Future<String?> consumeMenuAction() async {
    try {
      return await _channel.invokeMethod<String>('consumeMenuAction');
    } catch (_) {
      return null;
    }
  }

  /// 无障碍服务是否已在系统设置中开启
  Future<bool> isAccessibilityEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openAccessibilitySettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAccessibilitySettings') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 启动常驻通知菜单（前台服务）
  Future<bool> startMenuNotification() async {
    try {
      return await _channel.invokeMethod<bool>('startMenuNotification') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopMenuNotification() async {
    try {
      return await _channel.invokeMethod<bool>('stopMenuNotification') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isMenuNotificationRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isMenuNotificationRunning') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 读取并清空待处理截图（App 冷启动 / 前台收到 onCaptureReady 后调用）
  Future<PendingCapture?> consumePendingCapture() async {
    try {
      final result = await _channel.invokeMethod<dynamic>('consumePendingCapture');
      if (result is Map) return PendingCapture.fromMap(result);
    } catch (_) {}
    return null;
  }

  Future<void> clearPendingCapture() async {
    try {
      await _channel.invokeMethod<void>('clearPendingCapture');
    } catch (_) {}
  }

  /// 关闭截屏确认后返回触发截屏前的应用（任务切回后台）。
  /// 返回 true 表示已切回（原生执行了 moveTaskToBack）。
  Future<bool> returnToPreviousApp() async {
    try {
      return await _channel.invokeMethod<bool>('returnToPreviousApp') ?? false;
    } catch (_) {
      return false;
    }
  }
}
