import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final Map<String, dynamic>? initialProfileData;
  final Uint8List? initialAvatarBytes;
  final bool useEmbeddedLayout;

  const ProfilePage({
    super.key,
    required this.lang,
    required this.isDark,
    required this.onLangChange,
    required this.onThemeChange,
    required this.onLogout,
    this.initialProfileData,
    this.initialAvatarBytes,
    this.useEmbeddedLayout = false,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isLoading = true;
  String? errorMessage;
  String? accessToken;
  Map<String, dynamic>? profileData;
  Uint8List? avatarBytes;
  String? hoveredBadgeKey;
  final TextEditingController _postComposerCtrl = TextEditingController();
  final List<Map<String, dynamic>> _pendingPostAttachments = [];
  final Map<String, TextEditingController> _commentControllers = {};
  final Set<String> _postingCommentForPostIds = <String>{};
  bool _isPostingActivity = false;
  String? _selectedSticker;
  String? _editingPostId;
  late String currentLang;
  late bool currentIsDark;
  final ScrollController _profileScrollController = ScrollController();
  final GlobalKey _experienceSectionKey = GlobalKey();
  final GlobalKey _skillsSectionKey = GlobalKey();
  final GlobalKey _educationSectionKey = GlobalKey();
  final GlobalKey _projectsSectionKey = GlobalKey();
  Map<String, dynamic>? _socialSummary;
  List<Map<String, dynamic>> _followers = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _contacts = const <Map<String, dynamic>>[];
  bool _followersListVisible = true;
  bool _contactsListVisible = true;
  bool _socialSummaryLoading = false;
  bool _socialListsLoading = false;
  bool _socialActionBusy = false;
  String? _authUserId;
  final Map<String, Uint8List?> _socialAvatarByUserId = <String, Uint8List?>{};
  final Set<String> _socialAvatarLoadingUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    currentLang = widget.lang;
    currentIsDark = widget.isDark;

    if (widget.initialProfileData != null) {
      profileData = widget.initialProfileData;
      avatarBytes = widget.initialAvatarBytes;
      isLoading = false;
      unawaited(_loadAccessTokenAndSocialSummary());
      return;
    }

    _loadAvatarFromCache();
    _loadProfile();
  }

  @override
  void dispose() {
    _postComposerCtrl.dispose();
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    _profileScrollController.dispose();
    super.dispose();
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

  bool get _isRomanianLanguage => currentLang.toLowerCase().startsWith('ro');

  String _localized(String ro, String en) => _isRomanianLanguage ? ro : en;

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
        accessToken = token;
        _authUserId = _extractUserIdFromToken(token);
        profileData = data;
        isLoading = false;
      });
      unawaited(_loadSocialSummary());

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

  String? get _displayedUserId {
    final user = profileData?['user'] as Map<String, dynamic>?;
    final id = user?['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  Future<void> _loadAccessTokenAndSocialSummary() async {
    final token = await SecureStorage.read('access_token');
    if (!mounted) return;
    setState(() {
      accessToken = token;
      _authUserId = _extractUserIdFromToken(token);
    });
    await _loadDisplayedUserAvatar(token);
    await _loadSocialSummary();
  }

  Future<void> _loadDisplayedUserAvatar(String? token) async {
    if (token == null || token.isEmpty) return;
    final displayedUserId = _displayedUserId;
    if (displayedUserId == null || displayedUserId.isEmpty) return;

    try {
      Uint8List? bytes;
      if (displayedUserId == _authUserId) {
        bytes = await ApiService.fetchAvatar(accessToken: token);
        if (bytes != null) {
          await SecureStorage.write(
            'profile_avatar_base64_cache',
            base64Encode(bytes),
          );
        }
      } else {
        bytes = await ApiService.fetchUserAvatar(
          accessToken: token,
          userId: displayedUserId,
        );
      }

      if (!mounted) return;
      setState(() {
        avatarBytes = bytes;
      });
    } catch (_) {
      return;
    }
  }

  String? _extractUserIdFromToken(String? token) {
    if (token == null || token.trim().isEmpty) return null;

    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payloadText = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadText);
      if (payload is! Map<String, dynamic>) return null;
      final userId = payload['sub']?.toString().trim();
      if (userId == null || userId.isEmpty) return null;
      return userId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadSocialSummary() async {
    final token = accessToken ?? await SecureStorage.read('access_token');
    final userId = _displayedUserId;
    if (token == null || token.isEmpty || userId == null) {
      return;
    }

    if (mounted) {
      setState(() => _socialSummaryLoading = true);
    }

    try {
      final summary = await ApiService.getSocialSummary(
        accessToken: token,
        userId: userId,
      );
      if (!mounted) return;
      setState(() {
        accessToken = token;
        _socialSummary = summary;
      });
      await _loadSocialLists(
        token,
        userId,
        summary,
        isOwnProfile: _authUserId != null && _authUserId == userId,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _socialSummary = null;
        _followers = const <Map<String, dynamic>>[];
        _contacts = const <Map<String, dynamic>>[];
        _followersListVisible = true;
        _contactsListVisible = true;
      });
    } finally {
      if (mounted) {
        setState(() => _socialSummaryLoading = false);
      }
    }
  }

  Future<void> _loadSocialLists(
    String token,
    String userId,
    Map<String, dynamic> summary,
    {required bool isOwnProfile}
  ) async {
    final shouldShowFollowers =
        isOwnProfile || summary['showFollowerList'] != false;
    final shouldShowContacts =
        isOwnProfile || summary['showContactList'] != false;

    if (mounted) {
      setState(() => _socialListsLoading = true);
    }

    try {
      Future<Map<String, dynamic>> safeListRequest(
        bool shouldRequest,
        Future<Map<String, dynamic>> Function() request,
      ) async {
        if (!shouldRequest) {
          return const <String, dynamic>{
            'items': <dynamic>[],
            'isVisible': false,
          };
        }
        try {
          return await request();
        } catch (_) {
          return const <String, dynamic>{
            'items': <dynamic>[],
            'isVisible': true,
          };
        }
      }

      final followersResult = await safeListRequest(
        shouldShowFollowers,
        () => ApiService.listFollowers(accessToken: token, userId: userId),
      );
      final contactsResult = await safeListRequest(
        shouldShowContacts,
        () => ApiService.listContacts(accessToken: token, userId: userId),
      );

      if (!mounted) return;
      setState(() {
        _followers =
            (followersResult['items'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .toList(growable: false);
        _contacts =
            (contactsResult['items'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .toList(growable: false);
        _followersListVisible =
            shouldShowFollowers && followersResult['isVisible'] != false;
        _contactsListVisible =
            shouldShowContacts && contactsResult['isVisible'] != false;
      });
      unawaited(_preloadSocialAvatars(token));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _followers = const <Map<String, dynamic>>[];
        _contacts = const <Map<String, dynamic>>[];
        _followersListVisible = true;
        _contactsListVisible = true;
      });
    } finally {
      if (mounted) {
        setState(() => _socialListsLoading = false);
      }
    }
  }

  Future<void> _preloadSocialAvatars(String token) async {
    final userIds = <String>{};
    for (final person in _followers) {
      final id = person['userId']?.toString().trim() ?? '';
      if (id.isNotEmpty) userIds.add(id);
    }
    for (final person in _contacts) {
      final id = person['userId']?.toString().trim() ?? '';
      if (id.isNotEmpty) userIds.add(id);
    }

    for (final userId in userIds) {
      if (_socialAvatarByUserId.containsKey(userId) ||
          _socialAvatarLoadingUserIds.contains(userId)) {
        continue;
      }

      _socialAvatarLoadingUserIds.add(userId);
      try {
        final bytes = await ApiService.fetchUserAvatar(
          accessToken: token,
          userId: userId,
        );
        if (!mounted) return;
        setState(() {
          _socialAvatarByUserId[userId] = bytes;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _socialAvatarByUserId[userId] = null;
        });
      } finally {
        _socialAvatarLoadingUserIds.remove(userId);
      }
    }
  }

  String _personInitials(Map<String, dynamic> person) {
    final fullName = person['fullName']?.toString().trim() ?? '';
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (parts.isNotEmpty) {
      final first = parts.first.characters.first;
      final last = parts.length > 1 ? parts.last.characters.first : '';
      return '$first$last'.toUpperCase();
    }

    final email = person['email']?.toString().trim() ?? '';
    if (email.isNotEmpty) return email.characters.first.toUpperCase();
    return '?';
  }

  Widget _socialPersonAvatar(Map<String, dynamic> person, IconData fallbackIcon) {
    final scheme = Theme.of(context).colorScheme;
    final userId = person['userId']?.toString().trim() ?? '';
    final bytes = userId.isEmpty ? null : _socialAvatarByUserId[userId];

    return CircleAvatar(
      radius: 16,
      backgroundColor: scheme.primary.withValues(alpha: 0.16),
      foregroundImage: bytes != null ? MemoryImage(bytes) : null,
      child: bytes == null
          ? Text(
              _personInitials(person),
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            )
          : null,
    );
  }

  Future<void> _openSocialPersonProfile(Map<String, dynamic> person) async {
    final token = accessToken ?? await SecureStorage.read('access_token');
    final userId = person['userId']?.toString().trim() ?? '';
    if (token == null || token.isEmpty || userId.isEmpty) return;

    try {
      final data = await ApiService.getProfileByUserId(
        accessToken: token,
        userId: userId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProfilePage(
            lang: currentLang,
            isDark: currentIsDark,
            onLangChange: widget.onLangChange,
            onThemeChange: widget.onThemeChange,
            onLogout: widget.onLogout,
            initialProfileData: data,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  bool _isVisible(String key) {
    final visibility = profileData?['visibility'] as Map<String, dynamic>?;
    return visibility?[key] == true;
  }

  Uri? _normalizedUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.tryParse(trimmed);
    }
    return Uri.tryParse('https://$trimmed');
  }

  Future<bool> _confirmExternalNavigation(Uri uri) async {
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(widget.lang, 'externalLinkDialogTitle')),
        content: Text(
          '${t(widget.lang, 'externalLinkDialogDescription')}\n\n${uri.toString()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t(widget.lang, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t(widget.lang, 'continueAction')),
          ),
        ],
      ),
    );

    return decision == true;
  }

  Future<void> _openSocialLink(String rawUrl) async {
    final uri = _normalizedUrl(rawUrl);
    if (uri == null) return;

    final canOpen = await _confirmExternalNavigation(uri);
    if (!canOpen) return;

    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t(widget.lang, 'comingSoon'))));
    }
  }

  Future<void> _jumpToSection(GlobalKey sectionKey) async {
    final targetContext = sectionKey.currentContext;
    if (targetContext == null) return;

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  Widget _buildJumpTabs(List<({GlobalKey key, String label})> sections) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        height: 86,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primary.withValues(alpha: 0.14),
              scheme.secondary.withValues(alpha: 0.1),
              scheme.surface.withValues(alpha: 0.96),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border(
            bottom: BorderSide(color: scheme.primary.withValues(alpha: 0.22)),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: sections
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton.tonal(
                      onPressed: () => _jumpToSection(entry.key),
                      child: Text(entry.label),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
  }

  int? _calculateAge(String? birthDateRaw) {
    final parsed = birthDateRaw == null
        ? null
        : DateTime.tryParse(birthDateRaw);
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

  bool _isUniversityEducationLevel(String? level) {
    if (level == null) return false;
    return level == t(widget.lang, 'educationBachelor') ||
        level == t(widget.lang, 'educationMaster') ||
        level == t(widget.lang, 'educationDoctorate');
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

  String _professionalStatusLabel(String? value) {
    if (value == 'hired') {
      return t(widget.lang, 'professionalStatusHired');
    }
    if (value == 'not_available') {
      return t(widget.lang, 'professionalStatusNotAvailable');
    }
    return t(widget.lang, 'professionalStatusOpenToWork');
  }

  ({Color background, Color foreground}) _professionalStatusColors(
    String? value,
  ) {
    if (value == 'hired') {
      return (background: const Color(0xFFD32F2F), foreground: Colors.white);
    }
    if (value == 'not_available') {
      return (background: Colors.black, foreground: Colors.white);
    }
    return (background: const Color(0xFF2E7D32), foreground: Colors.white);
  }

  bool get _isPreviewMode => widget.initialProfileData != null;

  bool get _canCreateActivityPosts {
    if (_isPreviewMode) return false;
    return profileData?['canPostActivity'] != false;
  }

  bool get _canCommentOnActivity {
    if (_isPreviewMode) return false;
    return profileData?['canCommentActivity'] != false;
  }

  TextEditingController _commentControllerFor(String postId) {
    return _commentControllers.putIfAbsent(postId, TextEditingController.new);
  }

  String _monthYearLabel(int month, int year) {
    final monthNumber = month.toString().padLeft(2, '0');
    final monthName = t(widget.lang, 'monthName$monthNumber');
    return '$monthNumber - $monthName / $year';
  }

  String _experiencePeriod(Map<String, dynamic> experience) {
    final startMonth = (experience['startMonth'] as num?)?.toInt() ?? 1;
    final startYear = (experience['startYear'] as num?)?.toInt() ?? DateTime.now().year;
    final isCurrent = experience['isCurrent'] == true;
    final start = _monthYearLabel(startMonth, startYear);

    if (isCurrent) {
      return '$start - ${t(widget.lang, 'present')}';
    }

    final endMonth = (experience['endMonth'] as num?)?.toInt();
    final endYear = (experience['endYear'] as num?)?.toInt();
    if (endMonth == null || endYear == null) {
      return start;
    }

    return '$start - ${_monthYearLabel(endMonth, endYear)}';
  }

  String _educationPeriod(Map<String, dynamic> education) {
    final startMonth = (education['startMonth'] as num?)?.toInt() ?? 1;
    final startYear = (education['startYear'] as num?)?.toInt() ?? DateTime.now().year;
    final isCurrent = education['isCurrent'] == true;
    final start = _monthYearLabel(startMonth, startYear);

    if (isCurrent) {
      return '$start - ${t(widget.lang, 'present')}';
    }

    final endMonth = (education['endMonth'] as num?)?.toInt();
    final endYear = (education['endYear'] as num?)?.toInt();
    if (endMonth == null || endYear == null) {
      return start;
    }

    return '$start - ${_monthYearLabel(endMonth, endYear)}';
  }

  String _projectPeriod(Map<String, dynamic> project) {
    final startMonth = (project['startMonth'] as num?)?.toInt() ?? 1;
    final startYear = (project['startYear'] as num?)?.toInt() ?? DateTime.now().year;
    final isCurrent = project['isCurrent'] == true;
    final start = _monthYearLabel(startMonth, startYear);

    if (isCurrent) {
      return '$start - ${t(widget.lang, 'present')}';
    }

    final endMonth = (project['endMonth'] as num?)?.toInt();
    final endYear = (project['endYear'] as num?)?.toInt();
    if (endMonth == null || endYear == null) {
      return start;
    }

    return '$start - ${_monthYearLabel(endMonth, endYear)}';
  }

  String _guessMimeType(String fileName) {
    final normalized = fileName.toLowerCase();
    if (normalized.endsWith('.png')) return 'image/png';
    if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (normalized.endsWith('.webp')) return 'image/webp';
    if (normalized.endsWith('.gif')) return 'image/gif';
    if (normalized.endsWith('.pdf')) return 'application/pdf';
    if (normalized.endsWith('.doc')) return 'application/msword';
    if (normalized.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (normalized.endsWith('.txt')) return 'text/plain';
    if (normalized.endsWith('.zip')) return 'application/zip';
    return 'application/octet-stream';
  }

  Future<String?> _pickSymbolFromCategories({
    required String title,
    required List<({String id, String label, List<String> symbols})> categories,
    double symbolFontSize = 24,
    bool showBorder = false,
  }) async {
    if (categories.isEmpty) return null;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var selectedCategoryIndex = 0;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final activeCategory = categories[selectedCategoryIndex];

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List<Widget>.generate(categories.length, (
                          index,
                        ) {
                          final category = categories[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              selected: selectedCategoryIndex == index,
                              onSelected: (_) {
                                setDialogState(() => selectedCategoryIndex = index);
                              },
                              label: Text(category.label),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: GridView.builder(
                        shrinkWrap: true,
                        itemCount: activeCategory.symbols.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                              childAspectRatio: 1,
                            ),
                        itemBuilder: (context, index) {
                          final symbol = activeCategory.symbols[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => Navigator.of(dialogContext).pop(symbol),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: showBorder
                                  ? BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary.withValues(alpha: 0.22),
                                      ),
                                    )
                                  : null,
                              child: Text(
                                symbol,
                                style: TextStyle(fontSize: symbolFontSize),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(t(widget.lang, 'cancel')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickPostEmoji() async {
    if (!_canCreateActivityPosts) return;

    final categories = <({String id, String label, List<String> symbols})>[
      (
        id: 'smileys',
        label: t(widget.lang, 'emojiCategorySmileys'),
        symbols: const [
          '😀', '😁', '😂', '🤣', '😊', '😍', '🥰', '😘', '😎', '🤩', '😇', '🙂',
          '🙃', '😉', '🤗', '🤔', '😌', '😴', '😮', '😢', '😭', '😡', '🤯', '🥳',
        ],
      ),
      (
        id: 'work',
        label: t(widget.lang, 'emojiCategoryWork'),
        symbols: const [
          '💼', '📊', '📈', '📉', '📌', '🗂️', '📎', '📝', '📣', '📅', '⏰', '⌛',
          '🧠', '💡', '✅', '📍', '🏢', '🧑‍💻', '💻', '🧾', '🤝', '📞', '📧', '🧮',
        ],
      ),
      (
        id: 'celebrate',
        label: t(widget.lang, 'emojiCategoryCelebrate'),
        symbols: const [
          '🎉', '🎊', '🏆', '🥇', '🥈', '🥉', '👏', '🙌', '🔥', '✨', '🌟', '💯',
          '🚀', '🎯', '🏅', '🍾', '🥂', '🎈', '🌈', '⭐', '🎖️', '🫶', '🙏', '🤍',
        ],
      ),
      (
        id: 'people',
        label: t(widget.lang, 'emojiCategoryPeople'),
        symbols: const [
          '👋', '🤝', '🫂', '👍', '👎', '👌', '✌️', '🤞', '🫡', '🙏', '💪', '🧑',
          '👨‍💼', '👩‍💼', '🧑‍🏫', '🧑‍🔧', '🧑‍⚕️', '👨‍💻', '👩‍💻', '👥', '🗣️', '🧍',
        ],
      ),
    ];

    final selected = await _pickSymbolFromCategories(
      title: t(widget.lang, 'pickEmoji'),
      categories: categories,
    );

    if (selected == null || selected.isEmpty) return;

    final currentText = _postComposerCtrl.text;
    final selection = _postComposerCtrl.selection;
    if (!selection.isValid) {
      _postComposerCtrl.text = '$currentText $selected'.trim();
      setState(() {});
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final nextText = currentText.replaceRange(start, end, '$selected ');
    _postComposerCtrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + selected.length + 1),
    );
    setState(() {});
  }

  Future<void> _pickPostSticker() async {
    if (!_canCreateActivityPosts) return;

    final categories = <({String id, String label, List<String> symbols})>[
      (
        id: 'business',
        label: t(widget.lang, 'stickerCategoryBusiness'),
        symbols: const [
          '💼', '📊', '📈', '📉', '📌', '🧾', '🗂️', '🧑‍💻', '🏢', '📅', '⏰', '✅',
        ],
      ),
      (
        id: 'motivation',
        label: t(widget.lang, 'stickerCategoryMotivation'),
        symbols: const [
          '🚀', '🔥', '🎯', '🏆', '✨', '🌟', '💡', '📣', '💪', '💯', '🎉', '🙌',
        ],
      ),
      (
        id: 'reactions',
        label: t(widget.lang, 'stickerCategoryReactions'),
        symbols: const [
          '👏', '🤝', '🙌', '👍', '👌', '🙏', '🤩', '😎', '🥳', '❤️', '🫶', '🤗',
        ],
      ),
      (
        id: 'status',
        label: t(widget.lang, 'stickerCategoryStatus'),
        symbols: const [
          '🟢', '🟡', '🔴', '🟣', '⚪', '⚫', '✅', '❗', '❕', '🔔', '📍', '🆕',
        ],
      ),
    ];

    final selected = await _pickSymbolFromCategories(
      title: t(widget.lang, 'pickSticker'),
      categories: categories,
      symbolFontSize: 28,
      showBorder: true,
    );

    if (selected == null) return;
    setState(() => _selectedSticker = selected);
  }

  Future<void> _pickPostAttachment() async {
    final token = accessToken;
    if (token == null || token.isEmpty || _isPreviewMode || !_canCreateActivityPosts) {
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'pdf', 'doc', 'docx', 'txt', 'zip'],
    );

    if (picked == null || picked.files.isEmpty) return;

    for (final file in picked.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final fileName = file.name;
      final mimeType = _guessMimeType(fileName);
      final isMedia = mimeType.startsWith('image/');

      try {
        final attachmentId = await ApiService.uploadPostAttachment(
          accessToken: token,
          attachmentType: isMedia ? 'post_media' : 'post_file',
          bytes: bytes,
          fileName: fileName,
          mimeType: mimeType,
        );

        if (attachmentId.isEmpty) continue;

        if (!mounted) return;
        setState(() {
          _pendingPostAttachments.add({
            'id': attachmentId,
            'fileName': fileName,
            'mimeType': mimeType,
            'fileSizeBytes': bytes.length,
          });
        });
      } on ApiException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  Future<void> _submitActivityPost() async {
    final token = accessToken;
    if (token == null ||
        token.isEmpty ||
        _isPostingActivity ||
        _isPreviewMode ||
        !_canCreateActivityPosts) {
      return;
    }

    final content = _postComposerCtrl.text.trim();
    final sticker = _selectedSticker;
    final attachmentIds = _pendingPostAttachments
        .map((attachment) => attachment['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    if (content.isEmpty && (sticker == null || sticker.isEmpty) && attachmentIds.isEmpty) {
      return;
    }

    setState(() => _isPostingActivity = true);

    try {
      final response = await ApiService.createActivityPost(
        accessToken: token,
        content: content,
        sticker: sticker,
        attachmentIds: attachmentIds,
      );

      if (!mounted) return;
      final post = response['post'];
      if (post is Map<String, dynamic>) {
        final currentPosts = (profileData?['activityPosts'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList(growable: true) ??
            <Map<String, dynamic>>[];
        currentPosts.insert(0, post);
        setState(() {
          profileData = {
            ...(profileData ?? const <String, dynamic>{}),
            'activityPosts': currentPosts,
          };
          _postComposerCtrl.clear();
          _selectedSticker = null;
          _pendingPostAttachments.clear();
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isPostingActivity = false);
      }
    }
  }

  Future<void> _submitActivityComment(String postId) async {
    final token = accessToken;
    if (token == null ||
        token.isEmpty ||
        _isPreviewMode ||
        !_canCommentOnActivity ||
        _postingCommentForPostIds.contains(postId)) {
      return;
    }

    final controller = _commentControllerFor(postId);
    final content = controller.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _postingCommentForPostIds.add(postId);
    });

    try {
      final response = await ApiService.createActivityComment(
        accessToken: token,
        postId: postId,
        content: content,
      );

      if (!mounted) return;

      final comment = response['comment'];
      if (comment is! Map<String, dynamic>) return;

      final posts = (profileData?['activityPosts'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList(growable: true) ??
          <Map<String, dynamic>>[];

      final index = posts.indexWhere(
        (entry) => entry['id']?.toString() == postId,
      );
      if (index < 0) return;

      final targetPost = Map<String, dynamic>.from(posts[index]);
      final comments = (targetPost['comments'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList(growable: true) ??
          <Map<String, dynamic>>[];
      comments.add(comment);
      targetPost['comments'] = comments;
      posts[index] = targetPost;

      setState(() {
        profileData = {
          ...(profileData ?? const <String, dynamic>{}),
          'activityPosts': posts,
        };
        controller.clear();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _postingCommentForPostIds.remove(postId);
        });
      }
    }
  }

  Future<void> _editActivityPost(Map<String, dynamic> post) async {
    final token = accessToken;
    if (token == null || token.isEmpty || _isPreviewMode) return;

    final postId = post['id']?.toString() ?? '';
    if (postId.isEmpty) return;

    final textController = TextEditingController(
      text: post['content']?.toString() ?? '',
    );
    String? localSticker = post['sticker']?.toString();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(t(widget.lang, 'editPost')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: t(widget.lang, 'postPlaceholder'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('${t(widget.lang, 'pickSticker')}: '),
                      const SizedBox(width: 6),
                      Text(localSticker ?? '-'),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setDialogState(() => localSticker = null),
                        child: Text(t(widget.lang, 'clear')),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(t(widget.lang, 'cancel')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(t(widget.lang, 'saveChanges')),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      textController.dispose();
      return;
    }

    setState(() => _editingPostId = postId);

    try {
      final response = await ApiService.updateActivityPost(
        accessToken: token,
        postId: postId,
        content: textController.text.trim(),
        sticker: localSticker,
      );

      if (!mounted) return;

      final updatedPost = response['post'];
      if (updatedPost is Map<String, dynamic>) {
        final currentPosts = (profileData?['activityPosts'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList(growable: true) ??
            <Map<String, dynamic>>[];

        final index = currentPosts.indexWhere(
          (entry) => entry['id']?.toString() == postId,
        );
        if (index >= 0) {
          currentPosts[index] = updatedPost;
          setState(() {
            profileData = {
              ...(profileData ?? const <String, dynamic>{}),
              'activityPosts': currentPosts,
            };
          });
        }
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      textController.dispose();
      if (mounted) {
        setState(() => _editingPostId = null);
      }
    }
  }

  Future<void> _deleteActivityPost(String postId) async {
    final token = accessToken;
    if (token == null || token.isEmpty || _isPreviewMode) return;

    setState(() => _editingPostId = postId);

    try {
      await ApiService.deleteActivityPost(accessToken: token, postId: postId);
      if (!mounted) return;

      final currentPosts = (profileData?['activityPosts'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList(growable: true) ??
          <Map<String, dynamic>>[];

      currentPosts.removeWhere((entry) => entry['id']?.toString() == postId);

      setState(() {
        profileData = {
          ...(profileData ?? const <String, dynamic>{}),
          'activityPosts': currentPosts,
        };
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _editingPostId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(24),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : _buildProfileContent(),
    );

    if (widget.useEmbeddedLayout) {
      return content;
    }

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
      child: content,
    );
  }

  Widget _buildProfileContent() {
    final accountType = profileData?['accountType'] as String? ?? 'user';
    final user = profileData?['user'] as Map<String, dynamic>? ?? {};
    final userProfile = profileData?['userProfile'] as Map<String, dynamic>?;
    final companyProfile =
        profileData?['companyProfile'] as Map<String, dynamic>?;
    final userExperiences = (profileData?['userExperiences'] as List?)
        ?.whereType<Map<String, dynamic>>()
        .toList(growable: false) ??
      const <Map<String, dynamic>>[];
    final userEducations = (profileData?['userEducations'] as List?)
        ?.whereType<Map<String, dynamic>>()
        .toList(growable: false) ??
      const <Map<String, dynamic>>[];
    final userSkills = (profileData?['userSkills'] as List?)
        ?.whereType<Map<String, dynamic>>()
        .toList(growable: false) ??
      const <Map<String, dynamic>>[];
    final activityPosts = (profileData?['activityPosts'] as List?)
        ?.whereType<Map<String, dynamic>>()
        .toList(growable: false) ??
      const <Map<String, dynamic>>[];
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

    final locationParts = <String>[];
    if (_isVisible('showCountry')) {
      final country = userProfile?['country']?.toString().trim() ?? '';
      if (country.isNotEmpty) locationParts.add(country);
    }
    if (_isVisible('showCity')) {
      final city = userProfile?['city']?.toString().trim() ?? '';
      if (city.isNotEmpty) locationParts.add(city);
    }
    if (_isVisible('showCounty')) {
      final county = userProfile?['county']?.toString().trim() ?? '';
      if (county.isNotEmpty) locationParts.add(county);
    }
    final locationConcatenated = locationParts.join(', ');

    final profileSummary =
        _isVisible('showProfileSummary') && accountType == 'user'
        ? (userProfile?['profileSummary']?.toString().trim() ?? '')
        : '';

    final professionalStatusRaw =
        _isVisible('showProfessionalStatus') && accountType == 'user'
        ? (userProfile?['professionalStatus']?.toString())
        : null;
    final professionalStatusColors = _professionalStatusColors(
      professionalStatusRaw,
    );
    final hasSocialProfile = _displayedUserId != null;
    final isOwnProfile =
      !_isPreviewMode ||
      (_authUserId != null && _displayedUserId == _authUserId);
    final followerCount = (_socialSummary?['followerCount'] as num?)?.toInt() ?? 0;
    final contactCount = (_socialSummary?['contactCount'] as num?)?.toInt() ?? 0;
    final isFollowing = _socialSummary?['isFollowing'] == true;
    final contactStatus = _socialSummary?['contactStatus']?.toString() ?? 'none';

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobileHeader = screenWidth < 720;
    final isTabletHeader = screenWidth >= 720 && screenWidth < 1100;
    final headerTopSpacing = isMobileHeader ? 8.0 : 16.0;
    final headerTextLeftPadding = isMobileHeader
        ? 102.0
        : (isTabletHeader ? 128.0 : 136.0);
    final avatarLeft = isMobileHeader ? 4.0 : 6.0;
    final avatarTop = isMobileHeader ? 10.0 : (isTabletHeader ? 12.0 : 14.0);
    final nameFontSize = isMobileHeader ? 22.0 : (isTabletHeader ? 25.0 : 28.0);
    final occupationFontSize = isMobileHeader
        ? 20.0
        : (isTabletHeader ? 22.0 : 24.0);
    final locationFontSize = isMobileHeader ? 14.0 : 15.0;
    final genderFontSize = isMobileHeader
        ? 20.0
        : (isTabletHeader ? 22.0 : 24.0);

    final visibleSocialLinks = <Map<String, dynamic>>[
      {
        'label': 'LinkedIn',
        'value': userProfile?['linkedInUrl']?.toString() ?? '',
        'visibility': 'showLinkedIn',
        'icon': Icons.business_center_rounded,
      },
      {
        'label': 'GitHub',
        'value': userProfile?['githubUrl']?.toString() ?? '',
        'visibility': 'showGithub',
        'icon': Icons.code_rounded,
      },
      {
        'label': 'YouTube',
        'value': userProfile?['youtubeUrl']?.toString() ?? '',
        'visibility': 'showYoutube',
        'icon': Icons.play_circle_fill_rounded,
      },
      {
        'label': 'Instagram',
        'value': userProfile?['instagramUrl']?.toString() ?? '',
        'visibility': 'showInstagram',
        'icon': Icons.camera_alt_rounded,
      },
      {
        'label': 'TikTok',
        'value': userProfile?['tiktokUrl']?.toString() ?? '',
        'visibility': 'showTiktok',
        'icon': Icons.music_note_rounded,
      },
    ].where((entry) {
      final value = entry['value']?.toString().trim() ?? '';
      return _isVisible(entry['visibility']?.toString() ?? '') &&
          value.isNotEmpty;
    }).toList(growable: false);

    final visibleExperiences = userExperiences
        .where((entry) => entry['showOnProfile'] != false)
        .toList(growable: false);

    final visibleEducations = userEducations
        .where((entry) => entry['showOnProfile'] != false)
        .toList(growable: false);

    final visibleSkills = userSkills
        .where((entry) => entry['isVisible'] == true)
        .toList(growable: false);

    final userProjects = (profileData?['userProjects'] as List?)
        ?.whereType<Map<String, dynamic>>()
        .toList(growable: false) ??
      const <Map<String, dynamic>>[];

    final visibleProjects = userProjects
      .where((entry) => entry['showOnProfile'] != false)
      .toList(growable: false);

    final groupedSkills = <String, List<Map<String, dynamic>>>{
      'language': visibleSkills
          .where((entry) => entry['category']?.toString() == 'language')
          .toList(growable: false),
      'soft': visibleSkills
          .where((entry) => entry['category']?.toString() == 'soft')
          .toList(growable: false),
      'hard': visibleSkills
          .where((entry) => entry['category']?.toString() == 'hard')
          .toList(growable: false),
    };

    final hasExperienceSection = visibleExperiences.isNotEmpty;
    final hasSkillsSection = groupedSkills.values.any((entries) => entries.isNotEmpty);
    final hasEducationSection = visibleEducations.isNotEmpty;
    final hasProjectsSection = visibleProjects.isNotEmpty;

    final visibleSections = <({GlobalKey key, String label})>[
      if (hasExperienceSection)
        (key: _experienceSectionKey, label: t(widget.lang, 'experienceSection')),
      if (hasSkillsSection)
        (key: _skillsSectionKey, label: t(widget.lang, 'skillsSection')),
      if (hasEducationSection)
        (key: _educationSectionKey, label: t(widget.lang, 'educationSection')),
      if (hasProjectsSection)
        (key: _projectsSectionKey, label: t(widget.lang, 'projectsSection')),
    ];

    final topContent = Column(
      children: [
        SizedBox(height: headerTopSpacing),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _futuristicHeroSection(
              child: Padding(
                padding: EdgeInsets.fromLTRB(headerTextLeftPadding, 8, 2, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (genderEmoji != null) ...[
                                Text(
                                  genderEmoji,
                                  style: TextStyle(
                                    fontSize: genderFontSize,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  headline.isEmpty ? '-' : headline,
                                  style: TextStyle(
                                    fontSize: nameFontSize,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
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
                          const SizedBox(height: 8),
                          Text(
                            occupation,
                            style: TextStyle(
                              fontSize: occupationFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (locationConcatenated.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: Theme.of(context).hintColor,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    locationConcatenated,
                                    style: TextStyle(
                                      color: Theme.of(context).hintColor,
                                      fontWeight: FontWeight.w500,
                                      fontSize: locationFontSize,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (hasSocialProfile) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_socialSummaryLoading || _socialListsLoading)
                                  Chip(
                                    avatar: const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    label: Text(
                                      _localized('Se încarcă conexiunile', 'Loading connections'),
                                    ),
                                  ),
                                ActionChip(
                                  onPressed: () async {
                                    final token = accessToken ??
                                        await SecureStorage.read('access_token');
                                    final userId = _displayedUserId;
                                    final summary = _socialSummary;
                                    final isOwnProfile = _authUserId != null &&
                                        _authUserId == userId;

                                    if (token != null &&
                                        token.isNotEmpty &&
                                        userId != null &&
                                        summary != null) {
                                      await _loadSocialLists(
                                        token,
                                        userId,
                                        summary,
                                        isOwnProfile: isOwnProfile,
                                      );
                                    }

                                    if (!mounted) return;
                                    _showSocialPeopleDialog(
                                      title: _localized('Urmăritori', 'Followers'),
                                      emptyLabel: _localized(
                                        _followersListVisible
                                            ? 'Nu există urmăritori afișați încă.'
                                            : 'Lista de urmăritori este privată.',
                                        _followersListVisible
                                            ? 'No followers to display yet.'
                                            : 'The follower list is private.',
                                      ),
                                      people: _followers,
                                      icon: Icons.groups_2_outlined,
                                    );
                                  },
                                  avatar: const Icon(Icons.groups_2_outlined, size: 18),
                                  label: Text(
                                    '$followerCount ${_localized('Urmăritori', 'Followers')}',
                                  ),
                                ),
                                ActionChip(
                                  onPressed: () async {
                                    final token = accessToken ??
                                        await SecureStorage.read('access_token');
                                    final userId = _displayedUserId;
                                    final summary = _socialSummary;
                                    final isOwnProfile = _authUserId != null &&
                                        _authUserId == userId;

                                    if (token != null &&
                                        token.isNotEmpty &&
                                        userId != null &&
                                        summary != null) {
                                      await _loadSocialLists(
                                        token,
                                        userId,
                                        summary,
                                        isOwnProfile: isOwnProfile,
                                      );
                                    }

                                    if (!mounted) return;
                                    _showSocialPeopleDialog(
                                      title: _localized('Contacte', 'Contacts'),
                                      emptyLabel: _localized(
                                        _contactsListVisible
                                            ? 'Nu există contacte afișate încă.'
                                            : 'Lista de contacte este privată.',
                                        _contactsListVisible
                                            ? 'No contacts to display yet.'
                                            : 'The contact list is private.',
                                      ),
                                      people: _contacts,
                                      icon: Icons.handshake_outlined,
                                    );
                                  },
                                  avatar: const Icon(Icons.contact_page_outlined, size: 18),
                                  label: Text(
                                    '$contactCount ${_localized('Contacte', 'Contacts')}',
                                  ),
                                ),
                                if (contactStatus == 'accepted' && !isOwnProfile)
                                  Chip(
                                    avatar: const Icon(Icons.handshake_outlined, size: 18),
                                    label: Text(
                                      _localized('Sunteți contacte', 'You are contacts'),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: isMobileHeader ? 148 : 184,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (hasSocialProfile && !isOwnProfile) ...[
                            FilledButton.icon(
                              onPressed: _socialActionBusy ? null : _onMessageTap,
                              icon: const Icon(Icons.chat_bubble_outline_rounded),
                              label: Text(t(widget.lang, 'message')),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _socialActionBusy
                                  ? null
                                  : (isFollowing ? _unfollowUser : _followUser),
                              icon: Icon(
                                isFollowing
                                    ? Icons.person_remove_alt_1_rounded
                                    : Icons.person_add_alt_1_rounded,
                              ),
                              label: Text(
                                isFollowing
                                    ? _localized('Nu mai urmări', 'Unfollow')
                                    : _localized('Urmărește', 'Follow'),
                              ),
                            ),
                          ] else ...[
                            FilledButton.icon(
                              onPressed: hasCv ? _onDownloadCvTap : null,
                              icon: const Icon(Icons.download_rounded),
                              label: Text(t(widget.lang, 'downloadCvAction')),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: avatarLeft,
              top: avatarTop,
              child: _profileAvatarWithStatus(
                professionalStatusRaw,
                professionalStatusColors,
                isMobile: isMobileHeader,
                isTablet: isTabletHeader,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _futuristicSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(widget.lang, 'achievements'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
              if (profileSummary.isNotEmpty) ...[
                const SizedBox(height: 14),
                _futuristicSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(widget.lang, 'profileSummary'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(profileSummary),
                    ],
                  ),
                ),
              ],
        if (visibleSocialLinks.isNotEmpty) ...[
          const SizedBox(height: 14),
          _futuristicSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(widget.lang, 'socialLinks'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: visibleSocialLinks
                      .map(
                        (entry) => _socialLinkTile(
                          label: entry['label']?.toString() ?? '-',
                          value: entry['value']?.toString() ?? '',
                          icon: entry['icon'] as IconData,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
      ],
    );

    return CustomScrollView(
      controller: _profileScrollController,
      slivers: [
        SliverToBoxAdapter(child: topContent),
        if (visibleSections.isNotEmpty)
          SliverPersistentHeader(
            pinned: true,
            delegate: _ProfileStickyHeaderDelegate(
              minHeight: 86,
              maxHeight: 86,
              child: _buildJumpTabs(visibleSections),
            ),
          ),
        SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1040;

              final leftColumn = Column(
                children: [
                  if (hasExperienceSection)
                    _profileCategorySection(
                      sectionKey: _experienceSectionKey,
                      title: t(widget.lang, 'experienceSection'),
                      child: _experienceList(visibleExperiences),
                    ),
                  if (hasExperienceSection && (hasSkillsSection || hasEducationSection || hasProjectsSection))
                    const SizedBox(height: 14),
                  if (hasSkillsSection)
                    _profileCategorySection(
                      sectionKey: _skillsSectionKey,
                      title: t(widget.lang, 'skillsSection'),
                      child: _skillsList(groupedSkills),
                    ),
                  if (hasSkillsSection && (hasEducationSection || hasProjectsSection))
                    const SizedBox(height: 14),
                  if (hasEducationSection)
                    _profileCategorySection(
                      sectionKey: _educationSectionKey,
                      title: t(widget.lang, 'educationSection'),
                      child: _educationList(visibleEducations),
                    ),
                  if (hasEducationSection && hasProjectsSection)
                    const SizedBox(height: 14),
                  if (hasProjectsSection)
                    _profileCategorySection(
                      sectionKey: _projectsSectionKey,
                      title: t(widget.lang, 'projectsSection'),
                      child: _projectsList(visibleProjects),
                    ),
                ],
              );

              final rightFeed = _profileCategorySection(
                title: t(widget.lang, 'activityFeed'),
                child: _activityFeedList(activityPosts),
              );

              if (!isWide) {
                return Column(
                  children: [
                    leftColumn,
                    const SizedBox(height: 14),
                    rightFeed,
                    const SizedBox(height: 14),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: leftColumn),
                  const SizedBox(width: 14),
                  Expanded(flex: 4, child: rightFeed),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _socialLinkTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openSocialLink(value),
      child: Container(
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _showSocialPeopleDialog({
    required String title,
    required String emptyLabel,
    required List<Map<String, dynamic>> people,
    required IconData icon,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 460,
            child: people.isEmpty
                ? Text(
                    emptyLabel,
                    style: TextStyle(color: Theme.of(dialogContext).hintColor),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: people.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final person = people[index];
                      final userId = person['userId']?.toString().trim() ?? '';
                      return Container(
                        padding: EdgeInsets.zero,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.36),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: userId.isEmpty
                              ? null
                              : () async {
                                  Navigator.of(dialogContext).pop();
                                  await _openSocialPersonProfile(person);
                                },
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                _socialPersonAvatar(person, icon),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        person['fullName']?.toString() ?? '-',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        person['email']?.toString() ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Theme.of(dialogContext).hintColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_localized('Închide', 'Close')),
            ),
          ],
        );
      },
    );
  }

  Widget _profileCategorySection({
    Key? sectionKey,
    required String title,
    required Widget child,
  }) {
    return KeyedSubtree(
      key: sectionKey,
      child: _futuristicSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _experienceList(List<Map<String, dynamic>> experiences) {
    return Column(
      children: experiences
          .map(
            (experience) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      _experiencePeriod(experience),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          experience['companyName']?.toString() ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          experience['jobTitle']?.toString() ?? '-',
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if ((experience['description']?.toString().trim().isNotEmpty ?? false))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(experience['description'].toString()),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _skillsList(Map<String, List<Map<String, dynamic>>> groupedSkills) {
    Widget skillsColumn(String title, List<Map<String, dynamic>> items) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...items.map(
              (entry) {
                final rawScore = entry['score'];
                final parsedScore = rawScore is num
                    ? rawScore.toDouble()
                    : double.tryParse(rawScore?.toString() ?? '');
                final normalizedScore = (parsedScore ?? 1).clamp(1.0, 10.0);
                final value = normalizedScore / 10.0;
                final percent = (value * 100).round();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry['name']?.toString() ?? '-',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 110,
                        child: LinearProgressIndicator(value: value, minHeight: 7),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 42,
                        child: Text(
                          '$percent%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            skillsColumn(
              t(widget.lang, 'skillsLanguages'),
              groupedSkills['language'] ?? const <Map<String, dynamic>>[],
            ),
            const SizedBox(width: 14),
            skillsColumn(
              t(widget.lang, 'skillsSoft'),
              groupedSkills['soft'] ?? const <Map<String, dynamic>>[],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            skillsColumn(
              t(widget.lang, 'skillsHard'),
              groupedSkills['hard'] ?? const <Map<String, dynamic>>[],
            ),
            const Spacer(),
          ],
        ),
      ],
    );
  }

  Widget _educationList(List<Map<String, dynamic>> educations) {
    return Column(
      children: educations
          .map(
            (education) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      _educationPeriod(education),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isVisible('showEducationInstitution')
                              ? (education['university']?.toString() ?? '-')
                              : '-',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (_isVisible('showEducationLevel'))
                          Text(
                            education['educationLevel']?.toString() ?? '-',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (_isVisible('showSpecialization') &&
                            _isUniversityEducationLevel(
                              education['educationLevel']?.toString(),
                            ) &&
                            (education['specialization']
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ??
                                false))
                          Text(
                            education['specialization']?.toString() ?? '-',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _projectsList(List<Map<String, dynamic>> projects) {
    if (projects.isEmpty) {
      return Text('-', style: TextStyle(color: Theme.of(context).hintColor));
    }

    return Column(
      children: projects
          .map(
            (project) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 180,
                    child: Text(
                      _projectPeriod(project),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final title = project['title']?.toString().trim() ?? '-';
                            final githubUrl = project['githubUrl']?.toString().trim() ?? '';

                            if (githubUrl.isNotEmpty) {
                              return InkWell(
                                onTap: () => _openSocialLink(githubUrl),
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              );
                            }

                            return Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            );
                          },
                        ),
                        if ((project['description']?.toString().trim().isNotEmpty ?? false)) ...[
                          const SizedBox(height: 4),
                          Text(project['description']?.toString() ?? ''),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _activityFeedList(List<Map<String, dynamic>> posts) {
    Widget composerAction({
      required IconData icon,
      required String tooltip,
      required VoidCallback? onTap,
    }) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(icon, size: 18),
          ),
        ),
      );
    }

    final postWidgets = posts.map((post) {
      final postId = post['id']?.toString() ?? '';
      final content = post['content']?.toString() ?? '';
      final sticker = post['sticker']?.toString();
      final canEditPost =
          post['canEdit'] == true || (!_isPreviewMode && post['canEdit'] == null);
      final attachments = (post['attachments'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList(growable: false) ??
          const <Map<String, dynamic>>[];
      final comments = (post['comments'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList(growable: false) ??
          const <Map<String, dynamic>>[];
      final commentController = postId.isEmpty ? null : _commentControllerFor(postId);
      final isCommentBusy = _postingCommentForPostIds.contains(postId);

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.14),
                    child: Icon(
                      Icons.campaign_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t(widget.lang, 'activityPostLabel'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (!_isPreviewMode && canEditPost)
                    PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') {
                          unawaited(_editActivityPost(post));
                        } else if (action == 'delete' && postId.isNotEmpty) {
                          unawaited(_deleteActivityPost(postId));
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(t(widget.lang, 'editPost')),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(t(widget.lang, 'deletePost')),
                        ),
                      ],
                    ),
                ],
              ),
              if (_editingPostId == postId)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if ((sticker ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(sticker!, style: const TextStyle(fontSize: 28)),
                ),
              if (content.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(content),
                ),
              if (attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: attachments
                        .map(
                          (attachment) => Chip(
                            label: Text(
                              attachment['fileName']?.toString() ?? '-',
                              overflow: TextOverflow.ellipsis,
                            ),
                            avatar: Icon(
                              (attachment['mimeType']?.toString().startsWith('image/') ??
                                      false)
                                  ? Icons.image_outlined
                                  : Icons.attach_file_rounded,
                              size: 16,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              if (comments.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '${t(widget.lang, 'activityComments')} (${comments.length})',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ...comments.map(
                  (comment) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.55),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment['authorName']?.toString() ?? 'User',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(comment['content']?.toString() ?? ''),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (_canCommentOnActivity && !_isPreviewMode && postId.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        minLines: 1,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: t(widget.lang, 'activityCommentPlaceholder'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: isCommentBusy ||
                              (commentController?.text.trim().isEmpty ?? true)
                          ? null
                          : () {
                              unawaited(_submitActivityComment(postId));
                            },
                      icon: isCommentBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      tooltip: t(widget.lang, 'commentAction'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }).toList(growable: false);

    final composer = _isPreviewMode
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_canCreateActivityPosts) ...[
                TextField(
                  controller: _postComposerCtrl,
                  maxLines: 4,
                  maxLength: 280,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: t(widget.lang, 'postPlaceholder'),
                    counterText: '',
                  ),
                ),
                Row(
                  children: [
                    composerAction(
                      icon: Icons.emoji_emotions_outlined,
                      tooltip: t(widget.lang, 'addEmoji'),
                      onTap: _pickPostEmoji,
                    ),
                    const SizedBox(width: 8),
                    composerAction(
                      icon: Icons.emoji_objects_outlined,
                      tooltip: t(widget.lang, 'addSticker'),
                      onTap: _pickPostSticker,
                    ),
                    const SizedBox(width: 8),
                    composerAction(
                      icon: Icons.attach_file_rounded,
                      tooltip: t(widget.lang, 'addAttachment'),
                      onTap: _pickPostAttachment,
                    ),
                    const Spacer(),
                    Text(
                      '${_postComposerCtrl.text.length}/280',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
                if (_selectedSticker != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('${t(widget.lang, 'pickSticker')}: $_selectedSticker'),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => setState(() => _selectedSticker = null),
                        child: Text(t(widget.lang, 'clear')),
                      ),
                    ],
                  ),
                ],
                if (_pendingPostAttachments.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _pendingPostAttachments
                        .map(
                          (attachment) => Chip(
                            label: Text(attachment['fileName']?.toString() ?? '-'),
                            onDeleted: () {
                              setState(() {
                                _pendingPostAttachments.remove(attachment);
                              });
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isPostingActivity ? null : _submitActivityPost,
                    icon: _isPostingActivity
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(t(widget.lang, 'postAction')),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    t(widget.lang, 'activityPostOwnerOnly'),
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          );

    if (postWidgets.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          composer,
          Text(
            t(widget.lang, 'activityEmptyState'),
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        composer,
        ...postWidgets,
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

  Widget _profileAvatarWithStatus(
    String? professionalStatusRaw,
    ({Color background, Color foreground}) professionalStatusColors, {
    required bool isMobile,
    required bool isTablet,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final avatarSize = isMobile ? 88.0 : (isTablet ? 98.0 : 108.0);
    final avatarBlockWidth = isMobile ? 110.0 : (isTablet ? 122.0 : 132.0);
    final avatarBlockHeight = isMobile ? 136.0 : (isTablet ? 146.0 : 158.0);
    final avatarInnerPadding = isMobile ? 3.0 : 3.5;
    final statusTop = avatarSize + 6;
    final statusFontSize = isMobile ? 12.0 : 13.0;
    final statusIconSize = isMobile ? 13.0 : 14.0;
    final fallbackIconSize = isMobile ? 36.0 : (isTablet ? 39.0 : 42.0);

    return SizedBox(
      width: avatarBlockWidth,
      height: avatarBlockHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: avatarBytes == null ? null : _showAvatarPreview,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              padding: EdgeInsets.all(avatarInnerPadding),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.95),
                    scheme.secondary.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.45),
                    blurRadius: isMobile ? 16 : 20,
                    spreadRadius: 1,
                    offset: Offset(0, isMobile ? 8 : 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: isMobile ? 10 : 14,
                    offset: Offset(0, isMobile ? 6 : 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: avatarBytes != null
                      ? Image.memory(
                          avatarBytes!,
                          width: avatarSize,
                          height: avatarSize,
                          fit: BoxFit.cover,
                        )
                      : Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                          size: fallbackIconSize,
                        ),
                ),
              ),
            ),
          ),
          if (professionalStatusRaw != null)
            Positioned(
              top: statusTop,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 12,
                  vertical: isMobile ? 5 : 6,
                ),
                decoration: BoxDecoration(
                  color: professionalStatusColors.background,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.26),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: -0.06,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.work_outline_rounded,
                        size: statusIconSize,
                        color: professionalStatusColors.foreground,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _professionalStatusLabel(professionalStatusRaw),
                        style: TextStyle(
                          color: professionalStatusColors.foreground,
                          fontWeight: FontWeight.w700,
                          fontSize: statusFontSize,
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
  }

  Widget _futuristicHeroSection({required Widget child}) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
        bottomLeft: Radius.circular(26),
        bottomRight: Radius.circular(38),
      ),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.16),
                    scheme.secondary.withValues(alpha: 0.12),
                    scheme.surface.withValues(alpha: 0.78),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.32),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.2),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: child,
            ),
          ),
          Positioned(
            right: -12,
            bottom: -16,
            child: Transform.rotate(
              angle: -0.18,
              child: Container(
                width: 70,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onMessageTap() {
    unawaited(_startDirectConversation());
  }

  Future<void> _runSocialAction(
    Future<void> Function(String token, String userId) action,
  ) async {
    final token = accessToken ?? await SecureStorage.read('access_token');
    final authUserId = _authUserId ?? _extractUserIdFromToken(token);
    final userId = _displayedUserId;
    if (token == null || token.isEmpty || userId == null || _socialActionBusy) {
      return;
    }

    if (authUserId != null && authUserId == userId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRomanianLanguage
                ? 'Nu poți folosi Follow pe propriul profil.'
                : 'You cannot follow your own profile.',
          ),
        ),
      );
      return;
    }

    setState(() => _socialActionBusy = true);
    try {
      await action(token, userId);
      await _loadSocialSummary();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _socialActionBusy = false);
      }
    }
  }

  Future<void> _followUser() async {
    await _runSocialAction((token, userId) async {
      await ApiService.followUser(accessToken: token, userId: userId);
    });
  }

  Future<void> _unfollowUser() async {
    await _runSocialAction((token, userId) async {
      await ApiService.unfollowUser(accessToken: token, userId: userId);
    });
  }

  Future<void> _startDirectConversation() async {
    final token = accessToken ?? await SecureStorage.read('access_token');
    final authUserId = _authUserId ?? _extractUserIdFromToken(token);
    final userId = _displayedUserId;
    if (token == null || token.isEmpty || userId == null) return;

    if (authUserId != null && authUserId == userId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRomanianLanguage
                ? 'Nu poți trimite mesaje către propriul profil.'
                : 'You cannot message your own profile.',
          ),
        ),
      );
      return;
    }

    try {
      final response = await ApiService.createDirectMessageConversation(
        accessToken: token,
        otherUserId: userId,
      );
      final conversationId = response['id']?.toString() ?? '';
      if (!mounted || conversationId.isEmpty) return;
      AuthenticatedPageShell.requestOpenConversation(conversationId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRomanianLanguage
                ? 'Conversația a fost deschisă.'
                : 'Conversation opened.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  void _onDownloadCvTap() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t(widget.lang, 'comingSoon'))));
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
                  color: scheme.primary.withValues(
                    alpha: isHovered ? 0.52 : 0.38,
                  ),
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

}

class _ProfileStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _ProfileStickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _ProfileStickyHeaderDelegate oldDelegate) {
    return minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight ||
        child != oldDelegate.child;
  }
}
