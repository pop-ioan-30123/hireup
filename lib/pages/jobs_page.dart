import 'package:flutter/material.dart';

import '../core/texts.dart';
import '../widgets/authenticated_page_shell.dart';

class JobsPage extends StatefulWidget {
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
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  late String _lang;
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _lang = widget.lang;
    _isDark = widget.isDark;
  }

  @override
  void didUpdateWidget(covariant JobsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lang != widget.lang) _lang = widget.lang;
    if (oldWidget.isDark != widget.isDark) _isDark = widget.isDark;
  }

  @override
  Widget build(BuildContext context) {
    return AuthenticatedPageShell(
      lang: _lang,
      isDark: _isDark,
      onLangChange: (lang) {
        setState(() => _lang = lang);
        widget.onLangChange(lang);
      },
      onThemeChange: (isDark) {
        setState(() => _isDark = isDark);
        widget.onThemeChange(isDark);
      },
      onLogout: widget.onLogout,
      child: Center(
        child: Text(
          t(_lang, 'homeJobsPlaceholder'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
