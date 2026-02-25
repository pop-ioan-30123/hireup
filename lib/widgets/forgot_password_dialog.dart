import 'package:flutter/material.dart';
import '../core/texts.dart';

Future<void> showForgotPasswordDialog({
  required BuildContext context,
  required bool isDark,
  required String lang,
  required TextEditingController emailCtrl,
  required ValueChanged<String> onEmailChanged,
  required OutlineInputBorder Function() emailBorder,
}) async {
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: isDark ? Colors.black : Colors.white,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t(lang, 'emailInfo')),
          const SizedBox(height: 12),
          TextField(
            controller: emailCtrl,
            onChanged: onEmailChanged,
            decoration: InputDecoration(
              labelText: t(lang, 'email'),
              border: emailBorder(),
              enabledBorder: emailBorder(),
              focusedBorder: emailBorder(),
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            child: Text(t(lang, 'send')),
          ),
        ],
      ),
    ),
  );
}
