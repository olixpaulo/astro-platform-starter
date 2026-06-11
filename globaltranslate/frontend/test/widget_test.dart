import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:globaltranslate/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('temas claro e escuro usam Material 3', () {
      expect(AppTheme.light().useMaterial3, isTrue);
      expect(AppTheme.dark().useMaterial3, isTrue);
    });

    test('brilho corresponde ao modo', () {
      expect(AppTheme.light().colorScheme.brightness, Brightness.light);
      expect(AppTheme.dark().colorScheme.brightness, Brightness.dark);
    });

    test('alto contraste produz esquema diferente', () {
      final normal = AppTheme.light();
      final contrast = AppTheme.light(highContrast: true);
      expect(normal.colorScheme.primary, isNot(contrast.colorScheme.primary));
    });
  });

  testWidgets('ecrã de login mínimo renderiza campos', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: Column(
          children: [
            TextField(decoration: InputDecoration(labelText: 'Email')),
            TextField(decoration: InputDecoration(labelText: 'Senha')),
          ],
        ),
      ),
    ));
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
  });
}
