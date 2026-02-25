import 'package:flutter/material.dart';
import '../core/texts.dart';

Future<bool> showGdprDialog({
  required BuildContext context,
  required String lang,
  required bool isDark,
}) async {
  bool gdprChecked = false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(t(lang, "gdprTitle")),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(lang, "gdprDescription"),
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  // In a real app, open the GDPR document link here
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t(lang, "gdprLinkPlaceholder"))),
                  );
                },
                child: Text(
                  t(lang, "gdprLink"),
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Checkbox(
                    value: gdprChecked,
                    onChanged: (value) {
                      setState(() => gdprChecked = value ?? false);
                    },
                  ),
                  Expanded(
                    child: Text(
                      t(lang, "gdprConsent"),
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(lang, "cancel")),
          ),
          ElevatedButton(
            onPressed: gdprChecked ? () => Navigator.pop(context, true) : null,
            child: Text(t(lang, "accept")),
          ),
        ],
      ),
    ),
  );

  return result ?? false;
}
