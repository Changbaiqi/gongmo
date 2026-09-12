import 'package:flutter/services.dart';

/// OCR 识别出的一行文字（含字号代理值与元素）
class OcrLine {
  final String text;

  /// 行包围盒高度（像素），用作字号大小代理：账单主金额通常是最高的一行
  final double height;
  final double top;
  final List<String> elements;

  const OcrLine({
    required this.text,
    this.height = 0,
    this.top = 0,
    this.elements = const [],
  });
}

/// 结构化 OCR 结果
class OcrResult {
  final String text;
  final List<OcrLine> lines;

  const OcrResult({required this.text, this.lines = const []});
}

/// 截图账单文字识别：调用原生 ML Kit 中文离线 OCR（不联网、不上传）。
///
/// 原生实现见 android/app/src/main/kotlin/.../OcrRecognizer.kt，
/// 通过 `com.gongmo.cbq.gongmo/ocr` 通道的 `recognizeText` 方法识别。
class OcrBookkeepingService {
  OcrBookkeepingService._();
  static final OcrBookkeepingService instance = OcrBookkeepingService._();

  static const MethodChannel _channel =
      MethodChannel('com.gongmo.cbq.gongmo/ocr');

  /// 结构化识别：返回整段文字与逐行信息（含元素），失败返回空结果
  Future<OcrResult> recognize(String imagePath) async {
    try {
      final raw = await _channel
          .invokeMethod<dynamic>('recognizeText', {'path': imagePath});
      if (raw is Map) {
        final lines = <OcrLine>[];
        final rawLines = raw['lines'];
        if (rawLines is List) {
          for (final item in rawLines.whereType<Map>()) {
            lines.add(OcrLine(
              text: '${item['text'] ?? ''}',
              height: (item['height'] as num?)?.toDouble() ?? 0,
              top: (item['top'] as num?)?.toDouble() ?? 0,
              elements: (item['elements'] as List?)
                      ?.map((e) => '$e')
                      .toList(growable: false) ??
                  const [],
            ));
          }
        }
        return OcrResult(text: '${raw['text'] ?? ''}', lines: lines);
      }
      // 兼容旧版仅返回纯文本
      return OcrResult(text: raw is String ? raw : '');
    } catch (_) {
      return const OcrResult(text: '');
    }
  }

  /// 仅需要整段文字时的便捷方法
  Future<String> recognizeImage(String imagePath) async =>
      (await recognize(imagePath)).text;
}
