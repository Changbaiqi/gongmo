import '../models/finance_entry.dart';

/// OCR 账单解析结果：任意字段可能为空，由确认页让用户补全/修改。
class OcrBillParseResult {
  final FinanceType? type;
  final double? amount;
  final String? merchant;

  const OcrBillParseResult({this.type, this.amount, this.merchant});

  bool get hasAmount => amount != null && amount! > 0;
}

/// 从账单页面 OCR 文字中提取 收支类型 / 金额 / 商户（纯函数，便于单测）。
///
/// 与通知解析（AutoBookkeepingService）分开：账单详情页的文案与推送通知不同，
/// 这里以「货币符号 + 元」的金额模式为主，关键词仅用于判断收支方向。
class OcrBillParser {
  OcrBillParser._();

  static const double maxAmount = 1000000.0;
  static const int _maxMerchantLength = 24;

  static OcrBillParseResult parse(String text) {
    if (text.trim().isEmpty) return const OcrBillParseResult();

    // 去掉千分位，避免 "1,234.50" 被截断
    final t = text.replaceAll(RegExp(r'[,，]'), '');

    final refund = (t.contains('退款') || t.contains('退回')) && !t.contains('失败');
    final income = refund ||
        RegExp(r'收款|已收到|收到|到账|入账|收入|红包').hasMatch(t);
    final expense =
        RegExp(r'支出|消费|付款|支付|扣款|交易|转账|账单').hasMatch(t);

    final negative = RegExp(r'[-−－]\s*[¥￥]\s*[0-9]').hasMatch(t);
    FinanceType? type;
    if (income) {
      type = FinanceType.income;
    } else if (expense || negative) {
      type = FinanceType.expense;
    }

    return OcrBillParseResult(
      type: type,
      amount: _parseAmount(t),
      merchant: _parseMerchant(t),
    );
  }

  static double? _parseAmount(String t) {
    final patterns = <RegExp>[
      RegExp(r'[-−－]\s*[¥￥]\s*([0-9]+(?:\.[0-9]+)?)'),
      RegExp(r'[-−－]\s*([0-9]+\.[0-9]{2})(?![0-9])'),
      RegExp(r'[¥￥]\s*([0-9]+(?:\.[0-9]+)?)'),
      RegExp(
          r'(?:金额|合计|实付|应付|总计|收款)\s*[:：]?\s*[¥￥]?\s*([0-9]+(?:\.[0-9]+)?)'),
      RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*元'),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(t);
      if (m == null) continue;
      final v = double.tryParse(m.group(1) ?? '');
      if (v != null && v > 0 && v < maxAmount) return v;
    }
    return null;
  }

  static String? _parseMerchant(String t) {
    final patterns = <RegExp>[
      RegExp(
          r'(?:收款方|付款方(?!式)|商户全称|商户名称|商家名称|收款人|收款账户)\s*[:：]\s*([^\n]{1,30})'),
      RegExp(r'向(.{1,30}?)(?:付款|支付|转账)'),
      RegExp(r'(?:商户|商家|店铺)\s*[:：]\s*([^\n]{1,24})'),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(t);
      final raw = m?.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      final cleaned = raw
          .replaceAll(RegExp(r'[，。,.、：:；;！!？?\s]+$'), '')
          .trim();
      if (cleaned.isEmpty || cleaned.length > _maxMerchantLength) continue;
      return cleaned;
    }
    return null;
  }
}
