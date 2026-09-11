package com.gongmo.cbq.gongmo

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock

/**
 * 透明中转页：常驻通知点击后由系统拉起。
 *
 * 因为通知栏需要先收起、且不能让我们自己的界面遮住待识别页面，
 * 这里用全透明 Activity 过渡：等待约 450ms 让通知栏收起与转场结束后，
 * 调用无障碍服务截取下层应用画面，保存结果并跳转 MainActivity 展示确认浮层。
 *
 * 若截屏前工墨还在前台（用户从本应用内下拉通知栏），确认完成后不再强行切回；
 * 否则记录需要切回原应用，由 MainActivity 在浮层关闭时 moveTaskToBack。
 */
class OcrBridgeActivity : Activity() {
    /** 截屏时工墨是否在前台 */
    private var appWasForeground = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // MainActivity 若刚被本中转页暂停，说明截屏前工墨在前台
        appWasForeground =
            SystemClock.elapsedRealtime() - MainActivity.lastPausedAt < 2000
        Handler(Looper.getMainLooper()).postDelayed({
            val service = GongmoAccessibilityService.instance
            if (service == null) {
                launchMain(null, "accessibility_disabled")
                return@postDelayed
            }
            service.captureToCache { path ->
                launchMain(path, if (path == null) "capture_failed" else null)
            }
        }, 450)
    }

    private fun launchMain(path: String?, error: String?) {
        ScreenshotStore.setCapture(this, path, error)
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(MainActivity.EXTRA_OCR_CAPTURE, true)
            putExtra(MainActivity.EXTRA_OCR_RETURN, !appWasForeground)
        }
        try {
            startActivity(intent)
        } catch (_: Exception) {
        }
        finish()
        overridePendingTransition(0, 0)
    }
}
