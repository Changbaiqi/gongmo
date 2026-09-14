package com.gongmo.cbq.gongmo

import android.app.Application
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 应用入口 Application：尽早安装未捕获异常记录器。
 *
 * 闪退（尤其是服务进程里的崩溃）可能发生在没有 Activity 的时候，
 * 因此日志安装放在 Application 里，写入 filesDir/crash_log.txt
 * （与 Flutter 侧的崩溃日志同一个文件），设置页「崩溃日志」可查看。
 */
class GongmoApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        installCrashLogger()
    }

    private fun installCrashLogger() {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val file = File(filesDir, "crash_log.txt")
                if (file.exists() && file.length() > 256 * 1024) file.delete()
                val time = SimpleDateFormat("MM-dd HH:mm:ss", Locale.US)
                    .format(Date())
                file.appendText(
                    "\n=== $time (native/${thread.name}) ===\n" +
                        Log.getStackTraceString(throwable) + "\n"
                )
            } catch (_: Throwable) {
            }
            previous?.uncaughtException(thread, throwable)
        }
    }
}
