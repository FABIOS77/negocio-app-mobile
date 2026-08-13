import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katering_grecia_app/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders empty fields by default and toggles password visibility', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Campos inician vacíos
    final emailWidget = tester.widget<TextFormField>(find.byKey(const Key('emailField')));
    final passwordWidget = tester.widget<TextFormField>(find.byKey(const Key('passwordField')));

    expect(emailWidget.controller?.text, isEmpty);
    expect(passwordWidget.controller?.text, isEmpty);

    // 2. Toggle visibilidad de contraseña
    final toggleIcon = find.byIcon(Icons.visibility);
    expect(toggleIcon, findsOneWidget);

    await tester.tap(toggleIcon);
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
  });

  testWidgets('LoginScreen preserves typed text without reverting to default values', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('emailField')), 'cocina@katering.com');
    await tester.enterText(find.byKey(const Key('passwordField')), 'CocinaPass123!');
    await tester.pump();

    final emailWidget = tester.widget<TextFormField>(find.byKey(const Key('emailField')));
    final passwordWidget = tester.widget<TextFormField>(find.byKey(const Key('passwordField')));

    expect(emailWidget.controller?.text, equals('cocina@katering.com'));
    expect(passwordWidget.controller?.text, equals('CocinaPass123!'));
  });
}
