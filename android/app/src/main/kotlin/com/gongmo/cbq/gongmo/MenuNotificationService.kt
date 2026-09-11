package com.gongmo.cbq.gongmo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * 「截屏记账」常驻通知服务。
 *
 * 以 specialUse 前台服务常驻一条自定义布局通知：
 * 通知主体内嵌「自动记账」按钮（RemoteViews），点击即拉起
 * [OcrBridgeActivity]，由无障碍服务截屏后进入识别确认浮层；
 * 左侧信息区点击打开应用。由设置页开关控制启停（MethodChannel）。
 */
class MenuNotificationService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startForegroundCompat(buildNotification())
        running = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
                running = false
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                val nm = getSystemService(NotificationManager::class.java)
                nm.notify(NOTIFICATION_ID, buildNotification())
                running = true
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    private fun startForegroundCompat(notification: Notification) {
        try {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                else 0
            )
        } catch (e: Exception) {
            // 前台服务启动失败时不崩溃，退回普通通知
            try {
                val nm = getSystemService(NotificationManager::class.java)
                nm.notify(NOTIFICATION_ID, notification)
            } catch (_: Exception) {
            }
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val openPi = PendingIntent.getActivity(
            this, 100, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val captureIntent = Intent(this, OcrBridgeActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val capturePi = PendingIntent.getActivity(
            this, 101, captureIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 自定义通知布局：主体内嵌「截图记账」按钮（RemoteViews），
        // 不再依赖系统通知的 action 按钮（MIUI 等会默认折叠）
        val views = RemoteViews(packageName, R.layout.notification_menu).apply {
            setOnClickPendingIntent(R.id.notify_capture, capturePi)
            setOnClickPendingIntent(R.id.notify_texts, openPi)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_gongmo)
            .setContentTitle(getString(R.string.notification_menu_title))
            .setContentText(getString(R.string.notification_menu_subtitle))
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(views)
            .setCustomBigContentView(views)
            .setOngoing(true)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            // 点信息区打开应用；右侧按钮由 RemoteViews 单独绑定截屏
            .setContentIntent(openPi)
            .addAction(0, getString(R.string.notification_action_capture), capturePi)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "记账菜单",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "截屏记账快捷菜单"
            setShowBadge(false)
        }
        nm.createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "gongmo_menu"
        const val NOTIFICATION_ID = 2001
        const val ACTION_STOP = "com.gongmo.cbq.gongmo.MENU_STOP"

        @Volatile
        var running = false
            private set
    }
}
