import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:katering_grecia_app/main.dart';

void main() {
  testWidgets('App initializes correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KateringGreciaApp(),
      ),
    );

    expect(find.byType(KateringGreciaApp), findsOneWidget);
  });
}
