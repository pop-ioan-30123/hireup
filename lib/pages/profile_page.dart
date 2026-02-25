import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/texts.dart';
import '../services/api_service.dart';
import '../services/secure_storage.dart';
import '../widgets/authenticated_page_shell.dart';

class ProfilePage extends StatefulWidget {
  final String lang;
  final bool isDark;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final Future<void> Function() onLogout;

  const ProfilePage({
    super.key,
    required this.lang,
    required this.isDark,
    required this.onLangChange,
    required this.onThemeChange,
    required this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? profileData;
  Uint8List? avatarBytes;
  String? hoveredBadgeKey;
  late String currentLang;
  late bool currentIsDark;

  @override
  void initState() {
    super.initState();
    currentLang = widget.lang;
    currentIsDark = widget.isDark;
    _loadAvatarFromCache();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.lang != widget.lang && currentLang != widget.lang) {
      currentLang = widget.lang;
    }

    if (oldWidget.isDark != widget.isDark && currentIsDark != widget.isDark) {
      currentIsDark = widget.isDark;
    }
  }

  Future<void> _loadAvatarFromCache() async {
    final encoded = await SecureStorage.read('profile_avatar_base64_cache');
    if (!mounted || encoded == null || encoded.isEmpty) return;

    try {
      final bytes = base64Decode(encoded);
      if (!_isSupportedImage(bytes)) {
        await SecureStorage.delete('profile_avatar_base64_cache');
        return;
      }
      if (!mounted) return;
      setState(() {
        avatarBytes = bytes;
      });
    } catch (_) {
      await SecureStorage.delete('profile_avatar_base64_cache');
    }
  }

  bool _isSupportedImage(Uint8List bytes) {
    if (bytes.length < 12) return false;

    final isPng =
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    if (isPng) return true;

    final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
    if (isJpeg) return true;

    final isWebp =
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
    return isWebp;
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

      try {
        final avatar = await ApiService.fetchAvatar(accessToken: token);
        if (!mounted) return;
        if (avatar != null) {
          setState(() {
            avatarBytes = avatar;
          });
          await SecureStorage.write(
            'profile_avatar_base64_cache',
            base64Encode(avatar),
          );
        }
      } on ApiException catch (avatarError) {
        if (avatarError.code == 'HTTP_401' || avatarError.code == 'HTTP_403') {
          await _forceLogout();
        }
      } catch (_) {}
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

  bool _isVisible(String key) {
    final visibility = profileData?['visibility'] as Map<String, dynamic>?;
    return visibility?[key] == true;
  }

  int? _calculateAge(String? birthDateRaw) {
    final parsed = birthDateRaw == null ? null : DateTime.tryParse(birthDateRaw);
    if (parsed == null) return null;

    final today = DateTime.now();
    var age = today.year - parsed.year;
    final hasHadBirthdayThisYear =
        today.month > parsed.month ||
        (today.month == parsed.month && today.day >= parsed.day);

    if (!hasHadBirthdayThisYear) {
      age -= 1;
    }

    return age < 0 ? null : age;
  }

  String? _genderEmoji(String? gender) {
    if (gender == 'male') return '♂';
    if (gender == 'female') return '♀';
    return null;
  }

  List<String> _unlockedBadgeKeys() {
    final rawBadges = profileData?['badges'];
    if (rawBadges is! List) {
      return const [];
    }

    final badges = <String>[];
    for (final entry in rawBadges) {
      if (entry is! Map<String, dynamic>) continue;

      final key = entry['key']?.toString() ?? '';
      if (key == 'founder' || key == 'two_factor') {
        badges.add(key);
      }
    }

    return badges;
  }

  Map<String, String> _badgeInfo(String keyName) {
    if (keyName == 'founder') {
      return {
        'title': t(widget.lang, 'badgeFounderTitle'),
        'description': t(widget.lang, 'badgeFounderDescription'),
      };
    }

    return {
      'title': t(widget.lang, 'badgeTwoFactorTitle'),
      'description': t(widget.lang, 'badgeTwoFactorDescription'),
    };
  }

  IconData _badgeIcon(String keyName) {
    if (keyName == 'founder') {
      return Icons.rocket_launch_rounded;
    }

    return Icons.security_rounded;
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
            : _buildProfileContent(),
      ),
    );
  }

  Widget _buildProfileContent() {
    final accountType = profileData?['accountType'] as String? ?? 'user';
    final user = profileData?['user'] as Map<String, dynamic>? ?? {};
    final userProfile = profileData?['userProfile'] as Map<String, dynamic>?;
    final companyProfile =
        profileData?['companyProfile'] as Map<String, dynamic>?;
    final hasCv = profileData?['hasCv'] == true;
    final badges = _unlockedBadgeKeys();
    final isEmailVerified = user['isEmailVerified'] == true;

    final firstName = user['firstName']?.toString().trim() ?? '';
    final lastName = user['lastName']?.toString().trim() ?? '';
    final fullName = [firstName, lastName].where((v) => v.isNotEmpty).join(' ');
    final age = _isVisible('showBirthDate')
      ? _calculateAge(user['birthDate']?.toString())
      : null;
    final headline = age != null ? '$fullName, $age' : fullName;
    final genderEmoji = _isVisible('showGender')
      ? _genderEmoji(user['gender']?.toString())
      : null;

    final occupation = accountType == 'user'
      ? (_isVisible('showJobTitle')
          ? (userProfile?['jobTitle']?.toString() ?? '-')
          : '-')
      : (_isVisible('showCompanyName')
          ? (companyProfile?['companyName']?.toString() ?? '-')
          : '-');

    final details = <MapEntry<String, String>>[];
    if (_isVisible('showPhone')) {
      details.add(
        MapEntry(t(widget.lang, 'phone'), user['phone']?.toString() ?? '-'),
      );
    }
    if (_isVisible('showCountry')) {
      details.add(
        MapEntry(
          t(widget.lang, 'country'),
          userProfile?['country']?.toString() ?? '-',
        ),
      );
    }
    if (_isVisible('showCounty')) {
      details.add(
        MapEntry(
          t(widget.lang, 'county'),
          userProfile?['county']?.toString() ?? '-',
        ),
      );
    }
    if (_isVisible('showCity')) {
      details.add(
        MapEntry(
          t(widget.lang, 'city'),
          userProfile?['city']?.toString() ?? '-',
        ),
      );
    }
    if (_isVisible('showYearsExperience')) {
      details.add(
        MapEntry(
          t(widget.lang, 'yearsExperience'),
          userProfile?['yearsExperience']?.toString() ?? '-',
        ),
      );
    }
    if (_isVisible('showEducationLevel')) {
      details.add(
        MapEntry(
          t(widget.lang, 'educationLevel'),
          userProfile?['educationLevel']?.toString() ?? '-',
        ),
      );
    }
    if (_isVisible('showEducationInstitution')) {
      details.add(
        MapEntry(
          t(widget.lang, 'lastEducationInstitution'),
          userProfile?['educationInstitution']?.toString() ?? '-',
        ),
      );
    }
    if (_isVisible('showCv')) {
      details.add(
        MapEntry(
          t(widget.lang, 'cvAttachmentSection'),
          hasCv
              ? t(widget.lang, 'cvAvailable')
              : t(widget.lang, 'cvNotAvailable'),
        ),
      );
    }

    return ListView(
      children: [
        _futuristicSection(
          child: Row(
            children: [
              GestureDetector(
                onTap: avatarBytes == null ? null : _showAvatarPreview,
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundImage: avatarBytes != null
                      ? MemoryImage(avatarBytes!)
                      : null,
                  child: avatarBytes == null
                      ? Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                          size: 42,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Row(
                  children: [
                    if (genderEmoji != null) ...[
                      Text(
                        genderEmoji,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        headline.isEmpty ? '-' : headline,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isEmailVerified)
                      Icon(
                        Icons.verified_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _futuristicSection(
          child: Row(
            children: [
              Icon(
                Icons.badge_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  occupation,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _futuristicSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(widget.lang, 'achievements'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              badges.isEmpty
                  ? _profileBadgesEmptyState()
                  : Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: badges
                          .map((badgeKey) => _profileBadgeIcon(badgeKey))
                          .toList(growable: false),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _futuristicSection(
          child: details.isEmpty
              ? Text('-', style: TextStyle(color: Theme.of(context).hintColor))
              : Column(
                  children: details
                      .map((entry) => _infoRow(entry.key, entry.value))
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }

  Future<void> _showAvatarPreview() async {
    if (avatarBytes == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.memory(avatarBytes!, fit: BoxFit.contain),
          ),
        );
      },
    );
  }

  Widget _futuristicSection({required Widget child}) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: Container(
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
        ),
      ),
    );
  }

  Widget _profileBadgesEmptyState() {
    return Text(
      t(widget.lang, 'achievementUnlockedNone'),
      style: TextStyle(color: Theme.of(context).hintColor),
    );
  }

  Future<void> _showBadgeDetails(String keyName) async {
    final info = _badgeInfo(keyName);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(info['title'] ?? ''),
          content: Text(info['description'] ?? ''),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t(widget.lang, 'ok')),
            ),
          ],
        );
      },
    );
  }

  Widget _profileBadgeIcon(String keyName) {
    final scheme = Theme.of(context).colorScheme;
    final isHovered = hoveredBadgeKey == keyName;
    final icon = _badgeIcon(keyName);
    final info = _badgeInfo(keyName);

    return Tooltip(
      message: info['title'] ?? '',
      child: MouseRegion(
        onEnter: (_) {
          if (!mounted) return;
          setState(() => hoveredBadgeKey = keyName);
        },
        onExit: (_) {
          if (!mounted) return;
          setState(() => hoveredBadgeKey = null);
        },
        child: GestureDetector(
          onTap: () => _showBadgeDetails(keyName),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            scale: isHovered ? 1.08 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withValues(alpha: isHovered ? 0.36 : 0.28),
                    scheme.secondary.withValues(alpha: isHovered ? 0.3 : 0.22),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: isHovered ? 0.52 : 0.38),
                  width: isHovered ? 1.5 : 1.2,
                ),
              ),
              child: Icon(icon, color: scheme.primary, size: 28),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 5, child: Text(value)),
        ],
      ),
    );
  }
}
