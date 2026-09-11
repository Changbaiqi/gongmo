import 'package:flutter_test/flutter_test.dart';
import 'package:gongmo/data/models/finance_entry.dart';
import 'package:gongmo/data/services/ocr_bill_parser.dart';

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
}
