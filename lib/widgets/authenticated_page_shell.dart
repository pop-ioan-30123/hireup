import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'top_bar.dart';
import '../core/texts.dart';
import '../pages/achievements_page.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';
import '../services/api_service.dart';
import '../services/secure_storage.dart';

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

  late String currentLang;
  late bool currentIsDark;

  @override
  void initState() {
    super.initState();
    currentLang = widget.lang;
    currentIsDark = widget.isDark;
    _loadAvatarFromCache();
    _loadAvatarFromServer();
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
