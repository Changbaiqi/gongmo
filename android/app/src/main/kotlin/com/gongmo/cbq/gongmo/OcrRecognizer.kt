package com.gongmo.cbq.gongmo

import android.graphics.BitmapFactory
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import java.io.File

/**
 * 截屏账单离线 OCR：ML Kit 中文识别（本机处理，不联网）。
 *
 * 直接在原生层调用，避免引入 google_mlkit_* Flutter 插件
 * （其 buildscript 硬编码 google() 仓库，国内构建易超时）。
 */
object OcrRecognizer {
    private val recognizer by lazy {
        TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
    }

    /** 识别图片文字；失败回调 null。回调在主线程执行，可直接回传 MethodChannel */
    fun recognize(path: String, onResult: (String?) -> Unit) {
        try {
            val bitmap = BitmapFactory.decodeFile(File(path).absolutePath) ?: run {
                onResult(null)
                return
            }
            val image = InputImage.fromBitmap(bitmap, 0)
            recognizer.process(image)
                .addOnSuccessListener { text ->
                    bitmap.recycle()
                    onResult(text.text)
                }
                .addOnFailureListener {
                    bitmap.recycle()
                    onResult(null)
                }
        } catch (e: Exception) {
            onResult(null)
        }
    }
}
