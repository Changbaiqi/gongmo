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

  test('扫码收款文案记为收入（含付款方名字）', () {
    final r =
        AutoBookkeepingService.parseAlipay('豪瑜通过扫码向你付款20.50元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.income);
    expect(r.$2, 20.50);
    expect(r.$3, '豪瑜');
  });

  test('他人向你转账记为收入', () {
    final r = AutoBookkeepingService.parseAlipay('小明向你转账88.00元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.income);
    expect(r.$2, 88.00);
  });

  test('支付宝到账文案记为收入', () {
    final r = AutoBookkeepingService.parseAlipay('支付宝到账20.50元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.income);
    expect(r.$2, 20.50);
  });

  test('主动转账仍记为支出', () {
    final r = AutoBookkeepingService.parseAlipay('你已转账给小明20.50元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 20.50);
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

  test('解析美团月付支付通知', () {
    final r = AutoBookkeepingService.parseMeituan('【美团月付】成功支付11.78元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 11.78);
    expect(r.$3, '美团月付');
  });

  test('解析美团支付成功文案（合计）', () {
    final r = AutoBookkeepingService.parseMeituan('美团支付成功，合计12.00元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 12.0);
  });

  test('解析美团退款通知', () {
    final r = AutoBookkeepingService.parseMeituan('【美团】退款5.00元已原路退回');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.income);
    expect(r.$2, 5.0);
  });

  test('解析美团收款到账通知', () {
    final r = AutoBookkeepingService.parseMeituan('美团收款到账6.00元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.income);
    expect(r.$2, 6.0);
  });

  test('美团营销/订单文本不误记账', () {
    expect(AutoBookkeepingService.parseMeituan('您有1个红包即将过期'), isNull);
    expect(AutoBookkeepingService.parseMeituan('您的订单预计30分钟送达'), isNull);
  });

  test('美团广告通知不误记账（含支付/消费字样的推广）', () {
    expect(
        AutoBookkeepingService.parseMeituan(
            '【美团】您有1张外卖红包待领取，点击领取立减20元'),
        isNull);
    expect(
        AutoBookkeepingService.parseMeituan('【美团外卖】限时特惠，￥9.9起，点击查看'),
        isNull);
    expect(
        AutoBookkeepingService.parseMeituan('【美团】外卖消费券限时领取，支付立减￥5'),
        isNull);
    expect(
        AutoBookkeepingService.parseMeituan('【美团】您的订单金额￥23.50，正在配送中'),
        isNull);
    expect(
        AutoBookkeepingService.parseMeituan('【美团月付】您的账单即将到期，请及时还款'),
        isNull);
  });

  test('美团真实支付通知仍能记账', () {
    final r = AutoBookkeepingService.parseMeituan('【美团月付】成功支付11.78元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 11.78);
  });

  test('parseNotification 分发美团', () {
    final r = AutoBookkeepingService.parseNotification(
        'meituan', '【美团月付】成功支付11.78元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 11.78);
  });

  test('解析微信个人收款码到账通知', () {
    final r =
        AutoBookkeepingService.parseWechat('[3条]微信支付：个人收款码到账￥5.00');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.income);
    expect(r.$2, 5.00);
  });

  test('解析支付宝免密扣款（中文商户名）', () {
    final r = AutoBookkeepingService.parseAlipay(
        '你在滴滴出行有一笔13.00元的免密/自动扣款支付，点击领取6个支付宝积分。');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 13.00);
    expect(r.$3, '滴滴出行');
  });

  test('解析账户付款成功通知', () {
    final r = AutoBookkeepingService.parseAlipay(
        '账户208**@qq.com于09月19日21时02分成功付款38.00元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 38.00);
  });

  test('解析美团支付成功（带剩余额度）', () {
    final r =
        AutoBookkeepingService.parseMeituan('成功支付257.75元，查看剩余额度>>');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 257.75);
  });

  test('长通知正文在 bigText 时也能解析（折叠通知）', () {
    final full = AutoBookkeepingService.composeEventText(
      title: '支付宝',
      text: '你有一笔新的交易',
      raw: {
        'bigText': '你在滴滴出行有一笔13.00元的免密/自动扣款支付，点击领取6个支付宝积分。',
      },
    );
    final r = AutoBookkeepingService.parseAlipay(full);
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 13.00);
    expect(r.$3, '滴滴出行');
  });

  test('composeEventText 合并 textLines 并去重', () {
    final full = AutoBookkeepingService.composeEventText(
      title: '支付宝',
      text: '通知',
      raw: {
        'textLines': [
          '账户208**@qq.com于09月19日21时02分成功付款38.00元',
          '通知',
        ],
      },
    );
    expect(full.contains('38.00'), isTrue);
    expect('通知'.allMatches(full).length, 1);
  });

  test('美团长通知（bigText）能解析', () {
    final full = AutoBookkeepingService.composeEventText(
      title: '美团',
      text: '支付成功',
      raw: {'bigText': '成功支付257.75元，查看剩余额度>>'},
    );
    final r = AutoBookkeepingService.parseMeituan(full);
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 257.75);
  });

  test('解析招商银行扣款通知（记为支出）', () {
    final r = AutoBookkeepingService.parseNotification(
        'cmb', '您尾号9058的账户扣款人民币287.33元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.expense);
    expect(r.$2, 287.33);
  });

  test('解析招商银行入账通知（记为收入）', () {
    final r = AutoBookkeepingService.parseNotification(
        'cmb', '您尾号9058的账户入账人民币466.00元');
    expect(r, isNotNull);
    expect(r!.$1, FinanceType.income);
    expect(r.$2, 466.00);
  });

  test('解析招商银行其它常见文案', () {
    final transfer = AutoBookkeepingService.parseNotification(
        'cmb', '您尾号9058的账户转出人民币120.00元');
    expect(transfer, isNotNull);
    expect(transfer!.$1, FinanceType.expense);
    expect(transfer.$2, 120.00);

    final refund = AutoBookkeepingService.parseNotification(
        'cmb', '您尾号9058的账户退款人民币99.90元');
    expect(refund, isNotNull);
    expect(refund!.$1, FinanceType.income);
    expect(refund.$2, 99.90);
  });

  test('招商银行包名覆盖主应用与掌上生活', () {
    final pkgs = AutoBookkeepingService.supportedApps
        .firstWhere((a) => a.key == 'cmb')
        .allPackages
        .toList();
    expect(pkgs, contains('cmb.pb'));
    expect(pkgs, contains('com.cmbchina.ccd.pluto.cmbActivity'));
  });
}
