import 'package:flutter/material.dart';

import '../widgets/authenticated_page_shell.dart';

class HomePage extends StatelessWidget {
  final String lang;
  final bool isDark;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final Future<void> Function() onLogout;

  const HomePage({
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
      isHomePage: true,
      child: const SizedBox.expand(),
    );
  }
}
