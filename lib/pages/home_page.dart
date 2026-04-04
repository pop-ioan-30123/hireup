import 'package:flutter/material.dart';

import '../core/texts.dart';
import '../widgets/authenticated_page_shell.dart';
import 'services/services_page.dart';
import 'home/widgets/home_action_tile.dart';
import 'jobs_page.dart';

class HomePage extends StatefulWidget {
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
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _borderRotationCtrl;
  String? _hoveredTileId;
  late String _lang;
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _lang = widget.lang;
    _isDark = widget.isDark;
    _borderRotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _borderRotationCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lang != widget.lang) _lang = widget.lang;
    if (oldWidget.isDark != widget.isDark) _isDark = widget.isDark;
  }

  @override
  Widget build(BuildContext context) {
    final tileForeground = _isDark ? Colors.black : Colors.white;
    final meteorColor = _isDark ? Colors.white : Colors.black;

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
      isHomePage: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 760;

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _homeTile(
                      context,
                      tileId: 'activities',
                      title: t(_lang, 'homeTileActivities'),
                      subtitle: t(_lang, 'homeTileActivitiesSubtitle'),
                      icon: Icons.design_services_rounded,
                      foregroundColor: tileForeground,
                      meteorColor: meteorColor,
                      onTap: () => _openActivities(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _homeTile(
                      context,
                      tileId: 'jobs',
                      title: t(_lang, 'homeTileJobs'),
                      subtitle: t(_lang, 'homeTileJobsSubtitle'),
                      icon: Icons.work_outline_rounded,
                      foregroundColor: tileForeground,
                      meteorColor: meteorColor,
                      onTap: () => _openJobs(context),
                    ),
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _homeTile(
                    context,
                    tileId: 'activities',
                    title: t(_lang, 'homeTileActivities'),
                    subtitle: t(_lang, 'homeTileActivitiesSubtitle'),
                    icon: Icons.design_services_rounded,
                    foregroundColor: tileForeground,
                    meteorColor: meteorColor,
                    onTap: () => _openActivities(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _homeTile(
                    context,
                    tileId: 'jobs',
                    title: t(_lang, 'homeTileJobs'),
                    subtitle: t(_lang, 'homeTileJobsSubtitle'),
                    icon: Icons.work_outline_rounded,
                    foregroundColor: tileForeground,
                    meteorColor: meteorColor,
                    onTap: () => _openJobs(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openActivities(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServicesPage(
          lang: _lang,
          isDark: _isDark,
          onLangChange: widget.onLangChange,
          onThemeChange: widget.onThemeChange,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  Future<void> _openJobs(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JobsPage(
          lang: _lang,
          isDark: _isDark,
          onLangChange: widget.onLangChange,
          onThemeChange: widget.onThemeChange,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  Widget _homeTile(
    BuildContext context, {
    required String tileId,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required Color foregroundColor,
    required Color meteorColor,
  }) {
    final hovered = _hoveredTileId == tileId;
    return HomeActionTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      onTap: onTap,
      hovered: hovered,
      onHoverEnter: () => setState(() => _hoveredTileId = tileId),
      onHoverExit: () => setState(() => _hoveredTileId = null),
      foregroundColor: foregroundColor,
      meteorColor: meteorColor,
      rotationAnimation: _borderRotationCtrl,
    );
  }
}
