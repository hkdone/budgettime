import 'package:flutter_test/flutter_test.dart';
import 'package:budgettime/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App starts and shows Login Page by default', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: BudgetTimeApp()));

    // Verify that we start at the Login Page (since no auth).
    expect(find.text('Login Page'), findsOneWidget);
    expect(find.text('Dashboard Page'), findsNothing);
  });
}
