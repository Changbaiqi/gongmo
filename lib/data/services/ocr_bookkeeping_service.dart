import 'package:flutter/services.dart';

/// 截图账单文字识别：调用原生 ML Kit 中文离线 OCR（不联网、不上传）。
///
/// 原生实现见 android/app/src/main/kotlin/.../OcrRecognizer.kt，
/// 通过 `com.gongmo.cbq.gongmo/ocr` 通道的 `recognizeText` 方法识别。
class OcrBookkeepingService {
  OcrBookkeepingService._();
  static final OcrBookkeepingService instance = OcrBookkeepingService._();

  static const MethodChannel _channel = MethodChannel('com.gongmo.cbq.gongmo/ocr');

  /// 识别图片中的文字（中文模型同时支持数字与英文），失败返回空串
  Future<String> recognizeImage(String imagePath) async {
    try {
      final text = await _channel
          .invokeMethod<String>('recognizeText', {'path': imagePath});
      return text ?? '';
    } catch (_) {
      return '';
    }
  }
}
