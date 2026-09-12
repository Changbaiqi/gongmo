package com.gongmo.cbq.gongmo

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val settingsChannelName = "com.gongmo.cbq.gongmo/settings"
    private val screenshotChannelName = "com.gongmo.cbq.gongmo/screenshot"
    private val ocrChannelName = "com.gongmo.cbq.gongmo/ocr"

    private var screenshotChannel: MethodChannel? = null

    /** 触发截屏时工墨在后台：确认完成后需切回原应用 */
    private var returnToPreviousTask = false

    /** 常驻通知按钮待处理动作（冷启动时由 Dart 侧 consumeMenuAction 取走） */
    private var pendingMenuAction: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // 冷启动流程：只有截屏中转页会同时带这两个标记
        val fromCapture = intent?.getBooleanExtra(EXTRA_OCR_CAPTURE, false) == true
        returnToPreviousTask = fromCapture &&
            intent?.getBooleanExtra(EXTRA_OCR_RETURN, false) == true
        pendingMenuAction = intent?.getStringExtra(EXTRA_MENU_ACTION)
    }

    override fun onPause() {
        lastPausedAt = android.os.SystemClock.elapsedRealtime()
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, settingsChannelName)
            .setMethodCallHandler { call, result ->
                        when (call.method) {
                            "openAppSettings" -> result.success(openAppSettings())
                            "openBatterySettings" -> result.success(openBatterySettings())
                            // 用系统应用打开附件（图片/PDF/文本）
                            "openAttachment" -> {
                                val path = call.argument<String>("path")
                                val mime = call.argument<String>("mime") ?: "*/*"
                                result.success(openAttachment(path, mime))
                            }
                            else -> result.notImplemented()
                        }
            }
        screenshotChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, screenshotChannelName)
                .also { channel ->
                    channel.setMethodCallHandler { call, result ->
                        when (call.method) {
                            "isAccessibilityEnabled" ->
                                result.success(isAccessibilityEnabled())
                            "openAccessibilitySettings" ->
                                result.success(openAccessibilitySettings())
                            "startMenuNotification" -> result.success(startMenuNotification())
                            "stopMenuNotification" -> result.success(stopMenuNotification())
                            "isMenuNotificationRunning" ->
                                result.success(MenuNotificationService.running)
                            "consumePendingCapture" ->
                                result.success(ScreenshotStore.consume(this))
                            // 常驻通知菜单按钮动作（冷启动读取并清空）
                            "consumeMenuAction" -> {
                                val action = pendingMenuAction
                                pendingMenuAction = null
                                result.success(action)
                            }
                            "clearPendingCapture" -> {
                                ScreenshotStore.clear(this)
                                result.success(null)
                            }
                            // 关闭确认浮层后切回触发截屏前的应用
                            "returnToPreviousApp" -> {
                                val doReturn = returnToPreviousTask
                                returnToPreviousTask = false
                                if (doReturn) {
                                    try {
                                        moveTaskToBack(true)
                                    } catch (_: Exception) {
                                    }
                                }
                                result.success(doReturn)
                            }
                            else -> result.notImplemented()
                        }
                    }
                }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ocrChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "recognizeText" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result.success(null)
                        } else {
                            OcrRecognizer.recognize(path) { text ->
                                result.success(text)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(EXTRA_OCR_CAPTURE, false)) {
            returnToPreviousTask = intent.getBooleanExtra(EXTRA_OCR_RETURN, false)
            intent.removeExtra(EXTRA_OCR_CAPTURE)
            screenshotChannel?.invokeMethod("onCaptureReady", null)
        }
        // 常驻通知按钮（如「拍照记账」）：热启动时直接通知 Flutter 执行
        intent.getStringExtra(EXTRA_MENU_ACTION)?.let { action ->
            intent.removeExtra(EXTRA_MENU_ACTION)
            pendingMenuAction = action
            screenshotChannel?.invokeMethod("onMenuAction", action)
        }
    }

    /** 判断本应用的无障碍服务是否已在系统设置中开启 */
    private fun isAccessibilityEnabled(): Boolean {
        val expected = "$packageName/${GongmoAccessibilityService::class.java.name}"
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.split(':').any { it.equals(expected, ignoreCase = true) }
    }

    private fun openAccessibilitySettings(): Boolean {
        return try {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun startMenuNotification(): Boolean {
        return try {
            ContextCompat.startForegroundService(
                this,
                Intent(this, MenuNotificationService::class.java)
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun stopMenuNotification(): Boolean {
        return try {
            stopService(Intent(this, MenuNotificationService::class.java))
            true
        } catch (e: Exception) {
            false
        }
    }

    /** 打开「应用信息」页面（自启动、省电策略等在此设置） */
    private fun openAppSettings(): Boolean {
        try {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$packageName")
                )
            )
            return true
        } catch (e: Exception) {
            // 忽略，尝试下一个入口
        }
        try {
            startActivity(Intent(Settings.ACTION_APPLICATION_SETTINGS))
            return true
        } catch (e: Exception) {
            // 忽略
        }
        return false
    }

    /** 打开电池优化设置列表 */
    private fun openBatterySettings(): Boolean {
        try {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            return true
        } catch (e: Exception) {
            // 忽略，退回应用信息页
        }
        return openAppSettings()
    }

    /** 用系统应用打开附件：FileProvider 生成 content:// URI */
    private fun openAttachment(path: String?, mime: String): Boolean {
        if (path.isNullOrEmpty()) return false
        return try {
            val uri = androidx.core.content.FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                java.io.File(path)
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    companion object {
        const val EXTRA_OCR_CAPTURE = "com.gongmo.cbq.gongmo.ocr_capture"
        const val EXTRA_OCR_RETURN = "com.gongmo.cbq.gongmo.ocr_return"

        /** 常驻通知菜单按钮动作（值如 photo_bookkeeping） */
        const val EXTRA_MENU_ACTION = "com.gongmo.cbq.gongmo.menu_action"

        /** 最近一次 onPause 时刻（elapsedRealtime），用于判断截屏时应用是否在前台 */
        @Volatile
        var lastPausedAt = 0L
            private set
    }
}
