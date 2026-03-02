import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'top_bar.dart';
import '../core/texts.dart';
import '../pages/achievements_page.dart';
import '../pages/profile_page.dart';
import '../pages/profile_search_page.dart';
import '../pages/settings_page.dart';
import '../services/api_service.dart';
import '../services/secure_storage.dart';

enum _NotificationCategory { settings, activities, jobs, comment, message }

class _TopNotificationItem {
  _TopNotificationItem({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.sentAt,
    required this.isImportant,
  });

  final String id;
  final _NotificationCategory category;
  final String title;
  final String description;
  final DateTime sentAt;
  final bool isImportant;
}

class AuthenticatedPageShell extends StatefulWidget {
  final String lang;
  final bool isDark;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final Widget child;
  final Future<void> Function() onLogout;
  final bool isHomePage;

  const AuthenticatedPageShell({
    super.key,
    required this.lang,
    required this.isDark,
    required this.onLangChange,
    required this.onThemeChange,
    required this.child,
    required this.onLogout,
    this.isHomePage = false,
  });

  @override
  State<AuthenticatedPageShell> createState() => _AuthenticatedPageShellState();
}

class _AuthenticatedPageShellState extends State<AuthenticatedPageShell> {
  static const String _avatarCacheKey = 'profile_avatar_base64_cache';
  Uint8List? avatarBytes;
  bool isAvatarHovered = false;
  final List<_TopNotificationItem> _notifications = <_TopNotificationItem>[];
  final Set<String> _seenNotificationIds = <String>{};

  int _notificationBadgeCount = 0;
  DateTime _notificationsOpenedAt = DateTime.now();
  String? _hoveredNotificationId;

  late String currentLang;
  late bool currentIsDark;

  @override
  void initState() {
    super.initState();
    currentLang = widget.lang;
    currentIsDark = widget.isDark;
    _loadAvatarFromCache();
    _loadAvatarFromServer();
    _refreshTopNotifications();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedPageShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.lang != widget.lang && currentLang != widget.lang) {
      currentLang = widget.lang;
    }

    if (oldWidget.isDark != widget.isDark && currentIsDark != widget.isDark) {
      currentIsDark = widget.isDark;
    }
  }

  Future<void> _loadAvatarFromCache() async {
    final encoded = await SecureStorage.read(_avatarCacheKey);
    if (!mounted || encoded == null || encoded.isEmpty) return;

    try {
      final bytes = base64Decode(encoded);
      if (!_isSupportedImage(bytes)) {
        await SecureStorage.delete(_avatarCacheKey);
        return;
      }
      if (!mounted) return;
      setState(() {
        avatarBytes = bytes;
      });
    } catch (_) {
      await SecureStorage.delete(_avatarCacheKey);
    }
  }

  Future<String?> _readAccessToken() async {
    return SecureStorage.read('access_token');
  }

  Future<void> _loadAvatarFromServer() async {
    final token = await _readAccessToken();
    if (!mounted || token == null || token.isEmpty) return;

    try {
      final bytes = await ApiService.fetchAvatar(accessToken: token);
      if (!mounted) return;
      if (bytes != null) {
        setState(() {
          avatarBytes = bytes;
        });
        await SecureStorage.write(_avatarCacheKey, base64Encode(bytes));
      } else {
        setState(() {
          avatarBytes = null;
        });
        await SecureStorage.delete(_avatarCacheKey);
      }
    } catch (_) {
      return;
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

  Future<void> _pickAvatarImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: false,
      withData: true,
    );

    if (!mounted) return;

    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null) return;

    final token = await _readAccessToken();
    if (token == null || token.isEmpty) return;

    try {
      await ApiService.uploadAvatar(
        accessToken: token,
        bytes: bytes,
        fileName: file?.name ?? 'avatar',
        mimeType: _guessMimeType(file?.name ?? ''),
      );

      setState(() {
        avatarBytes = bytes;
      });
      await SecureStorage.write(_avatarCacheKey, base64Encode(bytes));
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'HTTP_401' || error.code == 'HTTP_403') {
        await widget.onLogout();
        if (!mounted) return;
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route.isFirst);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLang, 'loginGenericError'))),
      );
    }
  }

  Future<void> _onAvatarMenuSelected(String value) async {
    if (value == 'upload') {
      await _pickAvatarImage();
      return;
    }

    if (value == 'profile') {
      await Navigator.of(context, rootNavigator: true).push(
        _buildFuturisticRoute(
          const RouteSettings(name: '/profile'),
          ProfilePage(
            lang: currentLang,
            isDark: currentIsDark,
            onLangChange: (lang) {
              setState(() => currentLang = lang);
              widget.onLangChange(lang);
            },
            onThemeChange: (isDark) {
              setState(() => currentIsDark = isDark);
              widget.onThemeChange(isDark);
            },
            onLogout: widget.onLogout,
          ),
        ),
      );
      return;
    }

    if (value == 'home') {
      if (!widget.isHomePage) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route.settings.name == '/home' || route.isFirst);
      }
      return;
    }

    if (value == 'achievements') {
      await Navigator.of(context, rootNavigator: true).push(
        _buildFuturisticRoute(
          const RouteSettings(name: '/achievements'),
          AchievementsPage(
            lang: currentLang,
            isDark: currentIsDark,
            onLangChange: (lang) {
              setState(() => currentLang = lang);
              widget.onLangChange(lang);
            },
            onThemeChange: (isDark) {
              setState(() => currentIsDark = isDark);
              widget.onThemeChange(isDark);
            },
            onLogout: widget.onLogout,
          ),
        ),
      );
      return;
    }

    if (value == 'settings') {
      await Navigator.of(context, rootNavigator: true).push(
        _buildFuturisticRoute(
          const RouteSettings(name: '/settings'),
          SettingsPage(
            lang: currentLang,
            isDark: currentIsDark,
            onLangChange: (lang) {
              setState(() => currentLang = lang);
              widget.onLangChange(lang);
            },
            onThemeChange: (isDark) {
              setState(() => currentIsDark = isDark);
              widget.onThemeChange(isDark);
            },
            onLogout: widget.onLogout,
          ),
        ),
      );
      return;
    }

    if (value == 'logout') {
      await widget.onLogout();
      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
      return;
    }

    if (value == 'help') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t(currentLang, 'comingSoon'))));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Widget _buildAvatarMenu() {
    final menuTextColor = currentIsDark ? Colors.white : Colors.black;

    return PopupMenuButton<String>(
      tooltip: '',
      color: currentIsDark ? Colors.grey[900] : Colors.white,
      onSelected: _onAvatarMenuSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'upload',
          child: Text(
            t(currentLang, 'uploadProfilePhoto'),
            style: TextStyle(color: menuTextColor),
          ),
        ),
        PopupMenuItem(
          value: 'home',
          child: Text(
            t(currentLang, 'home'),
            style: TextStyle(color: menuTextColor),
          ),
        ),
        PopupMenuItem(
          value: 'profile',
          child: Text(
            t(currentLang, 'profile'),
            style: TextStyle(color: menuTextColor),
          ),
        ),
        PopupMenuItem(
          value: 'achievements',
          child: Text(
            t(currentLang, 'achievements'),
            style: TextStyle(color: menuTextColor),
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Text(
            t(currentLang, 'settings'),
            style: TextStyle(color: menuTextColor),
          ),
        ),
        PopupMenuItem(
          value: 'help',
          child: Text(
            t(currentLang, 'help'),
            style: TextStyle(color: menuTextColor),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: Text(
            t(currentLang, 'logout'),
            style: TextStyle(color: menuTextColor),
          ),
        ),
      ],
      child: MouseRegion(
        onEnter: (_) => setState(() => isAvatarHovered = true),
        onExit: (_) => setState(() => isAvatarHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          scale: isAvatarHovered ? 1.12 : 1.0,
          child: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            foregroundImage: avatarBytes != null
                ? MemoryImage(avatarBytes!)
                : null,
            onForegroundImageError: avatarBytes != null
                ? (_, _) async {
                    if (!mounted) return;
                    setState(() {
                      avatarBytes = null;
                    });
                    await SecureStorage.delete(_avatarCacheKey);
                  }
                : null,
            child: avatarBytes == null
                ? const Icon(Icons.person, color: Colors.deepPurple, size: 30)
                : null,
          ),
        ),
      ),
    );
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  Future<void> _refreshTopNotifications() async {
    final token = await _readAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _notifications.clear();
        _notificationBadgeCount = 0;
      });
      return;
    }

    try {
      final response = await ApiService.listActivityNotifications(
        accessToken: token,
      );
      final items =
          (response['items'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const <Map<String, dynamic>>[];

      final parsed = <_TopNotificationItem>[];
      for (var index = 0; index < items.length; index += 1) {
        final node = items[index];
        final sentAt = DateTime.tryParse(node['sentAt']?.toString() ?? '');
        final itemId = node['id']?.toString().trim() ?? '';

        parsed.add(
          _TopNotificationItem(
            id: itemId.isNotEmpty ? itemId : 'notification_$index',
            category: _notificationCategoryFromApi(node),
            title:
                node['title']?.toString().trim().isNotEmpty == true
                ? node['title'].toString().trim()
                : _localized('Notificare nouă', 'New notification'),
            description: node['description']?.toString().trim() ?? '',
            sentAt: sentAt ?? DateTime.now(),
            isImportant: _notificationImportantFromApi(node),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _notifications
          ..clear()
          ..addAll(parsed);

        final existingIds = parsed.map((item) => item.id).toSet();
        _seenNotificationIds.removeWhere((id) => !existingIds.contains(id));
        _notificationBadgeCount = parsed
            .where((item) => !_seenNotificationIds.contains(item.id))
            .length;
      });
    } catch (_) {
      return;
    }
  }

  _NotificationCategory _notificationCategoryFromApi(Map<String, dynamic> node) {
    final category = node['category']?.toString().toLowerCase() ?? '';
    final type = node['type']?.toString().toLowerCase() ?? '';
    final iconKey = node['iconKey']?.toString().toLowerCase() ?? '';
    final title = node['title']?.toString().toLowerCase() ?? '';
    final description = node['description']?.toString().toLowerCase() ?? '';
    final text = '$category $type $iconKey $title $description';

    if (text.contains('setari') ||
        text.contains('setări') ||
        text.contains('settings') ||
        text.contains('2fa') ||
        text.contains('security') ||
        text.contains('parola') ||
        text.contains('password')) {
      return _NotificationCategory.settings;
    }

    if (text.contains('comment') || text.contains('coment')) {
      return _NotificationCategory.comment;
    }

    if (text.contains('message') || text.contains('mesaj') || text.contains('chat')) {
      return _NotificationCategory.message;
    }

    if (text.contains('job') ||
        text.contains('post') ||
        text.contains('interview') ||
        text.contains('application')) {
      return _NotificationCategory.jobs;
    }

    return _NotificationCategory.activities;
  }

  bool _notificationImportantFromApi(Map<String, dynamic> node) {
    final type = node['type']?.toString().toLowerCase() ?? '';
    final title = node['title']?.toString().toLowerCase() ?? '';
    final description = node['description']?.toString().toLowerCase() ?? '';
    final iconKey = node['iconKey']?.toString().toLowerCase() ?? '';
    final text = '$type $title $description $iconKey';

    return text.contains('warning') ||
        text.contains('urgent') ||
        text.contains('critical') ||
        text.contains('closing_soon') ||
        text.contains('security');
  }

  String _localized(String ro, String en) {
    return currentLang.toLowerCase() == 'ro' ? ro : en;
  }

  String _twoDigits(int value) {
    return value < 10 ? '0$value' : '$value';
  }

  String _formatNotificationTimestamp(DateTime sentAt) {
    final sent = sentAt.toLocal();
    final reference = _notificationsOpenedAt.toLocal();
    final sentDateOnly = DateTime(sent.year, sent.month, sent.day);
    final referenceDateOnly = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    final dayDiff = referenceDateOnly.difference(sentDateOnly).inDays;
    final time = '${_twoDigits(sent.hour)}:${_twoDigits(sent.minute)}';

    if (dayDiff == 0) {
      return '${_localized('azi', 'today')}, $time';
    }
    if (dayDiff == 1) {
      return '${_localized('ieri', 'yesterday')}, $time';
    }

    return '${_twoDigits(sent.day)}.${_twoDigits(sent.month)}.${sent.year}, $time';
  }

  IconData _notificationIcon(_NotificationCategory category) {
    switch (category) {
      case _NotificationCategory.settings:
        return Icons.settings_outlined;
      case _NotificationCategory.activities:
        return Icons.local_activity_outlined;
      case _NotificationCategory.jobs:
        return Icons.work_outline_rounded;
      case _NotificationCategory.comment:
        return Icons.mode_comment_outlined;
      case _NotificationCategory.message:
        return Icons.mark_chat_unread_outlined;
    }
  }

  Future<void> _openNotificationsPanel() async {
    await _refreshTopNotifications();
    if (!mounted) return;

    setState(() {
      _notificationsOpenedAt = DateTime.now();
      _hoveredNotificationId = null;
      _seenNotificationIds.addAll(_notifications.map((item) => item.id));
      _notificationBadgeCount = 0;
    });

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'notifications',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, __) => _buildNotificationsPanel(context),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      routeSettings: const RouteSettings(name: '/notifications-panel'),
    );
  }

  Widget _buildNotificationsPanel(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 720;
    final important = _notifications.where((item) => item.isImportant).toList();
    final others = _notifications.where((item) => !item.isImportant).toList();

    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context, rootNavigator: true).pop(),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: isMobile
                    ? math.min(MediaQuery.of(context).size.width - 24, 430)
                    : 430,
                constraints: const BoxConstraints(maxHeight: 620),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF23242B)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.32),
                      blurRadius: 26,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t(currentLang, 'notifications'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '',
                            onPressed: () =>
                                Navigator.of(context, rootNavigator: true).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (important.isEmpty && others.isEmpty)
                              Container(
                                margin: const EdgeInsets.fromLTRB(6, 8, 6, 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 22,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: theme.brightness == Brightness.dark
                                        ? 0.1
                                        : 0.04,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.notifications_none_rounded,
                                      size: 28,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _localized(
                                        'Nu ai notificări momentan',
                                        'No notifications for now',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _localized(
                                        'Când apar notificări noi, le vei vedea aici.',
                                        'When new notifications arrive, you will see them here.',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (important.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                                child: Text(
                                  _localized('Important', 'Important'),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ),
                              ...important.map(
                                (item) => _buildNotificationTile(context, item),
                              ),
                            ],
                            if (others.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
                                child: Text(
                                  _localized(
                                    'Mai multe notificări',
                                    'More notifications',
                                  ),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ),
                              ...others.map(
                                (item) => _buildNotificationTile(context, item),
                              ),
                            ],
                          ],
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
  }

  Widget _buildNotificationTile(BuildContext context, _TopNotificationItem item) {
    final theme = Theme.of(context);
    final isHovered = _hoveredNotificationId == item.id;
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.64);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredNotificationId = item.id),
      onExit: (_) => setState(() => _hoveredNotificationId = null),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        scale: isHovered ? 1.015 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.12 : 0.04,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onNotificationTap(item),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(
                      _notificationIcon(item.category),
                      size: 19,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatNotificationTimestamp(item.sentAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onNotificationTap(_TopNotificationItem item) async {
    Navigator.of(context, rootNavigator: true).pop();

    switch (item.category) {
      case _NotificationCategory.settings:
        await Navigator.of(context, rootNavigator: true).push(
          _buildFuturisticRoute(
            const RouteSettings(name: '/settings'),
            SettingsPage(
              lang: currentLang,
              isDark: currentIsDark,
              onLangChange: (lang) {
                setState(() => currentLang = lang);
                widget.onLangChange(lang);
              },
              onThemeChange: (isDark) {
                setState(() => currentIsDark = isDark);
                widget.onThemeChange(isDark);
              },
              onLogout: widget.onLogout,
            ),
          ),
        );
        return;
      case _NotificationCategory.activities:
      case _NotificationCategory.jobs:
      case _NotificationCategory.comment:
      case _NotificationCategory.message:
        _showTopActionSoon();
        return;
    }
  }

  void _showTopActionSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t(currentLang, 'comingSoon'))));
  }

  Future<void> _handleTopSearchAction(String query, String scope) async {
    if (scope != 'profiles') {
      _showTopActionSoon();
      return;
    }

    await Navigator.of(context, rootNavigator: true).push(
      _buildFuturisticRoute(
        const RouteSettings(name: '/search/profiles'),
        ProfileSearchPage(
          lang: currentLang,
          isDark: currentIsDark,
          onLangChange: (lang) {
            setState(() => currentLang = lang);
            widget.onLangChange(lang);
          },
          onThemeChange: (isDark) {
            setState(() => currentIsDark = isDark);
            widget.onThemeChange(isDark);
          },
          onLogout: widget.onLogout,
          initialQuery: query,
        ),
      ),
    );
  }

  PageRouteBuilder<void> _buildFuturisticRoute(
    RouteSettings settings,
    Widget page,
  ) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);

        final fade = Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)).animate(animation);

        final scale = Tween<double>(
          begin: 0.985,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(scale: scale, child: child),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageBackground = currentIsDark ? Colors.grey[900]! : Colors.white;

    return Scaffold(
      backgroundColor: pageBackground,
      body: Column(
        children: [
          TopBarWidget(
            lang: currentLang,
            isDark: currentIsDark,
            onLangChange: (lang) {
              setState(() => currentLang = lang);
              widget.onLangChange(lang);
            },
            onThemeChange: (isDark) {
              setState(() => currentIsDark = isDark);
              widget.onThemeChange(isDark);
            },
            authenticatedLayout: true,
            onMessagesTap: _showTopActionSoon,
            onNotificationsTap: _openNotificationsPanel,
            onSearchAction: _handleTopSearchAction,
            notificationBadgeCount: _notificationBadgeCount,
            trailingRight: _buildAvatarMenu(),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: pageBackground,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
