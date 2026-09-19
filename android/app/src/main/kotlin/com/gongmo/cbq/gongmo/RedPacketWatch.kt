package com.gongmo.cbq.gongmo

import android.content.Context
import kotlin.math.abs

/**
 * 微信红包自动记账：无障碍服务识别到「已存入零钱」结果页后，
 * 把金额暂存到这里，由 Flutter 侧取走并入账。
 *
 * 存入前做 15 秒同金额去重：结果页会持续触发内容变化事件，
 * 避免同一笔红包被重复记账。
 */
object RedPacketWatch {
    private const val PREFS = "gongmo_red_packet"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_PENDING_AMOUNT = "pending_amount"
    private const val KEY_PENDING_TIME = "pending_time"
    private const val KEY_LAST_AMOUNT = "last_amount"
    private const val KEY_LAST_AT = "last_at"
    private const val DEDUP_WINDOW_MS = 15_000L

    /** 功能是否开启（由设置页开关通过 MethodChannel 写入） */
    fun enabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ENABLED, false)

    fun setEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    /** 记录一笔刚领取的红包金额；重复事件会被忽略 */
    fun report(context: Context, amount: Double) {
        if (amount <= 0 || amount > 2000) return
        val sp = prefs(context)
        val now = System.currentTimeMillis()
        val lastAt = sp.getLong(KEY_LAST_AT, 0L)
        val lastAmount = sp.getFloat(KEY_LAST_AMOUNT, -1f).toDouble()
        if (now - lastAt < DEDUP_WINDOW_MS && abs(lastAmount - amount) < 0.001) {
            return
        }
        sp.edit()
            .putLong(KEY_LAST_AT, now)
            .putFloat(KEY_LAST_AMOUNT, amount.toFloat())
            .putFloat(KEY_PENDING_AMOUNT, amount.toFloat())
            .putLong(KEY_PENDING_TIME, now)
            .apply()
    }

    /** Flutter 侧取走待记账红包（金额 + 领取时间戳，毫秒） */
    fun consume(context: Context): Map<String, Any>? {
        val sp = prefs(context)
        if (!sp.contains(KEY_PENDING_AMOUNT)) return null
        val amount = sp.getFloat(KEY_PENDING_AMOUNT, 0f).toDouble()
        val time = sp.getLong(KEY_PENDING_TIME, 0L)
        sp.edit()
            .remove(KEY_PENDING_AMOUNT)
            .remove(KEY_PENDING_TIME)
            .apply()
        if (amount <= 0) return null
        return mapOf("amount" to amount, "time" to time)
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
