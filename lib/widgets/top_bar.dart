import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/texts.dart';
import '../core/responsive.dart';
import 'animated_title.dart';

class TopBarWidget extends StatefulWidget {
  final String lang;
  final bool isDark;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final Widget? trailingRight;
  final bool authenticatedLayout;
  final ValueChanged<Rect>? onMessagesTap;
  final ValueChanged<Rect>? onSocialTap;
  final ValueChanged<Rect>? onNotificationsTap;
  final void Function(String query, String scope)? onSearchAction;
  final int messagesBadgeCount;
  final int socialBadgeCount;
  final int notificationBadgeCount;

  const TopBarWidget({
    super.key,
    required this.lang,
    required this.isDark,
    required this.onLangChange,
    required this.onThemeChange,
    this.trailingRight,
    this.authenticatedLayout = false,
    this.onMessagesTap,
    this.onSocialTap,
    this.onNotificationsTap,
    this.onSearchAction,
    this.messagesBadgeCount = 0,
    this.socialBadgeCount = 0,
    this.notificationBadgeCount = 0,
  });

  @override
  State<TopBarWidget> createState() => _TopBarWidgetState();
}

class _TopBarWidgetState extends State<TopBarWidget> {
  final TextEditingController _authSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _authSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final isDark = widget.isDark;
    final onLangChange = widget.onLangChange;
    final onThemeChange = widget.onThemeChange;
    final trailingRight = widget.trailingRight;
    final authenticatedLayout = widget.authenticatedLayout;
    final onMessagesTap = widget.onMessagesTap;
    final onSocialTap = widget.onSocialTap;
    final onNotificationsTap = widget.onNotificationsTap;
    final onSearchAction = widget.onSearchAction;
    final messagesBadgeCount = widget.messagesBadgeCount;
    final socialBadgeCount = widget.socialBadgeCount;
    final notificationBadgeCount = widget.notificationBadgeCount;
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final availableLanguages = supportedLanguages();
    final scheme = Theme.of(context).colorScheme;

    if (authenticatedLayout) {
      final titleFont = isMobile
          ? 24.0
          : isTablet
          ? 28.0
          : 32.0;

      return LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 1060;
          final isVeryNarrow = constraints.maxWidth < 700;
          final searchWidth = isNarrow
              ? double.infinity
              : (isTablet ? 360.0 : 560.0);
          final hasQuery = _authSearchCtrl.text.trim().isNotEmpty;

          void runSearchWithScope(String scope) {
            final query = _authSearchCtrl.text.trim();
            if (query.isEmpty) return;
            onSearchAction?.call(query, scope);
          }

          Widget scopeSuggestionChip(String scope, String label) {
            return ActionChip(
              label: Text(label),
              avatar: const Icon(Icons.search_rounded, size: 16),
              onPressed: () => runSearchWithScope(scope),
            );
          }

          final searchField = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF191B33),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                alignment: Alignment.center,
                child: TextField(
                  controller: _authSearchCtrl,
                  cursorColor: Colors.white,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (value) {
                    final query = value.trim();
                    if (query.isEmpty) return;
                    onSearchAction?.call(query, 'profiles');
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: t(lang, 'searchCandidatesJobs'),
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: scheme.primary.withValues(alpha: 0.85),
                        width: 1.2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              if (hasQuery) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    scopeSuggestionChip('profiles', t(lang, 'searchInProfiles')),
                    scopeSuggestionChip('jobs', t(lang, 'searchInJobs')),
                    scopeSuggestionChip('activities', t(lang, 'searchInActivities')),
                  ],
                ),
              ],
            ],
          );

          final rightControls = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.end,
            children: [
              if (!isVeryNarrow)
                _topActionButton(
                  label: t(lang, 'messages'),
                  icon: Icons.chat_bubble_outline_rounded,
                  onTap: onMessagesTap,
                  compact: isNarrow,
                  badgeCount: messagesBadgeCount,
                ),
              _topActionButton(
                label: lang == 'ro' ? 'Social' : 'Social',
                icon: Icons.groups_rounded,
                onTap: onSocialTap,
                compact: isNarrow,
                badgeCount: socialBadgeCount,
              ),
              _topActionButton(
                label: t(lang, 'notifications'),
                icon: Icons.notifications_outlined,
                onTap: onNotificationsTap,
                compact: isNarrow,
                badgeCount: notificationBadgeCount,
              ),
              DropdownButton<String>(
                value: lang,
                dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                style: const TextStyle(color: Colors.white),
                iconEnabledColor: Colors.white,
                underline: const SizedBox.shrink(),
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
              ?trailingRight,
            ],
          );

          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile
                  ? 10
                  : isTablet
                  ? 16
                  : 22,
              vertical: isMobile ? 8 : 10,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primary.withValues(alpha: 0.95),
                  scheme.secondary.withValues(alpha: 0.75),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
            ),
            child: isNarrow
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _themeSegmentedToggle(isMobile: isMobile),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AnimatedTitle(
                              syncGroup: 'appNameTitle_$lang',
                              text: t(lang, 'appName'),
                              animatedStyle: GoogleFonts.shadowsIntoLight(
                                fontSize: isVeryNarrow ? 20 : 22,
                                letterSpacing: 0.2,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              finalStyle: GoogleFonts.shadowsIntoLight(
                                fontSize: isVeryNarrow ? 20 : 22,
                                letterSpacing: 0.2,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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
                          const SizedBox(width: 8),
                          Flexible(child: rightControls),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: searchField),
                    ],
                  )
                : Row(
                    children: [
                      _themeSegmentedToggle(isMobile: isMobile),
                      const SizedBox(width: 10),
                      SizedBox(width: searchWidth, child: searchField),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Center(
                          child: AnimatedTitle(
                            syncGroup: 'appNameTitle_$lang',
                            text: t(lang, 'appName'),
                            animatedStyle: GoogleFonts.shadowsIntoLight(
                              fontSize: titleFont,
                              letterSpacing: isMobile ? 0.2 : 0.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            finalStyle: GoogleFonts.shadowsIntoLight(
                              fontSize: titleFont,
                              letterSpacing: isMobile ? 0.2 : 0.5,
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
                                  offset: Offset(1, 0),
                                ),
                                Shadow(
                                  blurRadius: 20,
                                  color: Colors.white.withValues(alpha: 0.55),
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
                      ),
                      rightControls,
                    ],
                  ),
          );
        },
      );
    }

    return Container(
      height: isMobile
          ? 70
          : isTablet
          ? 85
          : 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.95),
            scheme.secondary.withValues(alpha: 0.75),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
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
                if (trailingRight case final rightWidget?) ...[
                  const SizedBox(width: 8),
                  rightWidget,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topActionButton({
    required String label,
    required IconData icon,
    required ValueChanged<Rect>? onTap,
    bool compact = false,
    int badgeCount = 0,
  }) {
    final displayBadge = badgeCount > 0;
    final badgeText = badgeCount > 99 ? '99+' : '$badgeCount';

    final iconWidget = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: compact ? 18 : 17),
        if (displayBadge)
          Positioned(
            right: -8,
            top: -9,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.all(Radius.circular(11)),
              ),
              child: Text(
                badgeText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );

    return Builder(
      builder: (buttonContext) => OutlinedButton.icon(
        onPressed: onTap == null
            ? null
            : () {
                final renderObject = buttonContext.findRenderObject();
                if (renderObject is! RenderBox) {
                  return;
                }
                final topLeft = renderObject.localToGlobal(Offset.zero);
                final rect = topLeft & renderObject.size;
                onTap(rect);
              },
        icon: iconWidget,
        label: compact ? const SizedBox.shrink() : Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 10,
          ),
          minimumSize: compact ? const Size(42, 40) : null,
        ),
      ),
    );
  }

  Widget _themeSegmentedToggle({required bool isMobile}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment<bool>(value: false, icon: Icon(Icons.wb_sunny_rounded)),
          ButtonSegment<bool>(value: true, icon: Icon(Icons.dark_mode_rounded)),
        ],
        selected: {widget.isDark},
        showSelectedIcon: false,
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(
            Size(isMobile ? 38 : 42, isMobile ? 36 : 38),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 8),
          ),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.white.withValues(alpha: 0.72);
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.transparent;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        onSelectionChanged: (selection) {
          final value = selection.first;
          widget.onThemeChange(value);
        },
      ),
    );
  }
}
