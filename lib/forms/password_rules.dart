import 'package:flutter/material.dart';
import '../core/texts.dart';

class PasswordRulesWidget extends StatelessWidget {
  final bool isDark;
  final bool hasLower;
  final bool hasUpper;
  final bool hasNumber;
  final bool hasSpecial;
  final String lang;

  const PasswordRulesWidget({
    super.key,
    required this.isDark,
    required this.hasLower,
    required this.hasUpper,
    required this.hasNumber,
    required this.hasSpecial,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;

    Widget row(bool ok, String text) => Row(
      children: [
        Icon(
          ok ? Icons.check : Icons.close,
          color: ok ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: ok ? Colors.green : textColor,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(hasLower, t(lang, "lower")),
        row(hasUpper, t(lang, "upper")),
        row(hasNumber, t(lang, "number")),
        row(hasSpecial, t(lang, "special")),
      ],
    );
  }
}
