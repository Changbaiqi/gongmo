package com.gongmo.cbq.gongmo

import android.content.Intent
import android.net.Uri
import android.os.Build
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
                            // 系统分享面板（发送到 QQ / 微信等）
                            "shareAttachment" -> {
                                val path = call.argument<String>("path")
                                val mime = call.argument<String>("mime") ?: "*/*"
                                result.success(shareAttachment(path, mime))
                            }
                            // 创建/校正每日提醒频道（用资源 ID 指定内置提示音）
                            "ensureReminderChannel" ->
                                result.success(ensureReminderChannel())
                            // 提醒声音状态：频道是否有声音 + 小米「允许声音」开关
                            "reminderSoundState" ->
                                result.success(reminderSoundState())
                            // 打开本应用的通知设置（MIUI 的「允许声音」在此页）
                            "openNotificationSettings" -> {
                                try {
                                    startActivity(
                                        Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                            .putExtra(
                                                android.provider.Settings.EXTRA_APP_PACKAGE,
                                                packageName
                                            )
                                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    )
                                    result.success(true)
                                } catch (_: Throwable) {
                                    result.success(false)
                                }
                            }
                            // 导出日志前尽力抓取本应用的 logcat（无权限则忽略）
                            "dumpLogcat" -> result.success(dumpLogcat())
                            // 把备份包保存到公共「下载」目录（不随应用数据清理消失）
                            "saveToDownloads" -> {
                                val source = call.argument<String>("source")
                                val name = call.argument<String>("name")
                                val mime = call.argument<String>("mime")
                                    ?: "application/octet-stream"
                                val relativeDir = call.argument<String>("relativeDir")
                                result.success(saveToDownloads(source, name, mime, relativeDir))
                            }
                            // 用系统文件管理器打开公共备份目录
                            "openFolder" -> {
                                val relativeDir = call.argument<String>("relativeDir")
                                result.success(openFolder(relativeDir))
                            }
                            // 清理过旧的本地快照（只保留最近几份）
                            "pruneLocalBackups" ->
                                result.success(pruneLocalBackups())
                            // 列出公共备份目录内容（应用内「查看」展示）
                            "listLocalBackups" ->
                                result.success(listLocalBackups())
                            // 公共备份目录的绝对路径（读取快照恢复用）
                            "localBackupDirPath" -> {
                                @Suppress("DEPRECATION")
                                val base =
                                    android.os.Environment.getExternalStorageDirectory()
                                result.success(
                                    java.io.File(
                                        base,
                                        "${android.os.Environment.DIRECTORY_DOWNLOADS}/$LOCAL_BACKUP_DIR"
                                    ).absolutePath
                                )
                            }
                            // 删除某个快照目录下的所有文件（重复备份时覆盖用）
                            "deleteLocalDir" -> {
                                val relativeDir = call.argument<String>("relativeDir")
                                result.success(deleteLocalDir(relativeDir))
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
                            // 用户是否希望菜单常驻（null=从未设置过）
                            "menuDesiredState" ->
                                result.success(MenuNotificationService.desiredState(this))
                            // 微信红包自动记账：开关与待入账记录
                            "setRedPacketWatch" -> {
                                val enabled = call.argument<Boolean>("enabled") == true
                                RedPacketWatch.setEnabled(this, enabled)
                                result.success(true)
                            }
                            "consumePendingRedPacket" ->
                                result.success(RedPacketWatch.consume(this))
                            // 其它应用来通知时把常驻菜单重新贴到最前
                            "bumpMenuNotification" -> {
                                MenuNotificationService.bumpIfRunning(this)
                                result.success(true)
                            }
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

    /**
     * 尽力导出一份本应用的 logcat 到 files/logs/logcat.txt。
     * 普通应用只能读到自身进程日志，读不到或命令不可用时返回 false。
     */
    private fun dumpLogcat(): Boolean {
        return try {
            val dir = java.io.File(filesDir, "logs")
            if (!dir.exists()) dir.mkdirs()
            val out = java.io.File(dir, "logcat.txt")
            val process = ProcessBuilder("logcat", "-d", "-v", "time")
                .redirectErrorStream(true)
                .start()
            process.inputStream.use { input ->
                out.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            process.waitFor()
            out.length() > 0
        } catch (_: Throwable) {
            false
        }
    }

    /**
     * 把文件保存到公共「下载/<relativeDir>」目录。
     *
     * Android 10+ 走 MediaStore（无需任何权限）；旧版本直接写公共 Downloads。
     * 该目录属于用户存储，清理应用数据或卸载重装都不会被删除。
     * 返回用户可见路径，失败返回 null。
     */
    private fun saveToDownloads(
        source: String?,
        name: String?,
        mime: String,
        relativeDir: String?
    ): String? {
        if (source.isNullOrEmpty() || name.isNullOrEmpty()) return null
        val src = java.io.File(source)
        if (!src.exists()) return null
        val dir = (relativeDir ?: LOCAL_BACKUP_DIR).trim('/')
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = android.content.ContentValues().apply {
                    put(android.provider.MediaStore.Downloads.DISPLAY_NAME, name)
                    put(android.provider.MediaStore.Downloads.MIME_TYPE, mime)
                    put(
                        android.provider.MediaStore.Downloads.RELATIVE_PATH,
                        "${android.os.Environment.DIRECTORY_DOWNLOADS}/$dir"
                    )
                    put(android.provider.MediaStore.Downloads.IS_PENDING, 1)
                }
                val resolver = contentResolver
                val uri = resolver.insert(
                    android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    values
                ) ?: return null
                try {
                    resolver.openOutputStream(uri)?.use { out ->
                        src.inputStream().use { input -> input.copyTo(out) }
                    }
                } catch (e: Exception) {
                    resolver.delete(uri, null, null)
                    return null
                }
                val done = android.content.ContentValues().apply {
                    put(android.provider.MediaStore.Downloads.IS_PENDING, 0)
                }
                resolver.update(uri, done, null, null)
                "下载/$dir/$name"
            } else {
                @Suppress("DEPRECATION")
                val base = android.os.Environment.getExternalStoragePublicDirectory(
                    android.os.Environment.DIRECTORY_DOWNLOADS
                )
                val target = java.io.File(base, dir)
                if (!target.exists()) target.mkdirs()
                val dst = java.io.File(target, name)
                src.inputStream().use { input ->
                    dst.outputStream().use { out -> input.copyTo(out) }
                }
                dst.absolutePath
            }
        } catch (_: Throwable) {
            null
        }
    }

    /**
     * 用系统文件管理器打开「下载/工墨数据备份」目录。
     * 优先用 ExternalStorageProvider 的文档 uri 定位，失败则打开系统下载页。
     */
    private fun openFolder(relativeDir: String?): Boolean {
        val dir = (relativeDir ?: LOCAL_BACKUP_DIR).trim('/')
        return try {
            val docId = "primary:${android.os.Environment.DIRECTORY_DOWNLOADS}/$dir"
            val uri = android.provider.DocumentsContract.buildDocumentUri(
                "com.android.externalstorage.documents",
                docId
            )
            startActivity(Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "vnd.android.document/directory")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
            true
        } catch (_: Throwable) {
            try {
                startActivity(
                    Intent(android.app.DownloadManager.ACTION_VIEW_DOWNLOADS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                true
            } catch (_: Throwable) {
                false
            }
        }
    }

    /**
     * 公共目录里只保留最近 [KEEP_LOCAL_BACKUPS] 个快照目录，
     * 并清理旧格式（直接放在根目录的 .gongmo 包）。
     */
    private fun pruneLocalBackups(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
        return try {
            val resolver = contentResolver
            val collection = android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI
            val projection = arrayOf(
                android.provider.MediaStore.Downloads._ID,
                android.provider.MediaStore.Downloads.RELATIVE_PATH,
                android.provider.MediaStore.Downloads.DATE_ADDED
            )
            val root = "${android.os.Environment.DIRECTORY_DOWNLOADS}/$LOCAL_BACKUP_DIR/"
            val folderIds = LinkedHashMap<String, MutableList<Long>>()
            val folderNewest = HashMap<String, Long>()
            val rootIds = ArrayList<Long>()
            resolver.query(
                collection,
                projection,
                null,
                null,
                "${android.provider.MediaStore.Downloads.DATE_ADDED} DESC"
            )?.use { c ->
                val idIdx = c.getColumnIndexOrThrow(projection[0])
                val pathIdx = c.getColumnIndexOrThrow(projection[1])
                val dateIdx = c.getColumnIndexOrThrow(projection[2])
                while (c.moveToNext()) {
                    val rel = c.getString(pathIdx) ?: continue
                    if (!rel.startsWith(root)) continue
                    val id = c.getLong(idIdx)
                    val rest = rel.removePrefix(root).trim('/')
                    if (rest.isEmpty()) {
                        rootIds.add(id)
                        continue
                    }
                    val folder = rest.substringBefore('/')
                    folderIds.getOrPut(folder) { ArrayList() }.add(id)
                    val date = c.getLong(dateIdx)
                    val cur = folderNewest[folder]
                    if (cur == null || date > cur) folderNewest[folder] = date
                }
            }
            val sorted = folderIds.keys.sortedByDescending { folderNewest[it] ?: 0L }
            for (i in KEEP_LOCAL_BACKUPS until sorted.size) {
                folderIds[sorted[i]]?.forEach { id ->
                    resolver.delete(
                        android.content.ContentUris.withAppendedId(collection, id),
                        null,
                        null
                    )
                }
            }
            rootIds.forEach { id ->
                resolver.delete(
                    android.content.ContentUris.withAppendedId(collection, id),
                    null,
                    null
                )
            }
            true
        } catch (_: Throwable) {
            false
        }
    }

    /** 列出公共备份目录下的文件（folder 为空表示直接放在根目录的旧版备份） */
    private fun listLocalBackups(): List<Map<String, Any>> {
        val out = ArrayList<Map<String, Any>>()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return out
        return try {
            val collection = android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI
            val projection = arrayOf(
                android.provider.MediaStore.Downloads.RELATIVE_PATH,
                android.provider.MediaStore.Downloads.DISPLAY_NAME,
                android.provider.MediaStore.Downloads.SIZE,
                android.provider.MediaStore.Downloads.DATE_ADDED
            )
            val root = "${android.os.Environment.DIRECTORY_DOWNLOADS}/$LOCAL_BACKUP_DIR/"
            contentResolver.query(
                collection,
                projection,
                null,
                null,
                "${android.provider.MediaStore.Downloads.DATE_ADDED} DESC"
            )?.use { c ->
                while (c.moveToNext()) {
                    val rel = c.getString(0) ?: continue
                    if (!rel.startsWith(root)) continue
                    val rest = rel.removePrefix(root).trim('/')
                    out.add(
                        mapOf(
                            "folder" to if (rest.isEmpty()) "" else rest.substringBefore('/'),
                            "name" to (c.getString(1) ?: ""),
                            "size" to c.getLong(2),
                            "date" to c.getLong(3)
                        )
                    )
                }
            }
            out
        } catch (_: Throwable) {
            out
        }
    }

    /** 删除某个快照目录下的所有文件（短时间内重复备份时覆盖旧快照） */
    private fun deleteLocalDir(relativeDir: String?): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        if (relativeDir.isNullOrEmpty()) return false
        return try {
            val resolver = contentResolver
            val collection = android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI
            val projection = arrayOf(
                android.provider.MediaStore.Downloads._ID,
                android.provider.MediaStore.Downloads.RELATIVE_PATH
            )
            val target =
                "${android.os.Environment.DIRECTORY_DOWNLOADS}/${relativeDir.trim('/')}/"
            val ids = ArrayList<Long>()
            resolver.query(collection, projection, null, null, null)?.use { c ->
                val idIdx = c.getColumnIndexOrThrow(projection[0])
                val pathIdx = c.getColumnIndexOrThrow(projection[1])
                while (c.moveToNext()) {
                    val rel = c.getString(pathIdx) ?: continue
                    if (rel == target) ids.add(c.getLong(idIdx))
                }
            }
            for (id in ids) {
                resolver.delete(
                    android.content.ContentUris.withAppendedId(collection, id),
                    null,
                    null
                )
            }
            true
        } catch (_: Throwable) {
            false
        }
    }

    /**
     * 创建/校正「每日记账提醒」频道。
     *
     * release 构建会混淆资源名，`android.resource://包名/raw/xxx` 这种按名字
     * 取音频的 uri 会解析失败导致通知发不出来；这里用编译期资源 ID
     * （R.raw.gongmo_reminder）生成 uri，稳定可用。
     * 频道已存在时该调用不会覆盖用户手动改过的设置。
     */
    private fun ensureReminderChannel(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
            val nm = getSystemService(android.app.NotificationManager::class.java)
            val channel = android.app.NotificationChannel(
                REMINDER_CHANNEL_ID,
                "每日记账提醒",
                android.app.NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "每天定时提醒记录收支"
                enableVibration(true)
                setShowBadge(true)
                val attrs = android.media.AudioAttributes.Builder()
                    .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                    .build()
                setSound(
                    android.net.Uri.parse(
                        "android.resource://$packageName/${R.raw.gongmo_reminder}"
                    ),
                    attrs
                )
            }
            nm.createNotificationChannel(channel)
            true
        } catch (_: Throwable) {
            false
        }
    }

    /** 提醒频道的状态：{channelExists, hasSound, miuiSoundEnabled} */
    private fun reminderSoundState(): Map<String, Any> {
        val out = HashMap<String, Any>()
        var exists = false
        var hasSound = true
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val ch = getSystemService(android.app.NotificationManager::class.java)
                    .getNotificationChannel(REMINDER_CHANNEL_ID)
                exists = ch != null
                hasSound = ch?.sound != null
            }
        } catch (_: Throwable) {
        }
        out["channelExists"] = exists
        out["hasSound"] = hasSound
        out["miuiSoundEnabled"] = isMiuiNotificationSoundOn()
        return out
    }

    /**
     * 小米 ROM 的应用通知声音总开关（字段缺失时视为开启，避免误报）。
     * MIUI 13 / 澎湃 OS：mi_notification_sound_enable；MIUI 12-：notification_sound_enabled。
     */
    private fun isMiuiNotificationSoundOn(): Boolean {
        return try {
            val isMiui = try {
                val clz = Class.forName("android.os.SystemProperties")
                val get = clz.getMethod("get", String::class.java, String::class.java)
                (get.invoke(null, "ro.miui.ui.version.name", "") as String).isNotEmpty()
            } catch (_: Throwable) {
                false
            }
            if (!isMiui) return true
            val resolver = contentResolver
            val state = android.provider.Settings.Secure.getInt(
                resolver,
                "mi_notification_sound_enable",
                android.provider.Settings.Secure.getInt(
                    resolver,
                    "notification_sound_enabled",
                    1
                )
            )
            state == 1
        } catch (_: Throwable) {
            true
        }
    }

    private fun stopMenuNotification(): Boolean {
        return try {
            stopService(Intent(this, MenuNotificationService::class.java))
            // 记录"不再常驻"，避免重启/升级后自动恢复
            MenuNotificationService.setDesired(this, false)
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
    /**
     * 用系统应用打开文件（ACTION_VIEW）。
     *
     * 注意：文档目录（app_flutter）不在 FileProvider 的映射根内，
     * 直接 getUriForFile 会抛异常导致"无法打开"；这里兜底把文件复制到
     * cache/share（cache-path 已映射）再打开。
     */
    private fun openAttachment(path: String?, mime: String): Boolean {
        val uri = resolveShareableUri(path) ?: return false
        return try {
            startActivity(Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                clipData = android.content.ClipData.newUri(contentResolver, "file", uri)
            })
            true
        } catch (_: Exception) {
            false
        }
    }

    /** 分享文件：调起系统分享面板（可发送到 QQ / 微信等） */
    private fun shareAttachment(path: String?, mime: String): Boolean {
        val uri = resolveShareableUri(path) ?: return false
        return try {
            val send = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                clipData = android.content.ClipData.newUri(contentResolver, "file", uri)
            }
            startActivity(Intent.createChooser(send, "发送文件"))
            true
        } catch (_: Exception) {
            false
        }
    }

    /** 取得可分享的 content uri：文档目录不在 FileProvider 映射内时先复制到 cache/share */
    private fun resolveShareableUri(path: String?): android.net.Uri? {
        if (path.isNullOrEmpty()) return null
        val src = java.io.File(path)
        if (!src.exists()) return null
        tryGetUri(src)?.let { return it }
        val copy = copyToShareCache(src) ?: return null
        return tryGetUri(copy)
    }

    private fun tryGetUri(file: java.io.File): android.net.Uri? = try {
        androidx.core.content.FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file
        )
    } catch (_: Throwable) {
        null
    }

    /** 复制文件到 cache/share（FileProvider 已映射 cache 根） */
    private fun copyToShareCache(src: java.io.File): java.io.File? = try {
        val dir = java.io.File(cacheDir, "share")
        if (!dir.exists()) dir.mkdirs()
        val dst = java.io.File(dir, src.name)
        src.inputStream().use { input ->
            dst.outputStream().use { output -> input.copyTo(output) }
        }
        dst
    } catch (_: Throwable) {
        null
    }

    companion object {
        const val EXTRA_OCR_CAPTURE = "com.gongmo.cbq.gongmo.ocr_capture"
        const val EXTRA_OCR_RETURN = "com.gongmo.cbq.gongmo.ocr_return"

        /** 本地备份的公共目录名（下载目录下） */
        const val LOCAL_BACKUP_DIR = "工墨数据备份"

        /** 每日记账提醒的通知频道（与 Dart 侧保持一致） */
        const val REMINDER_CHANNEL_ID = "daily_bookkeeping_reminder_v4"

        /** 公共目录里最多保留的本地备份份数 */
        const val KEEP_LOCAL_BACKUPS = 3

        /** 常驻通知菜单按钮动作（值如 photo_bookkeeping） */
        const val EXTRA_MENU_ACTION = "com.gongmo.cbq.gongmo.menu_action"

        /** 最近一次 onPause 时刻（elapsedRealtime），用于判断截屏时应用是否在前台 */
        @Volatile
        var lastPausedAt = 0L
            private set
    }
}
