import 'package:flutter/material.dart';

class PasswordValidation {
  bool hasLower = false;
  bool hasUpper = false;
  bool hasNumber = false;
  bool hasSpecial = false;

  bool get isValid => hasLower && hasUpper && hasNumber && hasSpecial;

  void validate(String value) {
    hasLower = value.contains(RegExp(r'[a-z]'));
    hasUpper = value.contains(RegExp(r'[A-Z]'));
    hasNumber = value.contains(RegExp(r'[0-9]'));
    hasSpecial = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  }
}

class EmailValidator {
  static bool validate(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  static OutlineInputBorder getBorder(bool touched, bool valid) {
    if (!touched) {
      return const OutlineInputBorder();
    }

    return OutlineInputBorder(
      borderSide: BorderSide(
        color: valid ? Colors.green : Colors.red,
        width: 2,
      ),
    );
  }
}

String capitalizeWords(String text) {
  return text
      .split(" ")
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(" ");
}
