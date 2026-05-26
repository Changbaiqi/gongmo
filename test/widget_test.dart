import 'package:flutter_test/flutter_test.dart';

import 'package:gongmo/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const GongMoApp());
    expect(find.text('工墨'), findsOneWidget);
  });
}
