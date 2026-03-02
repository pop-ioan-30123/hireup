import 'package:flutter/material.dart';

import '../core/texts.dart';
import '../widgets/authenticated_page_shell.dart';
import 'activities_page.dart';
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

  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tileForeground = widget.isDark ? Colors.black : Colors.white;
    final meteorColor = widget.isDark ? Colors.white : Colors.black;

    return AuthenticatedPageShell(
      lang: widget.lang,
      isDark: widget.isDark,
      onLangChange: widget.onLangChange,
      onThemeChange: widget.onThemeChange,
      onLogout: widget.onLogout,
      isHomePage: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 760;
            final tiles = isMobile
                ? Column(
                    children: [
                      _homeTile(
                        context,
                        tileId: 'activities',
                        title: t(widget.lang, 'homeTileActivities'),
                        subtitle: t(widget.lang, 'homeTileActivitiesSubtitle'),
                        icon: Icons.dynamic_feed_rounded,
                        foregroundColor: tileForeground,
                        meteorColor: meteorColor,
                        onTap: () => _openActivities(context),
                      ),
                      const SizedBox(height: 14),
                      _homeTile(
                        context,
                        tileId: 'jobs',
                        title: t(widget.lang, 'homeTileJobs'),
                        subtitle: t(widget.lang, 'homeTileJobsSubtitle'),
                        icon: Icons.work_outline_rounded,
                        foregroundColor: tileForeground,
                        meteorColor: meteorColor,
                        onTap: () => _openJobs(context),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _homeTile(
                          context,
                          tileId: 'activities',
                          title: t(widget.lang, 'homeTileActivities'),
                          subtitle: t(widget.lang, 'homeTileActivitiesSubtitle'),
                          icon: Icons.dynamic_feed_rounded,
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
                          title: t(widget.lang, 'homeTileJobs'),
                          subtitle: t(widget.lang, 'homeTileJobsSubtitle'),
                          icon: Icons.work_outline_rounded,
                          foregroundColor: tileForeground,
                          meteorColor: meteorColor,
                          onTap: () => _openJobs(context),
                        ),
                      ),
                    ],
                  );

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: tiles,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: scheme.surface,
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t(widget.lang, 'homeCommunityTitle'),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._communityItems(widget.lang).map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _communityCard(
                                  context,
                                  author: item.author,
                                  ageLabel: item.ageLabel,
                                  content: item.content,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openActivities(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivitiesPage(
          lang: widget.lang,
          isDark: widget.isDark,
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
          lang: widget.lang,
          isDark: widget.isDark,
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

  Widget _communityCard(
    BuildContext context, {
    required String author,
    required String ageLabel,
    required String content,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.36),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: scheme.primary.withValues(alpha: 0.13),
                child: Icon(Icons.person, size: 16, color: scheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$author · $ageLabel',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  List<_CommunityItem> _communityItems(String lang) => [
        _CommunityItem(
          author: 'Alex P.',
          ageLabel: lang == 'RO' ? '2 ore' : '2 hours',
          content: t(lang, 'homeCommunityPost1'),
        ),
        _CommunityItem(
          author: 'Creative Solutions',
          ageLabel: lang == 'RO' ? '1 zi' : '1 day',
          content: t(lang, 'homeCommunityPost2'),
        ),
        _CommunityItem(
          author: 'Andreea M.',
          ageLabel: lang == 'RO' ? '3 zile' : '3 days',
          content: t(lang, 'homeCommunityPost3'),
        ),
      ];
}

class _CommunityItem {
  final String author;
  final String ageLabel;
  final String content;

  const _CommunityItem({
    required this.author,
    required this.ageLabel,
    required this.content,
  });
}
