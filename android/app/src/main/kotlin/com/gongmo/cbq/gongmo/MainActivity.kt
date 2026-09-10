package com.gongmo.cbq.gongmo

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.gongmo.cbq.gongmo/settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAppSettings" -> result.success(openAppSettings())
                    "openBatterySettings" -> result.success(openBatterySettings())
                    else -> result.notImplemented()
                }
            }
    }

    /// 打开「应用信息」页面（自启动、省电策略等在此设置）
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

    /// 打开电池优化设置列表
    private fun openBatterySettings(): Boolean {
        try {
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            return true
        } catch (e: Exception) {
            // 忽略，退回应用信息页
        }
        return openAppSettings()
    }
}
