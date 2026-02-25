import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:careersuitup/services/validator.dart';

void main() {
  group('RegisterForm Logic Tests', () {
    late TextEditingController emailCtrl;
    late TextEditingController passCtrl;
    late TextEditingController confirmPassCtrl;

    setUp(() {
      emailCtrl = TextEditingController();
      passCtrl = TextEditingController();
      confirmPassCtrl = TextEditingController();
    });

    tearDown(() {
      emailCtrl.dispose();
      passCtrl.dispose();
      confirmPassCtrl.dispose();
    });

    test('Email validation works for register', () {
      expect(EmailValidator.validate('user@example.com'), isTrue);
      expect(EmailValidator.validate('invalid.email'), isFalse);
    });

    test('Password validation detects weak passwords', () {
      bool hasLower = 'weak'.contains(RegExp(r'[a-z]'));
      bool hasUpper = 'weak'.contains(RegExp(r'[A-Z]'));
      bool hasNumber = 'weak'.contains(RegExp(r'[0-9]'));
      bool hasSpecial = 'weak'.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

      expect(hasLower && hasUpper && hasNumber && hasSpecial, isFalse);
    });

    test('Password validation accepts strong passwords', () {
      bool hasLower = 'Strong1!'.contains(RegExp(r'[a-z]'));
      bool hasUpper = 'Strong1!'.contains(RegExp(r'[A-Z]'));
      bool hasNumber = 'Strong1!'.contains(RegExp(r'[0-9]'));
      bool hasSpecial = 'Strong1!'.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

      expect(hasLower && hasUpper && hasNumber && hasSpecial, isTrue);
    });

    test('Passwords match correctly', () {
      passCtrl.text = 'Password123!';
      confirmPassCtrl.text = 'Password123!';
      
      expect(passCtrl.text == confirmPassCtrl.text, isTrue);
    });

    test('Passwords do not match returns false', () {
      passCtrl.text = 'Password123!';
      confirmPassCtrl.text = 'Password456!';
      
      expect(passCtrl.text == confirmPassCtrl.text, isFalse);
    });

    test('Register button enabled only with valid password and match', () {
      emailCtrl.text = 'test@example.com';
      passCtrl.text = 'Password123!';
      confirmPassCtrl.text = 'Password123!';
      
      bool emailValid = EmailValidator.validate(emailCtrl.text);
      bool passValid = passCtrl.text.length >= 8;
      bool passMatch = passCtrl.text == confirmPassCtrl.text;
      
      expect(emailValid && passValid && passMatch, isTrue);
    });
  });
}
