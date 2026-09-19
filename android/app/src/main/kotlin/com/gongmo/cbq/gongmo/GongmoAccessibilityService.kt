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
 *
 * 另外在「微信红包自动记账」开启时，会监听微信界面事件，
 * 只在出现「已存入零钱」的收款结果页读取红包金额（见 [onAccessibilityEvent]）。
 */
class GongmoAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    /**
     * 微信红包识别：仅当功能开启、事件来自微信、且当前页面出现
     * 「已存入零钱」字样（拆开红包的收款结果页）时，才提取金额记录，
     * 避免把发红包、红包列表、过期红包等页面误记为收入。
     */
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        try {
            val evt = event ?: return
            if (evt.packageName?.toString() != WECHAT_PACKAGE) return
            if (!RedPacketWatch.enabled(this)) return
            val type = evt.eventType
            if (type != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
                type != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            ) {
                return
            }
            val root = rootInActiveWindow ?: return
            val texts = collectTexts(root)
            if (texts.none { it.contains("已存入零钱") }) return
            val amount = extractAmount(texts) ?: return
            RedPacketWatch.report(this, amount)
        } catch (_: Throwable) {
            // 任何异常都不能影响无障碍服务本身
        }
    }

    /** 广度收集节点文本（含 contentDescription），限制数量避免卡顿 */
    private fun collectTexts(root: android.view.accessibility.AccessibilityNodeInfo): List<String> {
        val out = ArrayList<String>(32)
        val queue = ArrayDeque<android.view.accessibility.AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < 80) {
            val node = queue.removeFirst()
            visited++
            node.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { out.add(it) }
            node.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }
                ?.let { out.add(it) }
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { queue.add(it) }
            }
        }
        return out
    }

    /**
     * 提取红包金额：
     * 1. 优先找 "0.58元" 这类带「元」的文本；
     * 2. 否则在存在「元」字样的页面上，取最大的纯数字节点
     *    （红包金额不会超过 2000）。
     */
    private fun extractAmount(texts: List<String>): Double? {
        val withYuan = Regex("([0-9]+(?:\\.[0-9]{1,2})?)\\s*元")
        for (t in texts) {
            val m = withYuan.find(t) ?: continue
            val v = m.groupValues[1].toDoubleOrNull() ?: continue
            if (v > 0 && v <= 2000) return v
        }
        if (texts.none { it.contains("元") }) return null
        val bare = Regex("^[0-9]+(?:\\.[0-9]{1,2})?$")
        var best: Double? = null
        for (t in texts) {
            val s = t.trim()
            if (!bare.matches(s)) continue
            val v = s.toDoubleOrNull() ?: continue
            if (v <= 0 || v > 2000) continue
            if (best == null || v > best) best = v
        }
        return best
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
        private const val WECHAT_PACKAGE = "com.tencent.mm"

        @Volatile
        var instance: GongmoAccessibilityService? = null
            private set

        fun isConnected(): Boolean = instance != null
    }
}
