import 'package:careersuitup/widgets/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TopBar renders theme controls left and language dropdown', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopBarWidget(
            lang: 'RO',
            isDark: false,
            onLangChange: (_) {},
            onThemeChange: (_) {},
            trailingRight: const CircleAvatar(radius: 24),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    expect(find.byIcon(Icons.nightlight), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });
}
