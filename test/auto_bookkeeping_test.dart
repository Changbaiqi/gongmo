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

  test('无关文本返回 null', () {
    expect(AutoBookkeepingService.parseAlipay('今日天气不错，适合出行。'), isNull);
  });
}
