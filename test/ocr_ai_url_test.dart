import 'package:flutter_test/flutter_test.dart';
import 'package:gongmo/data/services/ocr_ai_service.dart';

void main() {
  group('OcrAiService.normalizeApiUrl 接口地址补全', () {
    test('只填服务基础地址时补全 /v1/chat/completions', () {
      expect(OcrAiService.normalizeApiUrl('https://api.deepseek.com'),
          'https://api.deepseek.com/v1/chat/completions');
    });

    test('已带 /v1 时只补方法路径', () {
      expect(OcrAiService.normalizeApiUrl('https://api.deepseek.com/v1'),
          'https://api.deepseek.com/v1/chat/completions');
    });

    test('尾部斜杠会被清理', () {
      expect(OcrAiService.normalizeApiUrl('https://api.deepseek.com/v1/'),
          'https://api.deepseek.com/v1/chat/completions');
    });

    test('compatible-mode 地址', () {
      expect(
          OcrAiService.normalizeApiUrl(
              'https://dashscope.aliyuncs.com/compatible-mode/v1'),
          'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions');
    });

    test('非 v1 版本段（智谱 v4）', () {
      expect(OcrAiService.normalizeApiUrl('https://open.bigmodel.cn/api/paas/v4'),
          'https://open.bigmodel.cn/api/paas/v4/chat/completions');
    });

    test('完整地址保持不变', () {
      expect(
          OcrAiService.normalizeApiUrl(
              'https://api.openai.com/v1/chat/completions'),
          'https://api.openai.com/v1/chat/completions');
    });

    test('空地址返回默认地址', () {
      expect(OcrAiService.normalizeApiUrl('  '), OcrAiService.defaultApiUrl);
    });
  });
}
