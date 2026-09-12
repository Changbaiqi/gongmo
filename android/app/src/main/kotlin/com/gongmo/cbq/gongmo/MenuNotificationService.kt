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

    private val handler = android.os.Handler(android.os.Looper.getMainLooper())

    /** 巡检：部分机型（如 MIUI）允许划掉常驻通知，被划掉后立即重新贴出 */
    private val keepAlive = object : Runnable {
        override fun run() {
            if (!running) return
            try {
                val nm = getSystemService(NotificationManager::class.java)
                val alive = nm.activeNotifications?.any { it.id == NOTIFICATION_ID } == true
                if (!alive) {
                    nm.notify(NOTIFICATION_ID, buildNotification())
                }
            } catch (_: Exception) {
            }
            handler.postDelayed(this, 3000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startForegroundCompat(buildNotification())
        running = true
        handler.removeCallbacks(keepAlive)
        handler.postDelayed(keepAlive, 3000)
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
        handler.removeCallbacks(keepAlive)
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

        // 通知内「关闭菜单」：停止常驻服务
        val stopIntent = Intent(this, MenuNotificationService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPi = PendingIntent.getService(
            this, 102, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 通知内「拍照记账」：打开应用并让 Flutter 侧进入拍照识别流程
        val photoIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
            putExtra(MainActivity.EXTRA_MENU_ACTION, "photo_bookkeeping")
        }
        val photoPi = PendingIntent.getActivity(
            this, 103, photoIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 自定义通知布局（有道翻译官快捷菜单风格）：
        // 仅一行图标按钮并占满内容区，均直接绑定点击事件
        val views = RemoteViews(packageName, R.layout.notification_menu).apply {
            setOnClickPendingIntent(R.id.notify_capture, capturePi)
            setOnClickPendingIntent(R.id.notify_photo, photoPi)
            setOnClickPendingIntent(R.id.notify_open, openPi)
            setOnClickPendingIntent(R.id.notify_stop, stopPi)
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
            // 默认级别（高于 LOW）：提升在通知栏中的排序，同时不发出提示音
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            // 点信息区打开应用；按钮点击由 RemoteViews 单独绑定
            .setContentIntent(openPi)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        // 已创建的频道无法修改重要性，这里用新频道 ID 提升级别以尽量置顶
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "记账菜单",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "截屏记账快捷菜单"
                setShowBadge(false)
                setSound(null, null) // 静音，不打扰
                enableVibration(false)
            }
            nm.createNotificationChannel(channel)
        }
        // 清理旧的低优先级频道
        try {
            nm.deleteNotificationChannel(LEGACY_CHANNEL_ID)
        } catch (_: Exception) {
        }
    }

    companion object {
        /** 提升重要级别后的新频道（置顶排序） */
        const val CHANNEL_ID = "gongmo_menu_v2"

        /** 旧频道，创建新频道时清理 */
        const val LEGACY_CHANNEL_ID = "gongmo_menu"
        const val NOTIFICATION_ID = 2001
        const val ACTION_STOP = "com.gongmo.cbq.gongmo.MENU_STOP"

        @Volatile
        var running = false
            private set
    }
}
