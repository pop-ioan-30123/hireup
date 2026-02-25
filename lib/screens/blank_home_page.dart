import 'package:flutter/material.dart';
import '../pages/home_page.dart';

class BlankHomePage extends StatefulWidget {
  final String lang;
  final bool isDark;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final Future<void> Function() onLogout;

  const BlankHomePage({
    super.key,
    required this.lang,
    required this.isDark,
    required this.onLangChange,
    required this.onThemeChange,
    required this.onLogout,
  });

  @override
  State<BlankHomePage> createState() => _BlankHomePageState();
}

class _BlankHomePageState extends State<BlankHomePage> {
  @override
  Widget build(BuildContext context) {
    return HomePage(
      lang: widget.lang,
      isDark: widget.isDark,
      onLangChange: widget.onLangChange,
      onThemeChange: widget.onThemeChange,
      onLogout: widget.onLogout,
    );
  }
}