import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:careersuitup/services/validator.dart';

void main() {
  group('LoginForm Logic Tests', () {
    late TextEditingController emailCtrl;
    late TextEditingController passCtrl;

    setUp(() {
      emailCtrl = TextEditingController();
      passCtrl = TextEditingController();
    });

    tearDown(() {
      emailCtrl.dispose();
      passCtrl.dispose();
    });

    test('Email controller can be updated', () {
      emailCtrl.text = 'test@example.com';
      expect(emailCtrl.text, 'test@example.com');
    });

    test('Password controller can be updated', () {
      passCtrl.text = 'password123';
      expect(passCtrl.text, 'password123');
    });

    test('Email validation works correctly', () {
      expect(EmailValidator.validate('test@example.com'), isTrue);
      expect(EmailValidator.validate('invalid'), isFalse);
    });

    test('Login button enabled with valid email and password', () {
      emailCtrl.text = 'test@example.com';
      passCtrl.text = 'password123';
      
      bool emailValid = EmailValidator.validate(emailCtrl.text);
      bool passNotEmpty = passCtrl.text.trim().isNotEmpty;
      
      expect(emailValid && passNotEmpty, isTrue);
    });

    test('Login button disabled with invalid email', () {
      emailCtrl.text = 'invalid';
      passCtrl.text = 'password123';
      
      bool emailValid = EmailValidator.validate(emailCtrl.text);
      bool passNotEmpty = passCtrl.text.trim().isNotEmpty;
      
      expect(emailValid && passNotEmpty, isFalse);
    });

    test('Login button disabled with empty password', () {
      emailCtrl.text = 'test@example.com';
      passCtrl.text = '';
      
      bool emailValid = EmailValidator.validate(emailCtrl.text);
      bool passNotEmpty = passCtrl.text.trim().isNotEmpty;
      
      expect(emailValid && passNotEmpty, isFalse);
    });
  });
}
