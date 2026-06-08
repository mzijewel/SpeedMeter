import 'package:flutter_test/flutter_test.dart';
import 'package:speed_meter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SpeedMeterApp());
    expect(find.byType(SpeedMeterApp), findsOneWidget);
  });
}
