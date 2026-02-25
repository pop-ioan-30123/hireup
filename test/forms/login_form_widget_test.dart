import 'package:careersuitup/forms/login_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Login button becomes enabled when email and password are filled', (tester) async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginFormWidget(
            emailCtrl: emailCtrl,
            passCtrl: passCtrl,
            lang: 'RO',
            isDark: false,
            emailValid: false,
            emailTouched: false,
            remember: false,
            checkEmail: (_) {},
            onRememberChange: (_) {},
            onEmailFieldTap: () {},
            showForgotPasswordDialog: () {},
            emailBorder: () => const OutlineInputBorder(),
            onLoginPress: () async {},
            isLoginLoading: false,
            loginCooldownSeconds: 0,
            loginErrorMessage: null,
          ),
        ),
      ),
    );

    final loginButtonFinder = find.widgetWithText(ElevatedButton, 'Conectare');

    ElevatedButton button = tester.widget(loginButtonFinder);
    expect(button.onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'StrongPass1!');
    await tester.pump();

    button = tester.widget(loginButtonFinder);
    expect(button.onPressed, isNotNull);

    emailCtrl.dispose();
    passCtrl.dispose();
  });
}
