import 'package:flutter/material.dart';

import '../core/texts.dart';
import '../widgets/authenticated_page_shell.dart';

class JobsPage extends StatelessWidget {
  final String lang;
  final bool isDark;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final Future<void> Function() onLogout;

  const JobsPage({
    super.key,
    required this.lang,
    required this.isDark,
    required this.onLangChange,
    required this.onThemeChange,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AuthenticatedPageShell(
      lang: lang,
      isDark: isDark,
      onLangChange: onLangChange,
      onThemeChange: onThemeChange,
      onLogout: onLogout,
      child: Center(
        child: Text(
          t(lang, 'homeJobsPlaceholder'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
