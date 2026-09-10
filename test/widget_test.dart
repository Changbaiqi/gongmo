import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gongmo/core/widgets/pattern_lock.dart';

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
}
