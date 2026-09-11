package com.gongmo.cbq.gongmo

import android.content.Context

/**
 * 截屏结果的轻量本地存储：透明中转页写、Flutter 通过 MethodChannel 读取并清除。
 */
object ScreenshotStore {
    private const val PREFS = "gongmo_screenshot"
    private const val KEY_PATH = "pending_path"
    private const val KEY_ERROR = "pending_error"

    fun setCapture(context: Context, path: String?, error: String?) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_PATH, path)
            .putString(KEY_ERROR, error)
            .apply()
    }

    /** 读取并清空待处理截图，返回 [path, error]（都没有则返回 null） */
    fun consume(context: Context): Map<String, String?>? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val path = prefs.getString(KEY_PATH, null)
        val error = prefs.getString(KEY_ERROR, null)
        if (path == null && error == null) return null
        prefs.edit().remove(KEY_PATH).remove(KEY_ERROR).apply()
        return mapOf("path" to path, "error" to error)
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }
}
