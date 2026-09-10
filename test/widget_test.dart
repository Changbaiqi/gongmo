import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gongmo/core/widgets/pattern_lock.dart';
import 'package:gongmo/modules/work/stopwatch_page.dart';

void main() {
  testWidgets('图案锁渲染并回调拖拽选中的点', (WidgetTester tester) async {
    List<int>? completed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PatternLock(
              size: 260,
              onCompleted: (p) => completed = p,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PatternLock), findsOneWidget);

    // 从左上角圆点拖到中上圆点（格子中心约 43.3，间隔约 86.7）
    final rect = tester.getRect(find.byType(PatternLock));
    final start = rect.topLeft + const Offset(43.3, 43.3);
    await tester.dragFrom(start, const Offset(86.7, 0));
    await tester.pumpAndSettle();

    expect(completed, isNotNull);
    expect(completed, [0, 1]);
  });

  testWidgets('秒表：开始/计次/复位不报错（多 AnimationController）',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: StopwatchPage()));
    expect(find.text('秒表'), findsOneWidget);

    // 开始：会同时使用 _pulse 与 _pop 两个 AnimationController
    await tester.tap(find.byIcon(Icons.play_arrow_rounded), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    // 计次：触发 _pop 缩放动画
    await tester.tap(find.byIcon(Icons.flag_rounded), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));

    // 暂停后左侧按钮变为「复位」
    await tester.tap(find.byIcon(Icons.pause_rounded), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.refresh_rounded), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('秒表：复位保存历史，可在历史弹窗查看',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: StopwatchPage()));

    // 开始 → 计次 → 暂停 → 复位（复位即保存一条历史）
    await tester.tap(find.byIcon(Icons.play_arrow_rounded), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byIcon(Icons.flag_rounded), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.pause_rounded), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.refresh_rounded), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));

    // 打开历史弹窗
    await tester.tap(find.byIcon(Icons.history_rounded), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('秒表历史'), findsOneWidget);
    expect(find.textContaining('次计次'), findsWidgets);
  });
}
