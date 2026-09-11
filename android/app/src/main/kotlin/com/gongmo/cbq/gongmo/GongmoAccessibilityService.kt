package com.gongmo.cbq.gongmo

import android.accessibilityservice.AccessibilityService
import android.graphics.Bitmap
import android.hardware.HardwareBuffer
import android.os.Build
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import java.io.File
import java.io.FileOutputStream

/**
 * 截屏记账用的无障碍服务。
 *
 * 用户在系统设置中开启后，可通过 [captureToCache] 对当前屏幕静默截屏
 * （Android 11 / API 30 起支持 AccessibilityService.takeScreenshot），
 * 截图保存到应用缓存目录，供 ML Kit OCR 识别账单文字。
 * 本服务只读取屏幕截图，不监听也不采集任何界面内容。
 */
class GongmoAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 不需要事件内容；截屏通过 takeScreenshot 主动触发
    }

    override fun onInterrupt() {}

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        if (instance === this) instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    /** 截图并保存为 cacheDir/ocr_capture.jpg，回调返回文件路径（失败返回 null） */
    fun captureToCache(onResult: (String?) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            onResult(null)
            return
        }
        try {
            takeScreenshot(
                Display.DEFAULT_DISPLAY,
                mainExecutor,
                object : AccessibilityService.TakeScreenshotCallback {
                    override fun onSuccess(screenshot: AccessibilityService.ScreenshotResult) {
                        var buffer: HardwareBuffer? = null
                        try {
                            buffer = screenshot.hardwareBuffer
                            val bitmap = Bitmap.wrapHardwareBuffer(buffer, screenshot.colorSpace)
                            if (bitmap == null) {
                                onResult(null)
                                return
                            }
                            val file = File(cacheDir, "ocr_capture.jpg")
                            FileOutputStream(file).use { out ->
                                bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
                            }
                            bitmap.recycle()
                            onResult(file.absolutePath)
                        } catch (e: Exception) {
                            onResult(null)
                        } finally {
                            buffer?.close()
                        }
                    }

                    override fun onFailure(errorCode: Int) {
                        onResult(null)
                    }
                }
            )
        } catch (e: Exception) {
            onResult(null)
        }
    }

    companion object {
        @Volatile
        var instance: GongmoAccessibilityService? = null
            private set

        fun isConnected(): Boolean = instance != null
    }
}
