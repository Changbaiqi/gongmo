import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/category.dart';
import '../models/finance_entry.dart';
import 'storage_service.dart';

/// AI 识别业务异常，message 可直接展示给用户
class AiOcrException implements Exception {
  final String message;
  AiOcrException(this.message);
  @override
  String toString() => message;
}

/// AI 识别的账单结果
class AiBillResult {
  final FinanceType type;
  final double? amount;

  /// 匹配到的分类 id（未匹配到为 null）
  final String? categoryId;
  final String? merchant;
  final String? note;
  final DateTime? date;

  /// 模型原始输出（用于确认页展示“识别原文”）
  final String rawText;

  const AiBillResult({
    required this.type,
    this.amount,
    this.categoryId,
    this.merchant,
    this.note,
    this.date,
    this.rawText = '',
  });
}

/// AI 识图记账：调用 OpenAI 兼容的视觉大模型接口，
/// 从账单截图中提取 收支方向 / 金额 / 分类 / 商户备注。
///
/// 配置（URL/模型存 config.json，Key 存 flutter_secure_storage）：
/// - `ai_api_url`    完整接口地址，如 https://api.openai.com/v1/chat/completions
/// - `ai_api_model`  模型名，如 gpt-4o-mini / qwen-vl-plus / glm-4v
/// - `ai_api_key`    安全存储中的 API Key
class OcrAiService {
  OcrAiService._();
  static final OcrAiService instance = OcrAiService._();

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyApiKey = 'ai_api_key';

  static const String defaultApiUrl =
      'https://api.openai.com/v1/chat/completions';
  static const String defaultModel = 'gpt-4o-mini';

  /// 规范化接口地址：既支持完整 chat/completions 地址，也支持只填服务基础地址。
  ///
  /// - https://api.deepseek.com            → …/v1/chat/completions
  /// - https://api.deepseek.com/v1         → …/v1/chat/completions
  /// - https://dashscope.aliyuncs.com/compatible-mode/v1 → …/chat/completions
  /// - https://open.bigmodel.cn/api/paas/v4 → …/chat/completions
  static String normalizeApiUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return defaultApiUrl;
    s = s.replaceAll(RegExp(r'/+$'), '');
    if (s.endsWith('/chat/completions')) return s;
    // 已带版本段（v1 / v4 / v1beta / compatible-mode/v1 等）时只补方法路径
    if (RegExp(r'/(v\d+(?:beta)?|compatible-mode/v\d+)$').hasMatch(s)) {
      return '$s/chat/completions';
    }
    return '$s/v1/chat/completions';
  }

  final StorageService _storage = StorageService();

  String get apiUrl {
    final v = _storage.getConfig('ai_api_url') as String?;
    return (v == null || v.trim().isEmpty) ? defaultApiUrl : v.trim();
  }

  String get model {
    final v = _storage.getConfig('ai_api_model') as String?;
    return (v == null || v.trim().isEmpty) ? defaultModel : v.trim();
  }

  Future<String> getApiKey() async =>
      (await _secure.read(key: _keyApiKey) ?? '').trim();

  Future<void> saveApiKey(String key) async {
    final clean = key.trim();
    if (clean.isEmpty) {
      await _secure.delete(key: _keyApiKey);
    } else {
      await _secure.write(key: _keyApiKey, value: clean);
    }
  }

  /// 调用视觉模型识别账单截图。失败抛出 [AiOcrException]。
  Future<AiBillResult> recognize({
    required String imagePath,
    required List<Category> categories,
  }) async {
    final key = await getApiKey();
    if (key.isEmpty) {
      throw AiOcrException('尚未配置 AI API Key');
    }
    final url = normalizeApiUrl(apiUrl);
    if (url.isEmpty) {
      throw AiOcrException('尚未配置 AI 接口地址');
    }

    final bytes = await File(imagePath).readAsBytes();
    final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    final categoryList = categories
        .map((c) =>
            '${c.type == FinanceType.expense ? '支出' : '收入'}:${c.name}')
        .join('、');
    final now = DateTime.now();
    final prompt = '''
你是记账助手。请识别这张账单截图，并只返回一个 JSON 对象（不要 Markdown 代码块、不要任何多余文字），字段如下：
{"type":"expense 或 income","amount":数字,"category":"分类名","merchant":"商户名","note":"备注","date":"yyyy-MM-dd HH:mm"}
要求：
1. type 只能是 "expense"（支出）或 "income"（收入）；
2. amount 为账单实际金额（正数）；
3. category 必须从以下分类中选择最匹配的一项（只填分类名，不要编号）：$categoryList；
4. merchant 填商户/收款方名称，没有则空串；note 填补充说明，没有则空串；
5. date 为账单时间，无法识别则空串；今天是 ${now.year}-${now.month}-${now.day}。
''';

    final body = json.encode({
      'model': model,
      'temperature': 0,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': dataUrl},
            },
          ],
        }
      ],
    });

    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 45));
    } on SocketException {
      throw AiOcrException('网络连接失败');
    } on TimeoutException {
      throw AiOcrException('请求超时');
    } catch (e) {
      throw AiOcrException('请求失败');
    }

    if (res.statusCode == 401) {
      throw AiOcrException('API Key 无效或未授权');
    }
    if (res.statusCode == 429) {
      throw AiOcrException('请求过于频繁或额度不足');
    }
    if (res.statusCode == 404) {
      final detail = _errorDetail(res);
      throw AiOcrException(
          '接口地址或模型不存在（HTTP 404）${detail == null ? '' : '：$detail'}。'
          '请检查 API 地址与模型名（地址填基础域名也会自动补全 /v1/chat/completions）');
    }
    if (res.statusCode != 200) {
      final detail = _errorDetail(res);
      throw AiOcrException(
          '服务返回 HTTP ${res.statusCode}${detail == null ? '' : '：$detail'}');
    }

    final String content;
    try {
      final decoded = json.decode(utf8.decode(res.bodyBytes));
      final choices = decoded is Map ? decoded['choices'] : null;
      final message =
          (choices is List && choices.isNotEmpty && choices.first is Map)
              ? (choices.first as Map)['message']
              : null;
      final raw = (message is Map) ? message['content'] : null;
      if (raw is String) {
        content = raw;
      } else if (raw is List) {
        content = raw
            .whereType<Map>()
            .map((e) => '${e['text'] ?? ''}')
            .join();
      } else {
        throw AiOcrException('响应格式异常');
      }
    } catch (e) {
      if (e is AiOcrException) rethrow;
      throw AiOcrException('响应解析失败');
    }

    return _parseContent(content, categories);
  }

  /// 提取服务端返回的错误说明（error.message / message / msg）
  String? _errorDetail(http.Response res) {
    try {
      final body = json.decode(utf8.decode(res.bodyBytes));
      if (body is Map) {
        final err = body['error'];
        if (err is Map && err['message'] is String) {
          return (err['message'] as String).trim();
        }
        if (body['message'] is String) return (body['message'] as String).trim();
        if (body['msg'] is String) return (body['msg'] as String).trim();
      }
    } catch (_) {}
    return null;
  }

  AiBillResult _parseContent(String content, List<Category> categories) {
    var text = content.trim();
    // 去掉可能出现的 Markdown 代码块
    if (text.startsWith('```')) {
      text = text
          .replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw AiOcrException('模型未返回有效账单信息');
    }
    Map<String, dynamic> map;
    try {
      map = Map<String, dynamic>.from(
          json.decode(text.substring(start, end + 1)) as Map);
    } catch (_) {
      throw AiOcrException('模型返回内容无法解析');
    }

    final typeRaw = '${map['type'] ?? ''}'.toLowerCase();
    final type = (typeRaw.contains('income') || typeRaw.contains('收入'))
        ? FinanceType.income
        : FinanceType.expense;

    double? amount;
    final amountRaw = map['amount'];
    if (amountRaw is num) {
      amount = amountRaw.toDouble();
    } else {
      amount = double.tryParse('$amountRaw'.replaceAll(RegExp(r'[^0-9.]'), ''));
    }
    if (amount != null && (amount <= 0 || amount >= 1000000)) amount = null;

    final categoryName = '${map['category'] ?? ''}'.trim();
    String? categoryId;
    if (categoryName.isNotEmpty) {
      final sameType =
          categories.where((c) => c.type == type).toList(growable: false);
      for (final c in sameType) {
        if (c.name == categoryName) {
          categoryId = c.id;
          break;
        }
      }
      if (categoryId == null) {
        for (final c in sameType) {
          if (c.name.contains(categoryName) || categoryName.contains(c.name)) {
            categoryId = c.id;
            break;
          }
        }
      }
    }

    final merchant = '${map['merchant'] ?? ''}'.trim();
    final note = '${map['note'] ?? ''}'.trim();
    final dateRaw = '${map['date'] ?? ''}'.trim();
    final date = dateRaw.isEmpty ? null : DateTime.tryParse(dateRaw);

    return AiBillResult(
      type: type,
      amount: amount,
      categoryId: categoryId,
      merchant: merchant.isEmpty ? null : merchant,
      note: note.isEmpty ? null : note,
      date: date,
      rawText: content,
    );
  }
}
