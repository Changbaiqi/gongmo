// ============================================================
// 自动记账通知解析单元测试
// 覆盖：支付宝（支出/免密/收入/收款/转账/立减/千分位/退款）、
//       微信（已支付/向商户付款/收款/退款/无关文本）、招行、无关文本返回 null
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:gongmo/data/models/finance_entry.dart';
import 'package:gongmo/data/services/auto_bookkeeping_service.dart';

void main() {
  test('解析支付宝支出通知', () {
    final r = AutoBookkeepingService.parseAlipay(
        '你有一笔200.00元的支出，点击领取24个支付宝积分。');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 200.00);
    expect(r.$3, isNull);
  });

  test('解析免密/自动扣款通知（含商户名）', () {
    final r = AutoBookkeepingService.parseAlipay(
        '你在luckincoffee有一笔16.9元的免密/自动扣款支付，点击领取6个支付宝积分。');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 16.9);
    expect(r.$3, 'luckincoffee');
  });

  test('解析支付宝收入通知', () {
    final r = AutoBookkeepingService.parseAlipay('你有一笔88.50元的收入，已存入余额。');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.income);
    expect(r.$2, 88.50);
  });

  test('解析成功收款文案', () {
    final r = AutoBookkeepingService.parseAlipay('支付宝成功收款 66.00 元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.income);
    expect(r.$2, 66.00);
  });

  test('解析转账文案', () {
    final r = AutoBookkeepingService.parseAlipay('你收到一笔1000元的转账');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.income);
    expect(r.$2, 1000.00);
  });

  test('解析支付宝支出（含立减权益文案）', () {
    final r =
        AutoBookkeepingService.parseAlipay('你有一笔1.50元的支出，领立减1.08元权益。');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 1.50);
  });

  test('解析支付宝支出（关键词在前）', () {
    final r = AutoBookkeepingService.parseAlipay('支出1.50元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 1.50);
  });

  test('解析支付宝消费（人民币）', () {
    final r = AutoBookkeepingService.parseAlipay('您本次消费人民币25.00元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 25.00);
  });

  test('解析支付宝支出（千分位金额）', () {
    final r = AutoBookkeepingService.parseAlipay('你有一笔1,234.50元的支出');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 1234.50);
  });

  test('无关文本返回 null', () {
    expect(AutoBookkeepingService.parseAlipay('今日天气不错，适合出行。'), isNull);
  });

  test('解析支付宝退款通知', () {
    final r = AutoBookkeepingService.parseAlipay('你有一笔1.50元的退款，已原路退回。');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.income);
    expect(r.$2, 1.50);
  });

  test('解析支付宝收到退款通知', () {
    final r =
        AutoBookkeepingService.parseAlipay('你收到一笔16.9元退款，点击查看账单详情！');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.income);
    expect(r.$2, 16.9);
  });

  test('退款失败文案不入账', () {
    expect(AutoBookkeepingService.parseAlipay('退款失败，原路退回你支付的1.50元'), isNull);
  });

  test('解析微信已支付通知', () {
    final r = AutoBookkeepingService.parseWechat('微信支付 已支付￥24.81');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 24.81);
  });

  test('解析微信已成功支付（元）通知', () {
    final r = AutoBookkeepingService.parseWechat('你已成功支付24.81元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 24.81);
  });

  test('解析微信向商户付款通知（含商户名）', () {
    final r = AutoBookkeepingService.parseWechat('向星巴克付款￥35.00');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 35.00);
    expect(r.$3, '星巴克');
  });

  test('解析微信收款到账通知', () {
    final r = AutoBookkeepingService.parseWechat('微信支付收款12.34元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.income);
    expect(r.$2, 12.34);
  });

  test('微信无关文本返回 null', () {
    expect(AutoBookkeepingService.parseWechat('今晚一起吃饭吗'), isNull);
  });

  test('解析微信退款到账通知', () {
    final r = AutoBookkeepingService.parseWechat('微信支付退款到账￥24.81');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.income);
    expect(r.$2, 24.81);
  });
}
