package com.gongmo.cbq.gongmo

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import java.io.File

/**
 * 截屏账单离线 OCR：ML Kit 中文识别（本机处理，不联网）。
 *
 * 除整段文字外，还返回按行/元素/包围盒的结构化结果：
 * 账单金额常是页面上字号最大的一行，且「-」可能被识别成独立元素，
 * 上层据此重建负号、挑选主金额。
 *
 * 注意：整屏截图原图可达数十 MB，直接全尺寸解码在低内存机型上
 * 容易 OutOfMemoryError 直接闪退，因此按最长边降采样后再识别，
 * 并且捕获 Throwable（Error 不会被 Exception 捕获）。
 */
object OcrRecognizer {
    /** 解码目标最长边（像素）：文字识别不需要全分辨率 */
    private const val TARGET_LONG_SIDE = 1600

    private val recognizer by lazy {
        TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
    }

    /** 识别图片文字；失败回调 null。回调在主线程执行，可直接回传 MethodChannel */
    fun recognize(path: String, onResult: (Map<String, Any>?) -> Unit) {
        var bitmap: Bitmap? = null
        try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(File(path).absolutePath, bounds)
            val options = BitmapFactory.Options().apply {
                inSampleSize =
                    calcInSampleSize(bounds.outWidth, bounds.outHeight, TARGET_LONG_SIDE)
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            val decoded = BitmapFactory.decodeFile(File(path).absolutePath, options)
            bitmap = decoded
            if (decoded == null) {
                onResult(null)
                return
            }
            val image = InputImage.fromBitmap(decoded, 0)
            recognizer.process(image)
                .addOnSuccessListener { text ->
                    val result = try {
                        buildResult(text)
                    } catch (_: Throwable) {
                        null
                    }
                    recycle(decoded)
                    onResult(result)
                }
                .addOnFailureListener {
                    recycle(decoded)
                    onResult(null)
                }
        } catch (t: Throwable) {
            // 含 OutOfMemoryError：宁可识别失败也不能让进程闪退
            recycle(bitmap)
            onResult(null)
        }
    }

    private fun buildResult(text: com.google.mlkit.vision.text.Text): Map<String, Any> {
        val lines = ArrayList<HashMap<String, Any>>()
        for (block in text.textBlocks) {
            for (line in block.lines) {
                val elements = ArrayList<String>()
                for (element in line.elements) {
                    elements.add(element.text)
                }
                val map = HashMap<String, Any>()
                map["text"] = line.text
                map["height"] = line.boundingBox?.height() ?: 0
                map["top"] = line.boundingBox?.top ?: 0
                map["elements"] = elements
                lines.add(map)
            }
        }
        val result = HashMap<String, Any>()
        result["text"] = text.text
        result["lines"] = lines
        return result
    }

    /** 2 的幂次降采样倍数：把最长边压到 target 以内 */
    private fun calcInSampleSize(width: Int, height: Int, target: Int): Int {
        if (width <= 0 || height <= 0) return 1
        var sample = 1
        var longest = maxOf(width, height)
        while (longest / sample > target) {
            sample *= 2
        }
        return sample
    }

    private fun recycle(bitmap: Bitmap?) {
        try {
            if (bitmap != null && !bitmap.isRecycled) bitmap.recycle()
        } catch (_: Throwable) {
        }
    }
}
