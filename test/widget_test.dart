import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_spirit/main.dart';

void main() {
  testWidgets('App starts and shows splash', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: HealthySpiritApp()),
    );
    expect(find.text('Healthy Spirit'), findsOneWidget);

    // Дожидаемся таймера заставки, чтобы тест не падал
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });
}