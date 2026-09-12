import 'package:flutter_test/flutter_test.dart';
import 'package:gongmo/data/models/finance_entry.dart';
import 'package:gongmo/data/services/ocr_bill_parser.dart';
import 'package:gongmo/data/services/ocr_bookkeeping_service.dart';

void main() {
  group('OcrBillParser 账单解析', () {
    test('支付宝账单页：负数金额 + 商户', () {
      final r = OcrBillParser.parse('账单详情\n-¥24.81\n支付成功\n向星巴克付款\n付款方式 余额宝');
      expect(r.type, FinanceType.expense);
      expect(r.amount, 24.81);
      expect(r.merchant, '星巴克');
    });

    test('微信收款页：收入', () {
      final r = OcrBillParser.parse('微信支付收款\n+¥12.34\n收款到账');
      expect(r.type, FinanceType.income);
      expect(r.amount, 12.34);
    });

    test('"元"金额 + 商户冒号写法', () {
      final r = OcrBillParser.parse('消费 25.00元\n商户：全家便利店');
      expect(r.type, FinanceType.expense);
      expect(r.amount, 25.0);
      expect(r.merchant, '全家便利店');
    });

    test('退款记为收入', () {
      final r = OcrBillParser.parse('退款成功\n￥16.90 已原路退回');
      expect(r.type, FinanceType.income);
      expect(r.amount, 16.9);
    });

    test('千分位金额', () {
      final r = OcrBillParser.parse('支出 1,234.50元');
      expect(r.type, FinanceType.expense);
      expect(r.amount, 1234.5);
    });

    test('银行入账人民币', () {
      final r = OcrBillParser.parse('您尾号9058的账户入账人民币1.00元');
      expect(r.type, FinanceType.income);
      expect(r.amount, 1.0);
    });

    test('无货币符号的负两位小数', () {
      final r = OcrBillParser.parse('交易成功\n-15.80\n付款方式 余额宝');
      expect(r.type, FinanceType.expense);
      expect(r.amount, 15.8);
    });

    test('日期时间不会被误识别为金额', () {
      final r = OcrBillParser.parse('2026-09-11 12:30\n账单详情');
      expect(r.amount, isNull);
      expect(r.hasAmount, isFalse);
    });

    test('无金额时仅返回类型', () {
      final r = OcrBillParser.parse('账单详情\n今天');
      expect(r.amount, isNull);
      expect(r.type, FinanceType.expense);
    });

    test('空文本返回空结果', () {
      final r = OcrBillParser.parse('   ');
      expect(r.type, isNull);
      expect(r.amount, isNull);
      expect(r.merchant, isNull);
    });
  });

  group('OcrBillParser 结构化解析（负号/主金额）', () {
    test('负号被识别为独立元素时重建', () {
      final r = OcrBillParser.parseOcr(const OcrResult(
        text: '- ¥ 24.81\n账单详情\n支付成功',
        lines: [
          OcrLine(text: '- ¥ 24.81', height: 120, elements: ['-', '¥', '24.81']),
          OcrLine(text: '账单详情', height: 30, elements: ['账单详情']),
          OcrLine(text: '支付成功', height: 30, elements: ['支付成功']),
        ],
      ));
      expect(r.type, FinanceType.expense);
      expect(r.amount, 24.81);
    });

    test('数学负号 + 无货币符号', () {
      final r = OcrBillParser.parseOcr(const OcrResult(
        text: '− 35.60\n交易成功',
        lines: [
          OcrLine(text: '− 35.60', height: 110, elements: ['−', '35.60']),
          OcrLine(text: '交易成功', height: 28, elements: ['交易成功']),
        ],
      ));
      expect(r.type, FinanceType.expense);
      expect(r.amount, 35.6);
    });

    test('多个金额时按字号选主金额', () {
      final r = OcrBillParser.parseOcr(const OcrResult(
        text: '1.00\n88.88\n账单详情',
        lines: [
          OcrLine(text: '1.00', height: 40, elements: ['1.00']),
          OcrLine(text: '88.88', height: 120, elements: ['88.88']),
          OcrLine(text: '账单详情', height: 30, elements: ['账单详情']),
        ],
      ));
      expect(r.amount, 88.88);
      expect(r.type, FinanceType.expense);
    });

    test('负号整体丢失时按账单语境默认支出', () {
      final r = OcrBillParser.parseOcr(const OcrResult(
        text: '24.81\n账单详情\n交易成功',
        lines: [
          OcrLine(text: '24.81', height: 120, elements: ['24.81']),
          OcrLine(text: '账单详情', height: 30, elements: ['账单详情']),
          OcrLine(text: '交易成功', height: 30, elements: ['交易成功']),
        ],
      ));
      expect(r.type, FinanceType.expense);
      expect(r.amount, 24.81);
    });

    test('收入关键词仍优先判定为收入', () {
      final r = OcrBillParser.parseOcr(const OcrResult(
        text: '微信转账\n已收到\n100.00',
        lines: [
          OcrLine(text: '微信转账', height: 30, elements: ['微信转账']),
          OcrLine(text: '已收到', height: 30, elements: ['已收到']),
          OcrLine(text: '100.00', height: 110, elements: ['100.00']),
        ],
      ));
      expect(r.type, FinanceType.income);
      expect(r.amount, 100.0);
    });

    test('日期时间不会被当作负号/金额', () {
      final r = OcrBillParser.parseOcr(const OcrResult(
        text: '2026-09-11 12:30\n账单详情',
        lines: [
          OcrLine(text: '2026-09-11 12:30', height: 30),
          OcrLine(text: '账单详情', height: 30),
        ],
      ));
      expect(r.amount, isNull);
      expect(r.hasAmount, isFalse);
    });
  });
}
