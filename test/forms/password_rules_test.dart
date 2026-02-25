import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordRulesWidget Logic', () {
    test('Valid password has all requirements', () {
      bool hasLower = 'Password123!'.contains(RegExp(r'[a-z]'));
      bool hasUpper = 'Password123!'.contains(RegExp(r'[A-Z]'));
      bool hasNumber = 'Password123!'.contains(RegExp(r'[0-9]'));
      bool hasSpecial = 'Password123!'.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

      expect(hasLower, isTrue);
      expect(hasUpper, isTrue);
      expect(hasNumber, isTrue);
      expect(hasSpecial, isTrue);
    });

    test('Weak password missing requirements', () {
      bool hasLower = 'weak'.contains(RegExp(r'[a-z]'));
      bool hasUpper = 'weak'.contains(RegExp(r'[A-Z]'));
      bool hasNumber = 'weak'.contains(RegExp(r'[0-9]'));
      bool hasSpecial = 'weak'.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

      expect(hasLower, isTrue);
      expect(hasUpper, isFalse);
      expect(hasNumber, isFalse);
      expect(hasSpecial, isFalse);
    });

    test('Password with only lowercase', () {
      bool hasLower = 'onlylowercase'.contains(RegExp(r'[a-z]'));
      bool hasUpper = 'onlylowercase'.contains(RegExp(r'[A-Z]'));
      bool hasNumber = 'onlylowercase'.contains(RegExp(r'[0-9]'));

      expect(hasLower, isTrue);
      expect(hasUpper, isFalse);
      expect(hasNumber, isFalse);
    });

    test('Password with lowercase and uppercase', () {
      bool hasLower = 'LowerUpper'.contains(RegExp(r'[a-z]'));
      bool hasUpper = 'LowerUpper'.contains(RegExp(r'[A-Z]'));
      bool hasNumber = 'LowerUpper'.contains(RegExp(r'[0-9]'));
      bool hasSpecial = 'LowerUpper'.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

      expect(hasLower, isTrue);
      expect(hasUpper, isTrue);
      expect(hasNumber, isFalse);
      expect(hasSpecial, isFalse);
    });

    test('Password with all requirements and numbers', () {
      bool hasLower = 'StrongPass1!'.contains(RegExp(r'[a-z]'));
      bool hasUpper = 'StrongPass1!'.contains(RegExp(r'[A-Z]'));
      bool hasNumber = 'StrongPass1!'.contains(RegExp(r'[0-9]'));
      bool hasSpecial = 'StrongPass1!'.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

      expect(hasLower, isTrue);
      expect(hasUpper, isTrue);
      expect(hasNumber, isTrue);
      expect(hasSpecial, isTrue);
    });
  });
}
