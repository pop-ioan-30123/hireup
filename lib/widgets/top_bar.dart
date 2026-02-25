import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/texts.dart';
import '../core/responsive.dart';
import 'animated_title.dart';

class TopBarWidget extends StatelessWidget {
  final String lang;
  final bool isDark;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final Widget? trailingRight;

  const TopBarWidget({
    super.key,
    required this.lang,
    required this.isDark,
    required this.onLangChange,
    required this.onThemeChange,
    this.trailingRight,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final availableLanguages = supportedLanguages();

    return Container(
      height: isMobile
          ? 70
          : isTablet
          ? 85
          : 100,
      decoration: const BoxDecoration(color: Colors.purple),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile
            ? 12
            : isTablet
            ? 16
            : 20,
        vertical: isMobile ? 8 : 12,
      ),
      child: Stack(
        children: [
          // Logo - centered and responsive
          Align(
            alignment: Alignment.center,
            child: AnimatedTitle(
              syncGroup: 'appNameTitle_$lang',
              text: t(lang, 'appName'),
              animatedStyle: GoogleFonts.shadowsIntoLight(
                fontSize: isMobile
                    ? 22
                    : isTablet
                    ? 27
                    : 33,
                letterSpacing: isMobile
                    ? 0.2
                    : isTablet
                    ? 0.5
                    : 0.7,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              finalStyle: GoogleFonts.shadowsIntoLight(
                fontSize: isMobile
                    ? 22
                    : isTablet
                    ? 27
                    : 33,
                letterSpacing: isMobile
                    ? 0.2
                    : isTablet
                    ? 0.5
                    : 0.7,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: [
                  const Shadow(
                    blurRadius: 0,
                    color: Colors.black,
                    offset: Offset(0, 0),
                  ),
                  const Shadow(
                    blurRadius: 2,
                    color: Colors.black,
                    offset: Offset(2, 0),
                  ),
                  const Shadow(
                    blurRadius: 2,
                    color: Colors.black,
                    offset: Offset(-2, 0),
                  ),
                  const Shadow(
                    blurRadius: 2,
                    color: Colors.black,
                    offset: Offset(0, 2),
                  ),
                  Shadow(
                    blurRadius: 18,
                    color: Colors.white.withValues(alpha: 0.8),
                    offset: const Offset(0, 0),
                  ),
                  Shadow(
                    blurRadius: 32,
                    color: Colors.white.withValues(alpha: 0.6),
                    offset: const Offset(0, 0),
                  ),
                  Shadow(
                    blurRadius: 32,
                    color: Colors.white.withValues(alpha: 0.6),
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              colors: const [
                Colors.purpleAccent,
                Colors.deepPurple,
                Colors.blueAccent,
                Colors.pinkAccent,
              ],
              typingSpeed: const Duration(milliseconds: 160),
              colorPause: const Duration(milliseconds: 1200),
              fadeDuration: const Duration(milliseconds: 1600),
            ),
          ),
          // Theme toggle - left aligned
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: !isDark ? Colors.white : Colors.grey,
                  ),
                  onPressed: () => onThemeChange(false),
                  icon: Icon(
                    Icons.wb_sunny,
                    color: Colors.black,
                    size: isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 10),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.black : Colors.grey,
                  ),
                  onPressed: () => onThemeChange(true),
                  icon: Icon(
                    Icons.nightlight,
                    color: Colors.white,
                    size: isMobile ? 20 : 24,
                  ),
                ),
              ],
            ),
          ),
          // Language and profile - right aligned
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: lang,
                  dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                  style: const TextStyle(color: Colors.white),
                  iconEnabledColor: Colors.white,
                  items: availableLanguages
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => onLangChange(v!),
                ),
                if (trailingRight != null) ...[
                  const SizedBox(width: 8),
                  trailingRight!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
