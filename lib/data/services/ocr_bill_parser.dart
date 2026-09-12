import '../models/finance_entry.dart';
import 'ocr_bookkeeping_service.dart';

/// OCR 账单解析结果：任意字段可能为空，由确认页让用户补全/修改。
class OcrBillParseResult {
  final FinanceType? type;
  final double? amount;
  final String? merchant;

  const OcrBillParseResult({this.type, this.amount, this.merchant});

  bool get hasAmount => amount != null && amount! > 0;
}

/// 从账单页面 OCR 结果中提取 收支类型 / 金额 / 商户（纯函数，便于单测）。
///
/// 针对 ML Kit 的常见问题做了补偿：
/// - `-` 被识别成独立元素或与数字分开 → 元素级重建（`_rebuildLine`）；
/// - 金额页常把主金额显示为全页最大字号 → 用行包围盒高度挑选主金额；
/// - 负号/货币符号整体丢失 → 退化为「纯数字主行」并用账单语境默认支出。
class OcrBillParser {
  OcrBillParser._();

  static const double maxAmount = 1000000.0;
  static const int _maxMerchantLength = 24;

  /// 纯文本解析（无排版信息时使用）
  static OcrBillParseResult parse(String text) {
    if (text.trim().isEmpty) return const OcrBillParseResult();
    final lines =
        text.split('\n').map((e) => OcrLine(text: e)).toList(growable: false);
    return _parse(lines, _normalizeMinus(text));
  }

  /// 结构化解析：利用行文本/元素/包围盒，更适合账单截图
  static OcrBillParseResult parseOcr(OcrResult result) {
    if (result.lines.isEmpty) return parse(result.text);
    final lines = result.lines
        .map((l) => OcrLine(
              text: _rebuildLine(l),
              height: l.height,
              top: l.top,
            ))
        .toList(growable: false);
    final page =
        lines.map((l) => l.text).join('\n').trim();
    return _parse(lines, page.isEmpty ? _normalizeMinus(result.text) : page);
  }

  static OcrBillParseResult _parse(List<OcrLine> lines, String pageText) {
    if (pageText.trim().isEmpty) return const OcrBillParseResult();

    final best = _pickAmount(lines);
    final amount = best?.$1;
    final negative = best?.$3 ?? false;

    final t = _normalizeMinus(pageText).replaceAll(RegExp(r'[,，]'), '');
    final refund =
        (t.contains('退款') || t.contains('退回')) && !t.contains('失败');
    final incomeKw =
        RegExp(r'已收款|收款到账|收款成功|已到账|入账|已收到|收到|收入|红包')
            .hasMatch(t);
    final expenseKw =
        RegExp(r'支出|消费|付款|支付|扣款|交易|转账|账单').hasMatch(t);

    FinanceType? type;
    if (refund) {
      type = FinanceType.income;
    } else if (negative) {
      type = FinanceType.expense;
    } else if (incomeKw) {
      type = FinanceType.income;
    } else if (expenseKw) {
      type = FinanceType.expense;
    } else if (amount != null) {
      // 无明确关键词时，账单页默认按支出处理（移动支付以支出为主）
      type = FinanceType.expense;
    }

    return OcrBillParseResult(
      type: type,
      amount: amount,
      merchant: _parseMerchant(t),
    );
  }

  /// 统一下标点/负号写法（ML Kit 可能输出数学负号、破折号、全角横线）
  static String _normalizeMinus(String s) => s
      .replaceAll('−', '-')
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('﹣', '-')
      .replaceAll('－', '-')
      .replaceAll('＋', '+');

  /// 用行内元素重建文本，合并被拆开的负号/货币/小数点
  static String _rebuildLine(OcrLine line) {
    final els = line.elements
        .map(_normalizeMinus)
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
    var s = els.isEmpty ? _normalizeMinus(line.text) : els.join(' ');
    s = s
        .replaceAll(RegExp(r'[-]\s+(?=[0-9¥￥])'), '-')
        .replaceAllMapped(
            RegExp(r'([¥￥])\s+(?=[0-9])'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'([0-9])\s+([.,])\s+([0-9])'),
            (m) => '${m.group(1)}${m.group(2)}${m.group(3)}')
        .replaceAllMapped(
            RegExp(r'([0-9])\s+(元)'), (m) => '${m.group(1)}${m.group(2)}');
    return s.trim();
  }

  /// 是否带负号（避开日期里的连字符，如 2026-09-11）
  static bool _isNegative(String s) =>
      RegExp(r'(?:^|[^0-9])-\s*[¥￥]?\s*[0-9]').hasMatch(s);

  /// 从一行中提取金额，返回 (金额, 模式优先级)；优先级越小越可信
  static (double, int)? _amountOfLine(String raw) {
    final t = _normalizeMinus(raw).replaceAll(RegExp(r'[,，]'), '');
    final patterns = <(RegExp, int)>[
      (RegExp(r'[¥￥]\s*([0-9]+(?:\.[0-9]+)?)'), 0),
      (
        RegExp(
            r'(?:金额|合计|实付|应付|总计|支付|付款|扣款|消费|收款)\s*[:：]?\s*[¥￥]?\s*([0-9]+(?:\.[0-9]+)?)'),
        1
      ),
      (RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*元'), 2),
      (RegExp(r'^[-+]?\s*([0-9]{1,3}(?:[0-9,]*)(?:\.[0-9]{1,2})?)$'), 3),
    ];
    for (final (re, priority) in patterns) {
      final m = re.firstMatch(t);
      if (m == null) continue;
      final v = double.tryParse(m.group(1) ?? '');
      if (v != null && v > 0 && v < maxAmount) return (v, priority);
    }
    return null;
  }

  /// 挑选主金额：优先可信模式，同级取字号最大的一行
  static (double, int, bool)? _pickAmount(List<OcrLine> lines) {
    (double, int, bool)? best;
    var bestHeight = -1.0;
    for (final line in lines) {
      final parsed = _amountOfLine(line.text);
      if (parsed == null) continue;
      final (value, priority) = parsed;
      final candidate = (value, priority, _isNegative(line.text));
      final better = best == null ||
          priority < best.$2 ||
          (priority == best.$2 && line.height > bestHeight);
      if (better) {
        best = candidate;
        bestHeight = line.height;
      }
    }
    return best;
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
