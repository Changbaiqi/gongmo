package com.gongmo.cbq.gongmo

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
 */
object OcrRecognizer {
    private val recognizer by lazy {
        TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
    }

    /** 识别图片文字；失败回调 null。回调在主线程执行，可直接回传 MethodChannel */
    fun recognize(path: String, onResult: (Map<String, Any>?) -> Unit) {
        try {
            val bitmap = BitmapFactory.decodeFile(File(path).absolutePath) ?: run {
                onResult(null)
                return
            }
            val image = InputImage.fromBitmap(bitmap, 0)
            recognizer.process(image)
                .addOnSuccessListener { text ->
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
                    bitmap.recycle()
                    onResult(result)
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
