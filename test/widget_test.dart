import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:myapp/features/auth/presentation/pages/auth_page.dart';

void main() {
  testWidgets('Shows auth portal tabs and actions', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthPage()));

    expect(find.text('Portail JDR'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Inscription'), findsOneWidget);
    expect(find.text("Nom d'utilisateur"), findsOneWidget);
    expect(find.text('ENTRER'), findsOneWidget);
  });
}
