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
            // 其它应用来了新通知：把截屏记账常驻菜单重新贴一遍，
            // 让它在通知栏保持最前，不被一条条新通知顶下去
            if (evt.eventType == AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED) {
                val from = evt.packageName?.toString()
                if (from != null && from != packageName && from != "android") {
                    MenuNotificationService.bumpIfRunning(this)
                }
                return
            }
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
            val marker = markerOf(texts) ?: return
            val amount = amountAbove(texts, marker.first) ?: return
            RedPacketWatch.report(this, amount, marker.second)
        } catch (_: Throwable) {
            // 任何异常都不能影响无障碍服务本身
        }
    }

    /** 深度优先收集文本（尽可能按视觉从上到下的顺序），限制数量避免卡顿 */
    private fun collectTexts(
        root: android.view.accessibility.AccessibilityNodeInfo
    ): List<String> {
        val out = ArrayList<String>(48)

        fun walk(node: android.view.accessibility.AccessibilityNodeInfo, depth: Int) {
            if (out.size >= 140 || depth > 26) return
            node.text?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { out.add(it) }
            node.contentDescription?.toString()?.trim()?.takeIf { it.isNotEmpty() }
                ?.let { out.add(it) }
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { walk(it, depth + 1) }
            }
        }

        walk(root, 0)
        return out
    }

    /**
     * 找到收款标记：红包「已存入零钱」、转账「已收款/已收钱」。
     * 返回（标记下标, 类型）。
     */
    private fun markerOf(texts: List<String>): Pair<Int, String>? {
        for ((i, t) in texts.withIndex()) {
            if (t.contains("已存入零钱")) return i to "redpacket"
            if (t.contains("已收款") || t.contains("已收钱")) return i to "transfer"
        }
        return null
    }

    /**
     * 取标记上方最近的金额。
     *
     * 关键：红包/转账页面下方是"其它人的领取记录/交易记录"，
     * 金额很多；自己的金额一定在「已存入零钱/已收款」上方，
     * 因此从标记往回找第一个金额，避免取到别人的金额。
     */
    private fun amountAbove(texts: List<String>, markerIndex: Int): Double? {
        val bare = Regex("^[0-9]+(?:\\.[0-9]{1,2})?$")
        val withUnit = Regex("[¥￥]?\\s*([0-9]+(?:\\.[0-9]{1,2})?)\\s*元?$")
        for (i in markerIndex - 1 downTo 0) {
            val s = texts[i].trim()
            val m = if (bare.matches(s)) s else withUnit.find(s)?.groupValues?.get(1)
            val v = m?.toDoubleOrNull() ?: continue
            if (v > 0 && v <= 2000) return v
        }
        return null
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
