import 'package:flutter/material.dart';

import '../core/texts.dart';
import '../services/api_service.dart';
import '../services/secure_storage.dart';
import '../widgets/authenticated_page_shell.dart';

class AchievementsPage extends StatefulWidget {
  final String lang;
  final bool isDark;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final Future<void> Function() onLogout;

  const AchievementsPage({
    super.key,
    required this.lang,
    required this.isDark,
    required this.onLangChange,
    required this.onThemeChange,
    required this.onLogout,
  });

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? profileData;
  late String currentLang;
  late bool currentIsDark;

  @override
  void initState() {
    super.initState();
    currentLang = widget.lang;
    currentIsDark = widget.isDark;
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant AchievementsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.lang != widget.lang && currentLang != widget.lang) {
      currentLang = widget.lang;
    }

    if (oldWidget.isDark != widget.isDark && currentIsDark != widget.isDark) {
      currentIsDark = widget.isDark;
    }
  }

  Future<void> _loadProfile() async {
    final token = await SecureStorage.read('access_token');
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      await _forceLogout();
      return;
    }

    try {
      final data = await ApiService.getProfile(accessToken: token);
      if (!mounted) return;
      setState(() {
        profileData = data;
        isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'HTTP_401' || error.code == 'HTTP_403') {
        await _forceLogout();
        return;
      }
      setState(() {
        errorMessage = error.message;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorMessage = t(widget.lang, 'loginGenericError');
        isLoading = false;
      });
    }
  }

  Future<void> _forceLogout() async {
    await widget.onLogout();
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route.isFirst);
  }

  List<Map<String, String>> _badgeCatalog() {
    final rawCatalog = profileData?['badgeCatalog'];
    if (rawCatalog is! List) {
      return [
        {
          'key': 'founder',
          'status': 'unavailable',
          'title': t(widget.lang, 'badgeFounderTitle'),
          'description': t(widget.lang, 'badgeFounderDescription'),
        },
        {
          'key': 'two_factor',
          'status': 'available',
          'title': t(widget.lang, 'badgeTwoFactorTitle'),
          'description': t(widget.lang, 'badgeTwoFactorDescription'),
        },
      ];
    }

    final catalog = <Map<String, String>>[];
    for (final entry in rawCatalog) {
      if (entry is! Map<String, dynamic>) continue;
      final key = entry['key']?.toString() ?? '';
      final status = entry['status']?.toString() ?? 'available';
      if (key != 'founder' && key != 'two_factor') continue;

      catalog.add({
        'key': key,
        'status': status,
        'title': key == 'founder'
            ? t(widget.lang, 'badgeFounderTitle')
            : t(widget.lang, 'badgeTwoFactorTitle'),
        'description': key == 'founder'
            ? t(widget.lang, 'badgeFounderDescription')
            : t(widget.lang, 'badgeTwoFactorDescription'),
      });
    }

    return catalog;
  }

  IconData _badgeIcon(String keyName) {
    if (keyName == 'founder') {
      return Icons.rocket_launch_rounded;
    }

    return Icons.security_rounded;
  }

  String _badgeStatusLabel(String status) {
    if (status == 'unlocked') {
      return t(widget.lang, 'achievementStatusUnlocked');
    }
    if (status == 'unavailable') {
      return t(widget.lang, 'achievementStatusUnavailable');
    }
    return t(widget.lang, 'achievementStatusAvailable');
  }

  @override
  Widget build(BuildContext context) {
    return AuthenticatedPageShell(
      lang: currentLang,
      isDark: currentIsDark,
      onLangChange: (lang) {
        setState(() {
          currentLang = lang;
        });
        widget.onLangChange(lang);
      },
      onThemeChange: (isDark) {
        setState(() {
          currentIsDark = isDark;
        });
        widget.onThemeChange(isDark);
      },
      onLogout: widget.onLogout,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(child: Text(errorMessage!))
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final catalog = _badgeCatalog();

    return ListView(
      children: [
        _futuristicSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(currentLang, 'achievements'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...catalog.map(
                (badge) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _achievementCard(
                    keyName: badge['key'] ?? '',
                    title: badge['title'] ?? '',
                    description: badge['description'] ?? '',
                    status: badge['status'] ?? 'available',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _futuristicSection({required Widget child}) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.12),
            scheme.secondary.withValues(alpha: 0.08),
            scheme.surface.withValues(alpha: 0.74),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.26),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.17),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _achievementCard({
    required String keyName,
    required String title,
    required String description,
    required String status,
  }) {
    final scheme = Theme.of(context).colorScheme;

    final isUnlocked = status == 'unlocked';
    final isUnavailable = status == 'unavailable';

    final gradientColors = isUnlocked
        ? [
            scheme.primary.withValues(alpha: 0.32),
            scheme.secondary.withValues(alpha: 0.26),
            scheme.surface.withValues(alpha: 0.7),
          ]
        : isUnavailable
        ? [
            scheme.onSurface.withValues(alpha: 0.14),
            scheme.onSurface.withValues(alpha: 0.1),
            scheme.surface.withValues(alpha: 0.72),
          ]
        : [
            scheme.primary.withValues(alpha: 0.18),
            scheme.secondary.withValues(alpha: 0.14),
            scheme.surface.withValues(alpha: 0.7),
          ];

    final borderColor = isUnlocked
        ? scheme.primary.withValues(alpha: 0.46)
        : isUnavailable
        ? scheme.onSurface.withValues(alpha: 0.2)
        : scheme.secondary.withValues(alpha: 0.34);

    return Opacity(
      opacity: isUnavailable ? 0.72 : 1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: isUnavailable ? 0.1 : 0.16),
                border: Border.all(
                  color: isUnavailable
                      ? scheme.onSurface.withValues(alpha: 0.24)
                      : scheme.primary.withValues(alpha: 0.34),
                ),
              ),
              child: Icon(_badgeIcon(keyName), color: scheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: isUnavailable ? 0.62 : 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _badgeStatusLabel(status),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isUnavailable
                    ? scheme.onSurface.withValues(alpha: 0.64)
                    : scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
