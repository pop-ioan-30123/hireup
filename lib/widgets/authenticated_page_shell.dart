import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'top_bar.dart';
import '../core/texts.dart';
import '../pages/achievements_page.dart';
import '../pages/profile_page.dart';
import '../pages/profile_search_page.dart';
import '../pages/settings_page.dart';
import '../services/api_service.dart';
import '../services/secure_storage.dart';

enum _NotificationCategory { settings, activities, jobs, comment, message }

enum _SocialNotificationType {
  followReceived,
  followSent,
  unfollowReceived,
  unfollowSent,
  contactCreated,
  contactRemoved,
}

enum _MessagesPanelTab { messages, requests }

class _TopNotificationItem {
  _TopNotificationItem({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.sentAt,
    required this.isImportant,
    required this.isRead,
  });

  final String id;
  final _NotificationCategory category;
  final String title;
  final String description;
  final DateTime sentAt;
  final bool isImportant;
  final bool isRead;
}

class _SocialNotificationItem {
  const _SocialNotificationItem({
    required this.id,
    required this.actorUserId,
    required this.actorFullName,
    required this.type,
    required this.imageKey,
    required this.sentAt,
    required this.isRead,
  });

  final String id;
  final String actorUserId;
  final String actorFullName;
  final _SocialNotificationType type;
  final String imageKey;
  final DateTime sentAt;
  final bool isRead;
}

class _MessageConversationItem {
  const _MessageConversationItem({
    required this.id,
    required this.title,
    required this.unreadCount,
    required this.lastMessageAt,
    required this.lastMessagePreview,
    required this.lastMessageSenderUserId,
    required this.participants,
    required this.requestStatus,
  });

  final String id;
  final String title;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageSenderUserId;
  final List<Map<String, dynamic>> participants;
  final String requestStatus;
}

class _MessageEntryItem {
  const _MessageEntryItem({
    required this.id,
    required this.senderUserId,
    required this.messageKind,
    required this.ciphertext,
    required this.createdAt,
    required this.deliveredAt,
    required this.readAt,
    required this.editedAt,
    required this.metadata,
  });

  final String id;
  final String senderUserId;
  final String messageKind;
  final String ciphertext;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? editedAt;
  final Map<String, dynamic> metadata;

  bool get isSystem => messageKind == 'system';

  Map<String, String> get reactions {
    final raw = metadata['reactions'];
    if (raw is! Map) return const <String, String>{};

    final result = <String, String>{};
    raw.forEach((key, value) {
      final normalizedKey = key.toString().trim();
      final normalizedValue = value?.toString().trim() ?? '';
      if (normalizedKey.isNotEmpty && normalizedValue.isNotEmpty) {
        result[normalizedKey] = normalizedValue;
      }
    });
    return result;
  }
}

class AuthenticatedPageShell extends StatefulWidget {
  static final StreamController<String> _conversationRequestController =
      StreamController<String>.broadcast();

  static void requestOpenConversation(String conversationId) {
    if (conversationId.trim().isEmpty) return;
    _conversationRequestController.add(conversationId);
  }

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
  final List<_SocialNotificationItem> _socialNotifications =
      <_SocialNotificationItem>[];

  int _notificationBadgeCount = 0;
  int _socialBadgeCount = 0;
  DateTime _notificationsOpenedAt = DateTime.now();
  DateTime _socialOpenedAt = DateTime.now();
  Rect? _messagesButtonRect;
  Rect? _socialButtonRect;
  Rect? _notificationsButtonRect;
  String? _hoveredNotificationId;
  String? _hoveredSocialNotificationId;

  final List<_MessageConversationItem> _conversations =
      <_MessageConversationItem>[];
  final Set<String> _contactUserIds = <String>{};
  final Map<String, List<_MessageEntryItem>> _messagesByConversation =
      <String, List<_MessageEntryItem>>{};
  final Map<String, Uint8List?> _participantAvatarByUserId =
      <String, Uint8List?>{};
  final Set<String> _participantAvatarLoadingUserIds = <String>{};
  final TextEditingController _chatComposerCtrl = TextEditingController();

  String? _currentUserId;
  String? _activeConversationId;
  bool _messagesPopupOpen = false;
  bool _messagesPopupMinimized = false;
  bool _messagesPanelLoading = false;
  bool _messagesSending = false;
  _MessagesPanelTab _messagesPanelTab = _MessagesPanelTab.messages;
  String? _messagesError;
  String? _expandedMessageDetailsId;
  final List<String> _floatingConversationIds = <String>[];

  static const int _maxFloatingConversations = 5;

  double _chatBubbleLeft = 18;
  double _chatBubbleTop = 120;

  late String currentLang;
  late bool currentIsDark;
  Timer? _messagesTicker;
  StreamSubscription<String>? _conversationRequestSubscription;

  @override
  void initState() {
    super.initState();
    currentLang = widget.lang;
    currentIsDark = widget.isDark;
    _loadAvatarFromCache();
    _loadAvatarFromServer();
    _refreshTopNotifications();
    _refreshSocialNotifications();
    _resolveCurrentUserId();
    _refreshConversations();
    _conversationRequestSubscription = AuthenticatedPageShell
        ._conversationRequestController
        .stream
        .listen((id) {
          if (!mounted) return;
          unawaited(_openMessagesPopup(conversationId: id));
        });
    _messagesTicker = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      _refreshConversations(silent: true);
      unawaited(_refreshTopNotifications());
      unawaited(_refreshSocialNotifications());
    });
  }

  @override
  void dispose() {
    _messagesTicker?.cancel();
    _conversationRequestSubscription?.cancel();
    _chatComposerCtrl.dispose();
    super.dispose();
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

  Future<void> _resolveCurrentUserId() async {
    final token = await _readAccessToken();
    if (token == null || token.isEmpty) return;

    final parts = token.split('.');
    if (parts.length < 2) return;

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payloadText = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadText);
      if (payload is! Map<String, dynamic>) return;

      final userId = payload['sub']?.toString();
      if (!mounted || userId == null || userId.isEmpty) return;
      setState(() => _currentUserId = userId);
    } catch (_) {
      return;
    }
  }

  Future<void> _refreshConversations({bool silent = false}) async {
    final token = await _readAccessToken();
    if (token == null || token.isEmpty) return;

    if (!silent && mounted) {
      setState(() {
        _messagesPanelLoading = true;
        _messagesError = null;
      });
    }

    try {
      final response = await ApiService.listMessageConversations(
        accessToken: token,
      );

      final items = (response['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      final parsed = items.map(_conversationFromApi).toList(growable: false)
        ..sort((a, b) {
          final aTime =
              a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime =
              b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

      if (!mounted) return;
      setState(() {
        _conversations
          ..clear()
          ..addAll(parsed);
        _activeConversationId =
            _activeConversationId ??
            (parsed.isNotEmpty ? parsed.first.id : null);
      });
      unawaited(_refreshContactUsers());
      unawaited(_preloadParticipantAvatars(parsed));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _messagesError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _messagesError = _localized('Eroare la chat.', 'Chat load failed.'),
      );
    } finally {
      if (!silent && mounted) {
        setState(() => _messagesPanelLoading = false);
      }
    }
  }

  Future<void> _refreshContactUsers() async {
    final token = await _readAccessToken();
    if (token == null || token.isEmpty) return;

    try {
      final response = await ApiService.listContacts(accessToken: token);
      final items = (response['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      final parsed = <String>{};
      for (final item in items) {
        final userId = item['userId']?.toString().trim() ?? '';
        if (userId.isNotEmpty) {
          parsed.add(userId);
        }
      }

      if (!mounted) return;
      setState(() {
        _contactUserIds
          ..clear()
          ..addAll(parsed);
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _preloadParticipantAvatars(
    List<_MessageConversationItem> conversations,
  ) async {
    final token = await _readAccessToken();
    if (token == null || token.isEmpty) return;

    final userIds = <String>{};
    for (final conversation in conversations) {
      for (final participant in conversation.participants) {
        final userId = participant['userId']?.toString().trim() ?? '';
        if (userId.isEmpty || userId == _currentUserId) continue;
        userIds.add(userId);
      }
    }

    for (final userId in userIds) {
      if (_participantAvatarByUserId.containsKey(userId) ||
          _participantAvatarLoadingUserIds.contains(userId)) {
        continue;
      }
      _participantAvatarLoadingUserIds.add(userId);
      try {
        final bytes = await ApiService.fetchUserAvatar(
          accessToken: token,
          userId: userId,
        );
        if (!mounted) return;
        setState(() {
          _participantAvatarByUserId[userId] = bytes;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _participantAvatarByUserId[userId] = null;
        });
      } finally {
        _participantAvatarLoadingUserIds.remove(userId);
      }
    }
  }

  _MessageConversationItem _conversationFromApi(Map<String, dynamic> node) {
    final participants =
        (node['participants'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);

    final titleRaw = node['title']?.toString().trim() ?? '';
    String title = titleRaw;

    if (title.isEmpty) {
      final others = participants
          .where((participant) {
            final userId = participant['userId']?.toString();
            return userId != null && userId != _currentUserId;
          })
          .toList(growable: false);

      if (others.isNotEmpty) {
        title =
            others.first['fullName']?.toString().trim() ??
            others.first['email']?.toString().trim() ??
            _localized('Conversație', 'Conversation');
      } else {
        title = _localized('Conversație', 'Conversation');
      }
    }

    return _MessageConversationItem(
      id: node['id']?.toString() ?? '',
      title: title,
      unreadCount: (node['unreadCount'] as num?)?.toInt() ?? 0,
      lastMessageAt: DateTime.tryParse(node['lastMessageAt']?.toString() ?? ''),
      lastMessagePreview: node['lastMessagePreview']?.toString(),
      lastMessageSenderUserId: node['lastMessageSenderUserId']?.toString(),
      participants: participants,
      requestStatus: node['requestStatus']?.toString() ?? 'active',
    );
  }

  Future<void> _loadConversationMessages(
    String conversationId, {
    bool silent = false,
  }) async {
    final token = await _readAccessToken();
    if (token == null || token.isEmpty) return;

    if (!silent && mounted) {
      setState(() {
        _messagesPanelLoading = true;
        _messagesError = null;
      });
    }

    try {
      final response = await ApiService.listConversationMessages(
        accessToken: token,
        conversationId: conversationId,
        limit: 70,
      );
      final items =
          (response['items'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => _MessageEntryItem(
                  id: item['id']?.toString() ?? '',
                  senderUserId: item['senderUserId']?.toString() ?? '',
                  messageKind: item['messageKind']?.toString() ?? 'text',
                  ciphertext: item['ciphertext']?.toString() ?? '',
                  createdAt:
                      DateTime.tryParse(item['createdAt']?.toString() ?? '') ??
                      DateTime.now(),
                  deliveredAt: DateTime.tryParse(
                    item['deliveredAt']?.toString() ?? '',
                  ),
                  readAt: DateTime.tryParse(item['readAt']?.toString() ?? ''),
                  editedAt: DateTime.tryParse(
                    item['editedAt']?.toString() ?? '',
                  ),
                  metadata:
                      (item['metadata'] as Map?)?.map(
                        (key, value) => MapEntry(key.toString(), value),
                      ) ??
                      const <String, dynamic>{},
                ),
              )
              .toList(growable: false)
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      await ApiService.markConversationRead(
        accessToken: token,
        conversationId: conversationId,
      );

      if (!mounted) return;
      setState(() {
        _messagesByConversation[conversationId] = items;
      });
      await _refreshConversations(silent: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _messagesError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _messagesError = _localized(
          'Nu pot încărca mesajele.',
          'Could not load messages.',
        ),
      );
    } finally {
      if (!silent && mounted) {
        setState(() => _messagesPanelLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatComposerCtrl.text.trim();
    final conversationId = _activeConversationId;
    if (text.isEmpty || conversationId == null) return;

    final token = await _readAccessToken();
    if (token == null || token.isEmpty) return;

    setState(() => _messagesSending = true);
    try {
      await ApiService.sendConversationMessage(
        accessToken: token,
        conversationId: conversationId,
        ciphertext: text,
      );

      _chatComposerCtrl.clear();
      await _loadConversationMessages(conversationId, silent: true);
      await _refreshConversations(silent: true);

      if (!mounted) return;
      setState(() => _messagesError = null);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _messagesError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _messagesError = _localized(
          'Mesajul nu a fost trimis.',
          'Message send failed.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _messagesSending = false);
      }
    }
  }

  void _toggleMessagesMinimized() {
    if (!_messagesPopupOpen) return;
    setState(() => _messagesPopupMinimized = !_messagesPopupMinimized);
  }

  void _toggleMessageDetails(String messageId) {
    setState(() {
      _expandedMessageDetailsId = _expandedMessageDetailsId == messageId
          ? null
          : messageId;
    });
  }

  Map<String, dynamic>? get _activeConversationPeer {
    final conversation = _activeConversation;
    if (conversation == null) return null;
    for (final participant in conversation.participants) {
      final userId = participant['userId']?.toString();
      if (userId != null && userId != _currentUserId) {
        return participant;
      }
    }
    return null;
  }

  String? get _activeConversationPeerUserId {
    final peer = _activeConversationPeer;
    final userId = peer?['userId']?.toString().trim();
    if (userId == null || userId.isEmpty) return null;
    return userId;
  }

  String get _activeConversationPeerName {
    final peer = _activeConversationPeer;
    final fullName = peer?['fullName']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) return fullName;
    final email = peer?['email']?.toString().trim() ?? '';
    if (email.isNotEmpty) return email;
    return _activeConversation?.title ??
        _localized('Conversație', 'Conversation');
  }

  bool _isContactConversation(_MessageConversationItem conversation) {
    for (final participant in conversation.participants) {
      final userId = participant['userId']?.toString().trim() ?? '';
      if (userId.isEmpty || userId == _currentUserId) continue;
      return _contactUserIds.contains(userId);
    }
    return false;
  }

  bool _isMessageRequestConversation(_MessageConversationItem conversation) {
    return conversation.requestStatus == 'request';
  }

  bool get _activeConversationIsContact {
    final conversation = _activeConversation;
    if (conversation == null) return false;
    return _isContactConversation(conversation);
  }

  bool get _activeConversationAllowsOpenReply {
    final conversation = _activeConversation;
    if (conversation == null) return false;
    return conversation.requestStatus != 'request';
  }

  String get _currentUserChatLabel => _localized('Eu', 'Me');

  Uint8List? _participantAvatar(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    return _participantAvatarByUserId[userId];
  }

  int get _messagesBadgeCount {
    return _conversations
        .where((conversation) => conversation.unreadCount > 0)
        .length;
  }

  Map<String, dynamic>? _peerParticipant(
    _MessageConversationItem conversation,
  ) {
    for (final participant in conversation.participants) {
      final userId = participant['userId']?.toString();
      if (userId != null && userId != _currentUserId) {
        return participant;
      }
    }
    return null;
  }

  String _participantDisplayNameForConversation(
    _MessageConversationItem conversation,
    String userId,
  ) {
    for (final participant in conversation.participants) {
      if (participant['userId']?.toString() != userId) continue;
      final fullName = participant['fullName']?.toString().trim() ?? '';
      if (fullName.isNotEmpty) return fullName;
      final email = participant['email']?.toString().trim() ?? '';
      if (email.isNotEmpty) return email;
    }
    return _localized('Utilizator', 'User');
  }

  String _conversationPreviewText(_MessageConversationItem conversation) {
    final preview = conversation.lastMessagePreview?.trim() ?? '';
    if (preview.isEmpty) {
      return _conversationSubtitle(conversation);
    }

    final senderUserId = conversation.lastMessageSenderUserId?.trim();
    if (senderUserId == null || senderUserId.isEmpty) {
      return preview;
    }

    final sender = senderUserId == _currentUserId
        ? _localized('Tu', 'You')
        : _participantDisplayNameForConversation(conversation, senderUserId);
    return '$sender: $preview';
  }

  Uint8List? _conversationPreviewAvatar(_MessageConversationItem conversation) {
    final senderUserId = conversation.lastMessageSenderUserId?.trim();
    if (senderUserId != null && senderUserId.isNotEmpty) {
      if (senderUserId == _currentUserId) {
        return avatarBytes;
      }
      return _participantAvatar(senderUserId);
    }

    final peer = _peerParticipant(conversation);
    final peerUserId = peer?['userId']?.toString().trim();
    if (peerUserId == null || peerUserId.isEmpty) return null;
    return _participantAvatar(peerUserId);
  }

  String _conversationPreviewAvatarLabel(
    _MessageConversationItem conversation,
  ) {
    final senderUserId = conversation.lastMessageSenderUserId?.trim();
    if (senderUserId != null && senderUserId.isNotEmpty) {
      if (senderUserId == _currentUserId) {
        return _localized('Eu', 'Me');
      }
      return _participantDisplayNameForConversation(conversation, senderUserId);
    }

    final peer = _peerParticipant(conversation);
    final fullName = peer?['fullName']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) return fullName;
    final email = peer?['email']?.toString().trim() ?? '';
    if (email.isNotEmpty) return email;
    return conversation.title;
  }

  bool _canEditMessage(_MessageEntryItem entry) {
    if (_currentUserId == null || entry.senderUserId != _currentUserId) {
      return false;
    }
    return DateTime.now().difference(entry.createdAt) <=
        const Duration(minutes: 30);
  }

  String _twoInitials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  Widget _buildChatAvatar({
    required String label,
    Uint8List? bytes,
    double radius = 18,
    Color? background,
  }) {
    final bg = background ?? Theme.of(context).colorScheme.primary;
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg.withValues(alpha: 0.18),
      foregroundImage: bytes != null ? MemoryImage(bytes) : null,
      child: bytes == null
          ? Text(
              _twoInitials(label),
              style: TextStyle(
                color: bg,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.72,
              ),
            )
          : null,
    );
  }

  List<String> _messageDetailsLines(_MessageEntryItem entry) {
    final lines = <String>[];
    if (entry.deliveredAt != null) {
      lines.add(
        '${_localized('Delivered at', 'Delivered at')} ${_formatChatDateTime(entry.deliveredAt!)}',
      );
    } else {
      lines.add(_localized('Delivered pending', 'Delivered pending'));
    }

    if (entry.readAt != null) {
      lines.add(
        '${_localized('Read at', 'Read at')} ${_formatChatDateTime(entry.readAt!)}',
      );
    } else {
      lines.add(_localized('Unread', 'Unread'));
    }

    if (entry.editedAt != null) {
      lines.add(
        '${_localized('Edited at', 'Edited at')} ${_formatChatDateTime(entry.editedAt!)}',
      );
    }

    return lines;
  }

  String _formatChatDateTime(DateTime date) {
    final local = date.toLocal();
    return '${_twoDigits(local.day)}.${_twoDigits(local.month)}.${local.year} ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  Future<void> _copyMessageText(_MessageEntryItem entry) async {
    await Clipboard.setData(ClipboardData(text: entry.ciphertext));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_localized('Text copiat.', 'Text copied.'))),
    );
  }

  Future<void> _reactToMessage(_MessageEntryItem entry) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) {
        const emojis = ['👍', '❤️', '😂', '🔥', '👏', '😮'];
        return AlertDialog(
          title: Text(_localized('Reacționează', 'React')),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: emojis
                .map(
                  (emoji) => InkWell(
                    onTap: () => Navigator.of(context).pop(emoji),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );

    if (picked == null) return;
    final token = await _readAccessToken();
    final conversationId = _activeConversationId;
    if (token == null || token.isEmpty || conversationId == null) return;

    try {
      await ApiService.reactToConversationMessage(
        accessToken: token,
        conversationId: conversationId,
        messageId: entry.id,
        emoji: picked,
      );
      await _loadConversationMessages(conversationId, silent: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _messagesError = error.message);
    }
  }

  Future<void> _editMessage(_MessageEntryItem entry) async {
    if (!_canEditMessage(entry)) return;

    final controller = TextEditingController(text: entry.ciphertext);
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_localized('Editează mesajul', 'Edit message')),
        content: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 5,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_localized('Anulează', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_localized('Salvează', 'Save')),
          ),
        ],
      ),
    );

    if (approved != true) {
      controller.dispose();
      return;
    }

    final token = await _readAccessToken();
    final conversationId = _activeConversationId;
    final text = controller.text.trim();
    controller.dispose();
    if (token == null ||
        token.isEmpty ||
        conversationId == null ||
        text.isEmpty) {
      return;
    }

    try {
      await ApiService.updateConversationMessage(
        accessToken: token,
        conversationId: conversationId,
        messageId: entry.id,
        ciphertext: text,
      );
      await _loadConversationMessages(conversationId, silent: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _messagesError = error.message);
    }
  }

  Future<void> _deleteMessage(
    _MessageEntryItem entry, {
    required bool forEveryone,
  }) async {
    final token = await _readAccessToken();
    final conversationId = _activeConversationId;
    if (token == null || token.isEmpty || conversationId == null) return;

    try {
      await ApiService.deleteConversationMessage(
        accessToken: token,
        conversationId: conversationId,
        messageId: entry.id,
        scope: forEveryone ? 'everyone' : 'me',
      );
      await _loadConversationMessages(conversationId, silent: true);
      await _refreshConversations(silent: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _messagesError = error.message);
    }
  }

  Future<void> _showMessageContextMenu(
    TapDownDetails details,
    _MessageEntryItem entry,
  ) async {
    final mine = _currentUserId != null && entry.senderUserId == _currentUserId;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Text(_localized('Copiază textul', 'Copy text')),
        ),
        PopupMenuItem<String>(
          value: 'react',
          child: Text(_localized('Reacționează', 'React')),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          enabled: _canEditMessage(entry),
          child: Text(_localized('Editează', 'Edit')),
        ),
        PopupMenuItem<String>(
          value: 'delete_mine',
          child: Text(_localized('Șterge pentru mine', 'Delete for me')),
        ),
        PopupMenuItem<String>(
          value: 'delete_everyone',
          enabled: mine,
          child: Text(_localized('Șterge pentru toți', 'Delete for everyone')),
        ),
      ],
    );

    switch (selected) {
      case 'copy':
        await _copyMessageText(entry);
        return;
      case 'react':
        await _reactToMessage(entry);
        return;
      case 'edit':
        await _editMessage(entry);
        return;
      case 'delete_mine':
        await _deleteMessage(entry, forEveryone: false);
        return;
      case 'delete_everyone':
        await _deleteMessage(entry, forEveryone: true);
        return;
      default:
        return;
    }
  }

  Widget _buildReactionStrip(_MessageEntryItem entry) {
    final reactions = entry.reactions.values.toList(growable: false);
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: reactions
            .map(
              (emoji) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(emoji),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildMinimizedChatBubble() {
    final peerName = _activeConversationPeerName;
    final peerAvatar = _participantAvatar(_activeConversationPeerUserId);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: currentIsDark ? const Color(0xFF1F222D) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChatAvatar(label: peerName, bytes: peerAvatar, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_activeConversationIsContact)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _localized('Contact', 'Contact'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _localized('Contact', 'Contact'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFF2E7D32),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildRequestReplyHintBanner() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF9A825).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF9A825).withValues(alpha: 0.38),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFB08900),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _localized(
                'Daca raspunzi acestei conversatii, va veti putea trimite mesaj fara a fi contacte.',
                'If you reply to this conversation, you will be able to message each other without being contacts.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF7A5B00),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _participantDisplayName(String userId) {
    final conversation = _activeConversation;
    if (conversation == null) return _localized('Utilizator', 'User');

    for (final item in conversation.participants) {
      if (item['userId']?.toString() != userId) continue;
      final fullName = item['fullName']?.toString().trim() ?? '';
      if (fullName.isNotEmpty) return fullName;
      final email = item['email']?.toString().trim() ?? '';
      if (email.isNotEmpty) return email;
    }
    return _localized('Utilizator', 'User');
  }

  _MessageEntryItem _conversationSecuritySystemMessage(String conversationId) {
    return _MessageEntryItem(
      id: 'system-security-$conversationId',
      senderUserId: 'system',
      messageKind: 'system',
      ciphertext:
          'Mesajele sunt strict confidențiale și conversația este criptată end-to-end.',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      deliveredAt: null,
      readAt: null,
      editedAt: null,
      metadata: const <String, dynamic>{},
    );
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
            title: node['title']?.toString().trim().isNotEmpty == true
                ? node['title'].toString().trim()
                : _localized('Notificare nouă', 'New notification'),
            description: node['description']?.toString().trim() ?? '',
            sentAt: sentAt ?? DateTime.now(),
            isImportant: _notificationImportantFromApi(node),
            isRead: node['isRead'] == true,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _notifications
          ..clear()
          ..addAll(parsed);
        _notificationBadgeCount = parsed.where((item) => !item.isRead).length;
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _refreshSocialNotifications() async {
    final token = await _readAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _socialNotifications.clear();
        _socialBadgeCount = 0;
      });
      return;
    }

    try {
      final response = await ApiService.listSocialNotifications(
        accessToken: token,
      );
      final items = (response['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      final parsed = items
          .map((node) {
            final rawType = node['type']?.toString().toLowerCase() ?? '';
            final type = switch (rawType) {
              'follow_sent' => _SocialNotificationType.followSent,
              'unfollow_received' => _SocialNotificationType.unfollowReceived,
              'unfollow_sent' => _SocialNotificationType.unfollowSent,
              'contact' => _SocialNotificationType.contactCreated,
              'contact_created' => _SocialNotificationType.contactCreated,
              'contact_removed' => _SocialNotificationType.contactRemoved,
              'unfollow' => _SocialNotificationType.unfollowReceived,
              'follow' => _SocialNotificationType.followReceived,
              _ => _SocialNotificationType.followReceived,
            };

            return _SocialNotificationItem(
              id: node['id']?.toString() ?? '',
              actorUserId: node['actorUserId']?.toString() ?? '',
              actorFullName:
                  node['actorFullName']?.toString().trim().isNotEmpty == true
                  ? node['actorFullName'].toString().trim()
                  : _localized('Utilizator', 'User'),
              type: type,
              imageKey: node['imageKey']?.toString() ?? rawType,
              sentAt:
                  DateTime.tryParse(node['sentAt']?.toString() ?? '') ??
                  DateTime.now(),
              isRead: node['isRead'] == true,
            );
          })
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _socialNotifications
          ..clear()
          ..addAll(parsed);
        _socialBadgeCount = parsed.where((item) => !item.isRead).length;
      });
      unawaited(_preloadSocialNotificationAvatars(parsed));
    } catch (_) {
      return;
    }
  }

  Future<void> _preloadSocialNotificationAvatars(
    List<_SocialNotificationItem> notifications,
  ) async {
    final token = await _readAccessToken();
    if (token == null || token.isEmpty) return;

    final userIds = notifications
        .map((item) => item.actorUserId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final userId in userIds) {
      if (_participantAvatarByUserId.containsKey(userId) ||
          _participantAvatarLoadingUserIds.contains(userId)) {
        continue;
      }

      _participantAvatarLoadingUserIds.add(userId);
      try {
        final bytes = await ApiService.fetchUserAvatar(
          accessToken: token,
          userId: userId,
        );
        if (!mounted) return;
        setState(() {
          _participantAvatarByUserId[userId] = bytes;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _participantAvatarByUserId[userId] = null;
        });
      } finally {
        _participantAvatarLoadingUserIds.remove(userId);
      }
    }
  }

  _NotificationCategory _notificationCategoryFromApi(
    Map<String, dynamic> node,
  ) {
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

    if (text.contains('message') ||
        text.contains('mesaj') ||
        text.contains('chat')) {
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
    return _isRomanianLanguage ? ro : en;
  }

  bool get _isRomanianLanguage => currentLang.toLowerCase().startsWith('ro');

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

  Future<void> _openNotificationsPanel({Rect? anchorRect}) async {
    _notificationsButtonRect = anchorRect ?? _notificationsButtonRect;
    await _refreshTopNotifications();
    if (_notifications.any((item) => !item.isRead)) {
      final token = await _readAccessToken();
      if (token != null && token.isNotEmpty) {
        try {
          await ApiService.markAllActivityNotificationsRead(accessToken: token);
          await _refreshTopNotifications();
        } catch (_) {}
      }
    }
    if (!mounted) return;

    setState(() {
      _notificationsOpenedAt = DateTime.now();
      _hoveredNotificationId = null;
      _notificationBadgeCount = _notifications
          .where((item) => !item.isRead)
          .length;
    });

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'notifications',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, _) => _buildNotificationsPanel(context),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
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

  Future<void> _openSocialPanel({Rect? anchorRect}) async {
    _socialButtonRect = anchorRect ?? _socialButtonRect;
    await _refreshSocialNotifications();
    if (_socialNotifications.any((item) => !item.isRead)) {
      final token = await _readAccessToken();
      if (token != null && token.isNotEmpty) {
        try {
          await ApiService.markAllSocialNotificationsRead(accessToken: token);
          await _refreshSocialNotifications();
        } catch (_) {}
      }
    }
    if (!mounted) return;

    setState(() {
      _socialOpenedAt = DateTime.now();
      _hoveredSocialNotificationId = null;
      _socialBadgeCount = _socialNotifications
          .where((item) => !item.isRead)
          .length;
    });

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'social-notifications',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, _) => _buildSocialPanel(context),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      routeSettings: const RouteSettings(name: '/social-panel'),
    );
  }

  Widget _buildNotificationsPanel(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 720;
    final important = _notifications.where((item) => item.isImportant).toList();
    final others = _notifications.where((item) => !item.isImportant).toList();
    final panelWidth = isMobile
        ? math.min(media.size.width - 24.0, 430.0)
        : 430.0;
    final panelMaxHeight = media.size.height - 24;
    final panelPosition = _resolveTopBarAnchoredPosition(
      media: media,
      panelWidth: panelWidth,
      panelHeight: panelMaxHeight,
      anchorRect: _notificationsButtonRect,
    );

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
            top: panelPosition.dy,
            left: panelPosition.dx,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: panelWidth,
                constraints: BoxConstraints(maxHeight: panelMaxHeight),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF23242B)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        t(currentLang, 'notifications'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
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
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
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
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.8),
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
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.8),
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

  Widget _buildSocialPanel(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 720;
    final panelWidth = isMobile
        ? math.min(media.size.width - 24.0, 430.0)
        : 430.0;
    const panelMaxHeight = 620.0;
    final panelPosition = _resolveTopBarAnchoredPosition(
      media: media,
      panelWidth: panelWidth,
      panelHeight: panelMaxHeight,
      anchorRect: _socialButtonRect,
    );

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
            top: panelPosition.dy,
            left: panelPosition.dx,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: panelWidth,
                constraints: const BoxConstraints(maxHeight: 620),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF23242B)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        t(currentLang, 'socialPanelTitle'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_socialNotifications.isEmpty)
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
                                      Icons.groups_rounded,
                                      size: 28,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      t(currentLang, 'socialPanelEmptyTitle'),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t(currentLang, 'socialPanelEmptyDescription'),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.7),
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ..._socialNotifications.map(
                                (item) =>
                                    _buildSocialNotificationTile(context, item),
                              ),
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

  Widget _buildNotificationTile(
    BuildContext context,
    _TopNotificationItem item,
  ) {
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

  Widget _buildSocialNotificationTile(
    BuildContext context,
    _SocialNotificationItem item,
  ) {
    final theme = Theme.of(context);
    final isHovered = _hoveredSocialNotificationId == item.id;
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.64);
    final accent = switch (item.type) {
      _SocialNotificationType.followReceived => const Color(0xFF1565C0),
      _SocialNotificationType.followSent => const Color(0xFF0D47A1),
      _SocialNotificationType.unfollowReceived => const Color(0xFFC62828),
      _SocialNotificationType.unfollowSent => const Color(0xFFB71C1C),
      _SocialNotificationType.contactCreated => const Color(0xFF2E7D32),
      _SocialNotificationType.contactRemoved => const Color(0xFF6D4C41),
    };
    final icon = switch (item.type) {
      _SocialNotificationType.followReceived => Icons.person_add_alt_1_rounded,
      _SocialNotificationType.followSent => Icons.outbound_rounded,
      _SocialNotificationType.unfollowReceived => Icons.person_remove_alt_1_rounded,
      _SocialNotificationType.unfollowSent => Icons.logout_rounded,
      _SocialNotificationType.contactCreated => Icons.handshake_outlined,
      _SocialNotificationType.contactRemoved => Icons.link_off_rounded,
    };
    final title = switch (item.type) {
      _SocialNotificationType.followReceived => _localized(
        '${item.actorFullName} te urmărește',
        '${item.actorFullName} followed you',
      ),
      _SocialNotificationType.followSent => _localized(
        'Ai început să îl/o urmărești pe ${item.actorFullName}',
        'You started following ${item.actorFullName}',
      ),
      _SocialNotificationType.unfollowReceived => _localized(
        '${item.actorFullName} nu te mai urmărește',
        '${item.actorFullName} unfollowed you',
      ),
      _SocialNotificationType.unfollowSent => _localized(
        'Ai oprit urmărirea pentru ${item.actorFullName}',
        'You unfollowed ${item.actorFullName}',
      ),
      _SocialNotificationType.contactCreated => _localized(
        '${item.actorFullName} a devenit contact',
        '${item.actorFullName} became a contact',
      ),
      _SocialNotificationType.contactRemoved => _localized(
        'Contactul cu ${item.actorFullName} a fost eliminat',
        'Your contact with ${item.actorFullName} was removed',
      ),
    };
    final description = switch (item.type) {
      _SocialNotificationType.followReceived => _localized(
        'Ai primit un follower nou.',
        'You received a new follower.',
      ),
      _SocialNotificationType.followSent => _localized(
        'Acțiunea de follow a fost înregistrată cu succes.',
        'Your follow action was recorded successfully.',
      ),
      _SocialNotificationType.unfollowReceived => _localized(
        'Conexiunea de follow a fost retrasă.',
        'The follow connection was removed.',
      ),
      _SocialNotificationType.unfollowSent => _localized(
        'Ai retras conexiunea de follow.',
        'You removed the follow connection.',
      ),
      _SocialNotificationType.contactCreated => _localized(
        'Vă urmăriți reciproc, deci sunteți acum contacte.',
        'You follow each other, so you are now contacts.',
      ),
      _SocialNotificationType.contactRemoved => _localized(
        'Nu mai sunteți contacte după eliminarea urmăririi reciproce.',
        'You are no longer contacts after the mutual follow was removed.',
      ),
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredSocialNotificationId = item.id),
      onExit: (_) => setState(() => _hoveredSocialNotificationId = null),
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
            onTap: () => _onSocialNotificationTap(item),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildChatAvatar(
                        label: item.actorFullName,
                        bytes: _participantAvatar(item.actorUserId),
                        radius: 21,
                        background: accent,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.brightness == Brightness.dark
                                  ? const Color(0xFF23242B)
                                  : Colors.white,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(icon, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatSocialTimestamp(item.sentAt),
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
      case _NotificationCategory.message:
        await _openMessagesPanel();
        return;
      case _NotificationCategory.activities:
      case _NotificationCategory.jobs:
      case _NotificationCategory.comment:
        _showTopActionSoon();
        return;
    }
  }

  String _formatSocialTimestamp(DateTime sentAt) {
    final previous = _notificationsOpenedAt;
    _notificationsOpenedAt = _socialOpenedAt;
    final formatted = _formatNotificationTimestamp(sentAt);
    _notificationsOpenedAt = previous;
    return formatted;
  }

  Future<void> _onSocialNotificationTap(_SocialNotificationItem item) async {
    Navigator.of(context, rootNavigator: true).pop();
    await _openUserProfile(item.actorUserId);
  }

  Future<void> _openUserProfile(String userId) async {
    final token = await _readAccessToken();
    if (token == null || token.isEmpty || userId.trim().isEmpty) return;

    try {
      final data = await ApiService.getProfileByUserId(
        accessToken: token,
        userId: userId,
      );
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        _buildFuturisticRoute(
          const RouteSettings(name: '/profile-preview'),
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
            initialProfileData: data,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _showTopActionSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t(currentLang, 'comingSoon'))));
  }

  List<_MessageConversationItem> get _activeConversations {
    return _conversations
        .where((item) => !_isMessageRequestConversation(item))
        .toList(growable: false);
  }

  List<_MessageConversationItem> get _requestConversations {
    return _conversations
        .where((item) => _isMessageRequestConversation(item))
        .toList(growable: false);
  }

  _MessageConversationItem? get _activeConversation {
    final id = _activeConversationId;
    if (id == null) return null;
    for (final item in _conversations) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<_MessageEntryItem> get _activeMessages {
    final id = _activeConversationId;
    if (id == null) return const <_MessageEntryItem>[];

    final base = _messagesByConversation[id] ?? const <_MessageEntryItem>[];
    return <_MessageEntryItem>[_conversationSecuritySystemMessage(id), ...base];
  }

  String _conversationSubtitle(_MessageConversationItem conversation) {
    if (conversation.participants.isEmpty) {
      return _localized('Mesaje private', 'Direct messages');
    }

    final names = conversation.participants
        .map((item) {
          final userId = item['userId']?.toString();
          if (userId != null && userId == _currentUserId) {
            return null;
          }
          final name = item['fullName']?.toString().trim();
          if (name != null && name.isNotEmpty) return name;
          return item['email']?.toString().trim();
        })
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    if (names.isEmpty) return _localized('Doar tu', 'Only you');
    if (names.length == 1) return names.first;
    return '${names.first} +${names.length - 1}';
  }

  String _formatChatTime(DateTime date) {
    final local = date.toLocal();
    return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  bool _isSameCalendarDay(DateTime first, DateTime second) {
    final a = first.toLocal();
    final b = second.toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatConversationTimestamp(DateTime date) {
    final local = date.toLocal();
    final today = DateTime.now();
    final sent = DateTime(local.year, local.month, local.day);
    final current = DateTime(today.year, today.month, today.day);
    final dayDiff = current.difference(sent).inDays;

    if (dayDiff == 0) {
      return _localized('Azi', 'Today');
    }
    if (dayDiff == 1) {
      return _localized('Ieri', 'Yesterday');
    }

    return '${_twoDigits(local.day)}.${_twoDigits(local.month)}.${local.year}';
  }

  double _topBarAnchorFloor(MediaQueryData media) {
    if (media.size.width < 700) {
      return media.padding.top + 84;
    }
    if (media.size.width < 1060) {
      return media.padding.top + 108;
    }
    return media.padding.top + 74;
  }

  Offset _resolveTopBarAnchoredPosition({
    required MediaQueryData media,
    required double panelWidth,
    required double panelHeight,
    required Rect? anchorRect,
  }) {
    const edge = 12.0;
    final maxLeft = math.max(edge, media.size.width - panelWidth - edge);
    final minTop = math.max(edge, _topBarAnchorFloor(media));
    final maxTop = math.max(minTop, media.size.height - panelHeight - edge);

    if (anchorRect == null) {
      return Offset(maxLeft, minTop);
    }

    final anchoredLeft = anchorRect.left.clamp(edge, maxLeft).toDouble();
    final anchoredTop = math
        .max(anchorRect.bottom + 8.0, minTop)
        .clamp(minTop, maxTop)
        .toDouble();

    return Offset(anchoredLeft, anchoredTop);
  }

  Future<void> _openMessagesPanel({Rect? anchorRect}) async {
    _messagesButtonRect = anchorRect ?? _messagesButtonRect;
    await _refreshConversations(silent: false);
    if (!mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'messages',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, _) => _buildMessagesPanel(context),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      routeSettings: const RouteSettings(name: '/messages-panel'),
    );
  }

  Widget _buildMessagesPanel(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 720;
    final panelWidth = isMobile
        ? math.min(media.size.width - 24.0, 440.0)
        : 440.0;
    final panelMaxHeight = media.size.height - 24;
    final panelPosition = _resolveTopBarAnchoredPosition(
      media: media,
      panelWidth: panelWidth,
      panelHeight: panelMaxHeight,
      anchorRect: _messagesButtonRect,
    );

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
            top: panelPosition.dy,
            left: panelPosition.dx,
            child: StatefulBuilder(
              builder: (context, panelSetState) {
                final active = _activeConversations;
                final requests = _requestConversations;
                final showingRequests =
                    _messagesPanelTab == _MessagesPanelTab.requests;
                final visibleConversations = showingRequests
                    ? requests
                    : active;

                return Material(
                  color: Colors.transparent,
                  child: Container(
                    width: panelWidth,
                    constraints: BoxConstraints(maxHeight: panelMaxHeight),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF23242B)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
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
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Text(
                            _localized('Mesaje', 'Messages'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).pop();
                                    await _showStartConversationDialog();
                                  },
                                  icon: const Icon(Icons.person_search_rounded),
                                  label: Text(
                                    _localized(
                                      'Pornește conversație',
                                      'Start conversation',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).pop();
                                    await _showCreateGroupDialog();
                                  },
                                  icon: const Icon(Icons.group_add_rounded),
                                  label: Text(
                                    _localized('Creează grup', 'Create group'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    panelSetState(() {
                                      _messagesPanelTab =
                                          _MessagesPanelTab.messages;
                                    });
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        _messagesPanelTab ==
                                            _MessagesPanelTab.messages
                                        ? null
                                        : theme.colorScheme.surface,
                                    foregroundColor:
                                        _messagesPanelTab ==
                                            _MessagesPanelTab.messages
                                        ? null
                                        : theme.colorScheme.onSurface,
                                  ),
                                  child: Text(
                                    '${_localized('Mesaje', 'Messages')} (${active.length})',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    panelSetState(() {
                                      _messagesPanelTab =
                                          _MessagesPanelTab.requests;
                                    });
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        _messagesPanelTab ==
                                            _MessagesPanelTab.requests
                                        ? null
                                        : theme.colorScheme.surface,
                                    foregroundColor:
                                        _messagesPanelTab ==
                                            _MessagesPanelTab.requests
                                        ? null
                                        : theme.colorScheme.onSurface,
                                  ),
                                  child: Text(
                                    '${_localized('Cereri de mesaj', 'Message requests')} (${requests.length})',
                                  ),
                                ),
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
                                if (_messagesError != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFE63946,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _messagesError!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFFE63946),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                if (visibleConversations.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 22,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurface
                                          .withValues(
                                            alpha:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? 0.1
                                                : 0.04,
                                          ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.forum_outlined,
                                          size: 28,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          showingRequests
                                              ? _localized(
                                                  'Nu ai cereri de mesaj momentan',
                                                  'No message requests yet',
                                                )
                                              : _localized(
                                                  'Nu ai conversații momentan',
                                                  'No conversations yet',
                                                ),
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (visibleConversations.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      4,
                                      4,
                                      8,
                                    ),
                                    child: Text(
                                      showingRequests
                                          ? _localized(
                                              'Cereri de mesaj',
                                              'Message requests',
                                            )
                                          : _localized(
                                              'Conversații recente',
                                              'Recent conversations',
                                            ),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ...visibleConversations.map(
                                  (item) => _buildConversationPreviewTile(
                                    context,
                                    item,
                                    isRequest: showingRequests,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationPreviewTile(
    BuildContext context,
    _MessageConversationItem item, {
    bool isRequest = false,
  }) {
    final theme = Theme.of(context);
    final isContact = !isRequest && _isContactConversation(item);
    final avatarBytes = _conversationPreviewAvatar(item);
    final avatarLabel = _conversationPreviewAvatarLabel(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.12 : 0.04,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          Navigator.of(context, rootNavigator: true).pop();
          await _openMessagesPopup(conversationId: item.id);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              _buildChatAvatar(
                label: avatarLabel,
                bytes: avatarBytes,
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (item.lastMessageAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _formatConversationTimestamp(item.lastMessageAt!),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.62,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _conversationPreviewText(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    if (isContact)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildContactBadge(),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.lastMessageAt != null)
                    Text(
                      _formatChatTime(item.lastMessageAt!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.62,
                        ),
                      ),
                    ),
                  if (isRequest)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _localized('Cerere', 'Request'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else if (item.unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.16,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.unreadCount > 99
                            ? '99+'
                            : item.unreadCount.toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showStartConversationDialog() async {
    final token = await _readAccessToken();
    if (token == null || token.isEmpty || !mounted) return;

    final searchCtrl = TextEditingController();
    final results = <Map<String, dynamic>>[];
    var isSearching = false;
    Timer? searchDebounce;
    int activeSearchId = 0;

    Future<void> search(StateSetter setModalState) async {
      final query = searchCtrl.text.trim();
      if (query.isEmpty) {
        activeSearchId++;
        setModalState(() => results.clear());
        return;
      }

      final searchId = ++activeSearchId;
      setModalState(() => isSearching = true);
      try {
        final response = await ApiService.searchProfiles(
          accessToken: token,
          query: query,
          limit: 10,
        );
        if (!mounted || searchId != activeSearchId) return;
        final items = (response['items'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
        setModalState(() {
          results
            ..clear()
            ..addAll(items);
        });
      } catch (_) {
        if (searchId == activeSearchId) {
          setModalState(() => results.clear());
        }
      } finally {
        if (searchId == activeSearchId) {
          setModalState(() => isSearching = false);
        }
      }
    }

    void queueSearch(StateSetter setModalState) {
      searchDebounce?.cancel();
      searchDebounce = Timer(
        const Duration(milliseconds: 220),
        () => search(setModalState),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(
                _localized('Pornește conversație', 'Start conversation'),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchCtrl,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => queueSearch(setModalState),
                      onSubmitted: (_) {
                        searchDebounce?.cancel();
                        search(setModalState);
                      },
                      decoration: InputDecoration(
                        hintText: _localized(
                          'Caută un profil...',
                          'Search for a profile...',
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            searchDebounce?.cancel();
                            search(setModalState);
                          },
                          icon: const Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isSearching)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final item = results[index];
                            final user =
                                item['user'] as Map<String, dynamic>? ??
                                const <String, dynamic>{};
                            final userId = user['id']?.toString() ?? '';
                            final name = [
                              user['firstName']?.toString().trim() ?? '',
                              user['lastName']?.toString().trim() ?? '',
                            ].where((value) => value.isNotEmpty).join(' ');
                            final email = user['email']?.toString() ?? '';

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(name.isEmpty ? email : name),
                              subtitle: name.isEmpty ? null : Text(email),
                              trailing: const Icon(
                                Icons.chat_bubble_outline_rounded,
                              ),
                              onTap: userId.isEmpty || userId == _currentUserId
                                  ? null
                                  : () async {
                                      Navigator.of(
                                        dialogContext,
                                        rootNavigator: true,
                                      ).pop();
                                      try {
                                        final response =
                                            await ApiService.createDirectMessageConversation(
                                              accessToken: token,
                                              otherUserId: userId,
                                            );
                                        final conversationId =
                                            response['id']?.toString() ?? '';
                                        if (!mounted || conversationId.isEmpty) {
                                          return;
                                        }
                                        await _refreshConversations(
                                          silent: false,
                                        );
                                        await _openMessagesPopup(
                                          conversationId: conversationId,
                                        );
                                      } on ApiException catch (error) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          this.context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(error.message),
                                          ),
                                        );
                                      }
                                    },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchDebounce?.cancel();
    searchCtrl.dispose();
  }

  Future<void> _showCreateGroupDialog() async {
    final token = await _readAccessToken();
    if (token == null || token.isEmpty || !mounted) return;

    final titleCtrl = TextEditingController();
    final searchCtrl = TextEditingController();
    final results = <Map<String, dynamic>>[];
    final selectedMembers = <String, Map<String, dynamic>>{};
    var isSearching = false;

    Future<void> search(StateSetter setModalState) async {
      final query = searchCtrl.text.trim();
      if (query.length < 2) {
        setModalState(() => results.clear());
        return;
      }

      setModalState(() => isSearching = true);
      try {
        final response = await ApiService.searchProfiles(
          accessToken: token,
          query: query,
          limit: 12,
        );
        final items = (response['items'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
        setModalState(() {
          results
            ..clear()
            ..addAll(items);
        });
      } catch (_) {
        setModalState(() => results.clear());
      } finally {
        setModalState(() => isSearching = false);
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(_localized('Creează grup', 'Create group')),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        hintText: _localized('Numele grupului', 'Group name'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => search(setModalState),
                      decoration: InputDecoration(
                        hintText: _localized(
                          'Adaugă membri...',
                          'Add members...',
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => search(setModalState),
                          icon: const Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (selectedMembers.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedMembers.entries
                              .map((entry) {
                                final label =
                                    entry.value['label']?.toString() ??
                                    entry.key;
                                return InputChip(
                                  label: Text(label),
                                  onDeleted: () {
                                    setModalState(
                                      () => selectedMembers.remove(entry.key),
                                    );
                                  },
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (isSearching)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final item = results[index];
                            final user =
                                item['user'] as Map<String, dynamic>? ??
                                const <String, dynamic>{};
                            final userId = user['id']?.toString() ?? '';
                            final name = [
                              user['firstName']?.toString().trim() ?? '',
                              user['lastName']?.toString().trim() ?? '',
                            ].where((value) => value.isNotEmpty).join(' ');
                            final email = user['email']?.toString() ?? '';
                            final label = name.isEmpty ? email : name;
                            final selected = selectedMembers.containsKey(
                              userId,
                            );

                            return CheckboxListTile(
                              value: selected,
                              title: Text(label),
                              subtitle: name.isEmpty ? null : Text(email),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: userId.isEmpty
                                  ? null
                                  : (value) {
                                      setModalState(() {
                                        if (value == true) {
                                          selectedMembers[userId] = {
                                            'label': label,
                                          };
                                        } else {
                                          selectedMembers.remove(userId);
                                        }
                                      });
                                    },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext, rootNavigator: true).pop(),
                  child: Text(_localized('Anulează', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.length < 2) return;
                    final memberIds = selectedMembers.keys.toList(
                      growable: false,
                    );
                    Navigator.of(dialogContext, rootNavigator: true).pop();
                    try {
                      final response =
                          await ApiService.createGroupMessageConversation(
                            accessToken: token,
                            title: title,
                            memberIds: memberIds,
                          );
                      final conversationId = response['id']?.toString() ?? '';
                      if (!mounted || conversationId.isEmpty) return;
                      await _refreshConversations(silent: false);
                      await _openMessagesPopup(conversationId: conversationId);
                    } on ApiException catch (error) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(
                        this.context,
                      ).showSnackBar(SnackBar(content: Text(error.message)));
                    }
                  },
                  child: Text(_localized('Creează', 'Create')),
                ),
              ],
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    searchCtrl.dispose();
  }

  Future<void> _openMessagesPopup({String? conversationId}) async {
    if (conversationId != null &&
        conversationId.trim().isNotEmpty &&
        !_floatingConversationIds.contains(conversationId)) {
      if (_floatingConversationIds.length >= _maxFloatingConversations) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _localized(
                  'Poți avea maximum 5 conversații floating active.',
                  'You can have at most 5 active floating conversations.',
                ),
              ),
            ),
          );
        }
        return;
      }
      _floatingConversationIds.add(conversationId);
    }

    if (!_messagesPopupOpen && mounted) {
      setState(() {
        _messagesPopupOpen = true;
        _messagesPopupMinimized = false;
      });
    }

    await _refreshConversations(silent: false);
    if (!mounted || _conversations.isEmpty) return;

    final selectedConversationId =
        conversationId ??
        _activeConversationId ??
        (_activeConversations.isNotEmpty
            ? _activeConversations.first.id
            : null) ??
        _conversations.first.id;
    if (_activeConversationId != selectedConversationId && mounted) {
      setState(() => _activeConversationId = selectedConversationId);
    }

    await _loadConversationMessages(selectedConversationId, silent: true);
  }

  Future<void> _closeActiveConversationPopup() async {
    final closingConversationId = _activeConversationId;

    if (closingConversationId != null) {
      _floatingConversationIds.remove(closingConversationId);
    }

    final fallbackConversationId = _floatingConversationIds.isNotEmpty
        ? _floatingConversationIds.last
        : null;

    if (fallbackConversationId == null) {
      if (!mounted) return;
      setState(() {
        _messagesPopupOpen = false;
        _messagesPopupMinimized = false;
        _activeConversationId = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _activeConversationId = fallbackConversationId;
      _messagesPopupMinimized = false;
    });
    await _loadConversationMessages(fallbackConversationId, silent: true);
  }

  Widget _buildMessagesOverlay() {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;
    final popupHeight = _messagesPopupMinimized
        ? 64.0
        : (width < 760 ? 460.0 : 490.0);
    final popupWidth = _messagesPopupMinimized
        ? 250.0
        : (width < 760 ? math.min(width - 24, 420.0) : 420.0);
    final safeTop = media.padding.top + 78;
    final safeBottom = media.padding.bottom + 14;

    final minLeft = 12.0;
    final maxLeft = math.max(minLeft, width - popupWidth - 12);
    final minTop = safeTop;
    final maxTop = math.max(minTop, height - popupHeight - safeBottom);

    final popupLeft = _chatBubbleLeft.clamp(minLeft, maxLeft).toDouble();
    final popupTop = _chatBubbleTop.clamp(minTop, maxTop).toDouble();

    return Stack(
      children: [
        if (_messagesPopupOpen)
          Positioned(
            left: popupLeft,
            top: popupTop,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _chatBubbleLeft = (_chatBubbleLeft + details.delta.dx)
                      .clamp(minLeft, maxLeft)
                      .toDouble();
                  _chatBubbleTop = (_chatBubbleTop + details.delta.dy)
                      .clamp(minTop, maxTop)
                      .toDouble();
                });
              },
              child: _messagesPopupMinimized
                  ? GestureDetector(
                      onTap: _toggleMessagesMinimized,
                      child: _buildMinimizedChatBubble(),
                    )
                  : Container(
                      width: popupWidth,
                      height: popupHeight,
                      decoration: BoxDecoration(
                        color: currentIsDark
                            ? const Color(0xFF1F222D)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.14,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.26),
                            blurRadius: 26,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(10, 10, 2, 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.06,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(22),
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: _localized(
                                    'Minimizează',
                                    'Minimize',
                                  ),
                                  onPressed: _toggleMessagesMinimized,
                                  icon: const Icon(Icons.minimize_rounded),
                                ),
                                const SizedBox(width: 2),
                                _buildChatAvatar(
                                  label: _activeConversationPeerName,
                                  bytes: _participantAvatar(
                                    _activeConversationPeerUserId,
                                  ),
                                  radius: 17,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$_activeConversationPeerName, $_currentUserChatLabel',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          if (_activeConversation
                                                  ?.lastMessageAt !=
                                              null)
                                            Text(
                                              _formatConversationTimestamp(
                                                _activeConversation!
                                                    .lastMessageAt!,
                                              ),
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                          alpha: 0.68,
                                                        ),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          if (_activeConversationIsContact)
                                            _buildContactBadge(),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: _localized(
                                    'Închide conversația',
                                    'Close conversation',
                                  ),
                                  onPressed: _closeActiveConversationPopup,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                          ),
                          if (_messagesPanelLoading &&
                              _activeConversation == null)
                            const Expanded(
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else ...[
                            if (_messagesError != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  6,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFE63946,
                                    ).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _messagesError!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFFE63946),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: _activeConversation == null
                                  ? Center(
                                      child: Text(
                                        _localized(
                                          'Nu ai conversații încă.',
                                          'No conversations yet.',
                                        ),
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    )
                                  : Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.onSurface
                                            .withValues(
                                              alpha: currentIsDark
                                                  ? 0.11
                                                  : 0.04,
                                            ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: ListView.builder(
                                        reverse: true,
                                        itemCount: _activeMessages.length,
                                        itemBuilder: (context, index) {
                                          final chronologicalIndex =
                                              _activeMessages.length -
                                              1 -
                                              index;
                                          final entry =
                                              _activeMessages[chronologicalIndex];
                                          final previousEntry =
                                            chronologicalIndex > 0
                                            ? _activeMessages[chronologicalIndex -
                                              1]
                                            : null;
                                          final mine =
                                              _currentUserId != null &&
                                              entry.senderUserId ==
                                                  _currentUserId;
                                          final showSenderHeader =
                                            !entry.isSystem &&
                                            (previousEntry == null ||
                                              previousEntry.senderUserId !=
                                                entry.senderUserId ||
                                              !_isSameCalendarDay(
                                              previousEntry.createdAt,
                                              entry.createdAt,
                                              ));
                                          final senderName =
                                            mine
                                            ? _currentUserChatLabel
                                            : _participantDisplayName(
                                              entry.senderUserId,
                                            );
                                          final senderAvatar = mine
                                            ? avatarBytes
                                            : _participantAvatar(
                                              entry.senderUserId,
                                            );
                                          final senderDayLabel =
                                            _formatConversationTimestamp(
                                            entry.createdAt,
                                            );
                                          final detailsExpanded =
                                              _expandedMessageDetailsId ==
                                              entry.id;
                                          final detailsLines =
                                              _messageDetailsLines(entry);

                                          return Align(
                                            alignment: mine
                                                ? Alignment.centerRight
                                                : Alignment.centerLeft,
                                            child: GestureDetector(
                                              onSecondaryTapDown: entry.isSystem
                                                  ? null
                                                  : (details) =>
                                                        _showMessageContextMenu(
                                                          details,
                                                          entry,
                                                        ),
                                              onLongPressStart: entry.isSystem
                                                  ? null
                                                  : (
                                                      details,
                                                    ) => _showMessageContextMenu(
                                                      TapDownDetails(
                                                        globalPosition: details
                                                            .globalPosition,
                                                      ),
                                                      entry,
                                                    ),
                                              child: Column(
                                                crossAxisAlignment: mine
                                                    ? CrossAxisAlignment.end
                                                    : CrossAxisAlignment.start,
                                                children: [
                                                  if (showSenderHeader)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.fromLTRB(
                                                            10,
                                                            6,
                                                            10,
                                                            2,
                                                          ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          _buildChatAvatar(
                                                            label: senderName,
                                                            bytes: senderAvatar,
                                                            radius: 10,
                                                            background: mine
                                                                ? theme
                                                                      .colorScheme
                                                                      .secondary
                                                                : null,
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Text(
                                                            senderName,
                                                            style: theme
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Text(
                                                            senderDayLabel,
                                                            style: theme
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                                  color: theme
                                                                      .colorScheme
                                                                      .onSurface
                                                                      .withValues(
                                                                        alpha:
                                                                            0.68,
                                                                      ),
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      if (!mine)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                right: 6,
                                                                bottom: 2,
                                                              ),
                                                          child: _buildChatAvatar(
                                                            label: senderName,
                                                            bytes: _participantAvatar(
                                                              entry
                                                                  .senderUserId,
                                                            ),
                                                            radius: 13,
                                                          ),
                                                        ),
                                                      Container(
                                                        margin:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 4,
                                                              horizontal: 4,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 10,
                                                            ),
                                                        constraints:
                                                            const BoxConstraints(
                                                              maxWidth: 295,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: entry.isSystem
                                                              ? theme
                                                                    .colorScheme
                                                                    .surfaceContainerHighest
                                                              : (mine
                                                                    ? theme
                                                                          .colorScheme
                                                                          .primary
                                                                          .withValues(
                                                                            alpha:
                                                                                0.18,
                                                                          )
                                                                    : theme
                                                                          .colorScheme
                                                                          .surface),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              mine
                                                              ? CrossAxisAlignment
                                                                    .end
                                                              : CrossAxisAlignment
                                                                    .start,
                                                          children: [
                                                            InkWell(
                                                              onTap:
                                                                  entry.isSystem
                                                                  ? null
                                                                  : () => _toggleMessageDetails(
                                                                      entry.id,
                                                                    ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                child: Text(
                                                                  entry
                                                                      .ciphertext,
                                                                  style: theme.textTheme.bodyMedium?.copyWith(
                                                                    color:
                                                                        entry
                                                                            .isSystem
                                                                        ? const Color(
                                                                            0xFFB08900,
                                                                          )
                                                                        : null,
                                                                    fontWeight:
                                                                        entry
                                                                            .isSystem
                                                                        ? FontWeight
                                                                              .w700
                                                                        : null,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            if (!entry.isSystem)
                                                              _buildReactionStrip(
                                                                entry,
                                                              ),
                                                            if (!entry
                                                                    .isSystem &&
                                                                detailsExpanded)
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets.only(
                                                                      top: 4,
                                                                    ),
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      mine
                                                                      ? CrossAxisAlignment
                                                                            .end
                                                                      : CrossAxisAlignment
                                                                            .start,
                                                                  children: detailsLines
                                                                      .map(
                                                                        (
                                                                          line,
                                                                        ) => Text(
                                                                          line,
                                                                          style: theme.textTheme.labelSmall?.copyWith(
                                                                            fontSize:
                                                                                10,
                                                                            color: theme.colorScheme.onSurface.withValues(
                                                                              alpha: 0.56,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      )
                                                                      .toList(
                                                                        growable:
                                                                            false,
                                                                      ),
                                                                ),
                                                              ),
                                                            if (!entry.isSystem)
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                            if (!entry.isSystem)
                                                              Text(
                                                                entry.editedAt !=
                                                                        null
                                                                    ? '${_formatChatTime(entry.createdAt)} · ${_localized('editat', 'edited')}'
                                                                    : _formatChatTime(
                                                                        entry
                                                                            .createdAt,
                                                                      ),
                                                                style: theme
                                                                    .textTheme
                                                                    .labelSmall
                                                                    ?.copyWith(
                                                                      color: theme
                                                                          .colorScheme
                                                                          .onSurface
                                                                          .withValues(
                                                                            alpha:
                                                                                0.62,
                                                                          ),
                                                                    ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      if (mine)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                left: 6,
                                                                bottom: 2,
                                                              ),
                                                          child: _buildChatAvatar(
                                                            label:
                                                                _currentUserChatLabel,
                                                            bytes: avatarBytes,
                                                            radius: 13,
                                                            background: theme
                                                                .colorScheme
                                                                .secondary,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                            ),
                            if (_activeConversation != null &&
                                !_activeConversationAllowsOpenReply)
                              _buildRequestReplyHintBanner(),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _chatComposerCtrl,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => _sendMessage(),
                                      decoration: InputDecoration(
                                        hintText: _localized(
                                          'Scrie un mesaj...',
                                          'Write a message...',
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filled(
                                    onPressed: _messagesSending
                                        ? null
                                        : _sendMessage,
                                    icon: _messagesSending
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.send_rounded),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
      ],
    );
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
      body: Stack(
        children: [
          Column(
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
                onMessagesTap: (anchorRect) {
                  _openMessagesPanel(anchorRect: anchorRect);
                },
                onSocialTap: (anchorRect) {
                  _openSocialPanel(anchorRect: anchorRect);
                },
                onNotificationsTap: (anchorRect) {
                  _openNotificationsPanel(anchorRect: anchorRect);
                },
                onSearchAction: _handleTopSearchAction,
                messagesBadgeCount: _messagesBadgeCount,
                socialBadgeCount: _socialBadgeCount,
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
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: _buildMessagesOverlay(),
            ),
          ),
        ],
      ),
    );
  }
}
