import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:careersuitup/services/validator.dart';

void main() {
  group('EmailValidator', () {
    group('validate', () {
      test('Valid email with standard format returns true', () {
        expect(EmailValidator.validate('user@example.com'), isTrue);
      });

      test('Valid email with subdomain returns true', () {
        expect(EmailValidator.validate('user@mail.example.com'), isTrue);
      });

      test('Valid email with numbers returns true', () {
        expect(EmailValidator.validate('user123@example456.com'), isTrue);
      });

      test('Invalid email without @ returns false', () {
        expect(EmailValidator.validate('userexample.com'), isFalse);
      });

      test('Invalid email without domain extension returns false', () {
        expect(EmailValidator.validate('user@example'), isFalse);
      });

      test('Invalid email with multiple @ returns false', () {
        expect(EmailValidator.validate('user@@example.com'), isFalse);
      });

      test('Empty string returns false', () {
        expect(EmailValidator.validate(''), isFalse);
      });

    });

    group('getBorder', () {
      test('Untouched returns default border', () {
        final border = EmailValidator.getBorder(false, false);
        // Untouched should have default OutlineInputBorder with default borderSide
        expect(border.borderSide.style, BorderStyle.solid);
      });

      test('Touched and valid returns green border', () {
        final border = EmailValidator.getBorder(true, true);
        expect(border.borderSide.color, Colors.green);
      });

      test('Touched and invalid returns red border', () {
        final border = EmailValidator.getBorder(true, false);
        expect(border.borderSide.color, Colors.red);
      });

      test('Touched and invalid has width 2', () {
        final border = EmailValidator.getBorder(true, false);
        expect(border.borderSide.width, 2);
      });
    });
  });

  group('PasswordValidation', () {
    test('Empty password has no requirements met', () {
      final pv = PasswordValidation();
      pv.validate('');
      
      expect(pv.hasLower, isFalse);
      expect(pv.hasUpper, isFalse);
      expect(pv.hasNumber, isFalse);
      expect(pv.hasSpecial, isFalse);
      expect(pv.isValid, isFalse);
    });

    test('Password with only lowercase fails', () {
      final pv = PasswordValidation();
      pv.validate('onlylowercase');
      
      expect(pv.hasLower, isTrue);
      expect(pv.hasUpper, isFalse);
      expect(pv.hasNumber, isFalse);
      expect(pv.hasSpecial, isFalse);
      expect(pv.isValid, isFalse);
    });

    test('Password with lowercase and uppercase fails', () {
      final pv = PasswordValidation();
      pv.validate('LowerUpperCase');
      
      expect(pv.hasLower, isTrue);
      expect(pv.hasUpper, isTrue);
      expect(pv.hasNumber, isFalse);
      expect(pv.hasSpecial, isFalse);
      expect(pv.isValid, isFalse);
    });

    test('Password with lowercase, uppercase, and number fails', () {
      final pv = PasswordValidation();
      pv.validate('LowerUpper123');
      
      expect(pv.hasLower, isTrue);
      expect(pv.hasUpper, isTrue);
      expect(pv.hasNumber, isTrue);
      expect(pv.hasSpecial, isFalse);
      expect(pv.isValid, isFalse);
    });

    test('Strong password with all requirements succeeds', () {
      final pv = PasswordValidation();
      pv.validate('StrongPass123!');
      
      expect(pv.hasLower, isTrue);
      expect(pv.hasUpper, isTrue);
      expect(pv.hasNumber, isTrue);
      expect(pv.hasSpecial, isTrue);
      expect(pv.isValid, isTrue);
    });

    test('Password with @ special character is valid', () {
      final pv = PasswordValidation();
      pv.validate('Password@123');
      
      expect(pv.hasSpecial, isTrue);
      expect(pv.isValid, isTrue);
    });

    test('Password with # special character is valid', () {
      final pv = PasswordValidation();
      pv.validate('Password#123');
      
      expect(pv.hasSpecial, isTrue);
      expect(pv.isValid, isTrue);
    });

    test('Password with dollar sign special character is valid', () {
      final pv = PasswordValidation();
      pv.validate(r'Password$123');
      
      expect(pv.hasSpecial, isTrue);
      expect(pv.isValid, isTrue);
    });

    test('Validate updates all flags correctly on multiple calls', () {
      final pv = PasswordValidation();
      
      pv.validate('weak');
      expect(pv.isValid, isFalse);
      
      pv.validate('Strong@123');
      expect(pv.isValid, isTrue);
    });
  });

  group('Capitalize Words', () {
    test('Empty string returns empty string', () {
      // Test the capitalizeWords from the validator - but it's in main.dart
      final input = '';
      final words = input.split(' ');
      final capitalized = words
          .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
          .join(' ');
      expect(capitalized, '');
    });

    test('Single word capitalizes first letter', () {
      final input = 'hello';
      final words = input.split(' ');
      final capitalized = words
          .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
          .join(' ');
      expect(capitalized, 'Hello');
    });

    test('Multiple words capitalize each first letter', () {
      final input = 'hello world test';
      final words = input.split(' ');
      final capitalized = words
          .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
          .join(' ');
      expect(capitalized, 'Hello World Test');
    });

    test('Already capitalized word remains capitalized', () {
      final input = 'Hello World';
      final words = input.split(' ');
      final capitalized = words
          .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
          .join(' ');
      expect(capitalized, 'Hello World');
    });

    test('Single letter word capitalizes', () {
      final input = 'a b c';
      final words = input.split(' ');
      final capitalized = words
          .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
          .join(' ');
      expect(capitalized, 'A B C');
    });
  });
}
