import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../core/texts.dart';
import '../services/api_service.dart';
import '../services/secure_storage.dart';
import '../widgets/authenticated_page_shell.dart';
import 'profile_page.dart';

class ProfileSearchPage extends StatefulWidget {
  final String lang;
  final bool isDark;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final Future<void> Function() onLogout;
  final String initialQuery;
  final bool useEmbeddedLayout;

  const ProfileSearchPage({
    super.key,
    required this.lang,
    required this.isDark,
    required this.onLangChange,
    required this.onThemeChange,
    required this.onLogout,
    required this.initialQuery,
    this.useEmbeddedLayout = false,
  });

  @override
  State<ProfileSearchPage> createState() => _ProfileSearchPageState();
}

class _ProfileSearchPageState extends State<ProfileSearchPage> {
  static const int _pageSize = 20;

  late final TextEditingController _searchCtrl;
  String _selectedField = 'all';
  bool _isLoading = true;
  String? _error;
  int _page = 1;
  int _total = 0;
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic>? _selfSearchItem;
  final Map<String, Uint8List?> _avatarByUserId = <String, Uint8List?>{};
  final Set<String> _avatarLoadingUserIds = <String>{};
  late String _lang;
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _lang = widget.lang;
    _isDark = widget.isDark;
    _searchCtrl = TextEditingController(text: widget.initialQuery);
    _runSearch(resetPage: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProfileSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lang != widget.lang) _lang = widget.lang;
    if (oldWidget.isDark != widget.isDark) _isDark = widget.isDark;
  }

  Future<void> _runSearch({required bool resetPage}) async {
    final token = await SecureStorage.read('access_token');
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      await widget.onLogout();
      return;
    }

    final nextPage = resetPage ? 1 : _page;
    setState(() {
      _isLoading = true;
      _error = null;
      _page = nextPage;
    });

    try {
      await _ensureSelfSearchItem(token);

      final data = await ApiService.searchProfiles(
        accessToken: token,
        query: _searchCtrl.text.trim(),
        field: _selectedField,
        page: nextPage,
        limit: _pageSize,
      );

      final fetchedItems = (data['items'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList(growable: false) ??
          const <Map<String, dynamic>>[];

      final augmentedItems = _includeSelfInResults(
        fetchedItems,
        query: _searchCtrl.text.trim(),
        field: _selectedField,
        page: nextPage,
      );

      if (!mounted) return;
      setState(() {
        final backendTotal = (data['total'] as num?)?.toInt() ?? 0;
        final selfInjected = augmentedItems.length > fetchedItems.length;
        _total = backendTotal + (selfInjected ? 1 : 0);
        _items = augmentedItems;
        _isLoading = false;
      });
      unawaited(_preloadResultAvatars(token, augmentedItems));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = t(_lang, 'loginGenericError');
        _isLoading = false;
      });
    }
  }

  Future<void> _preloadResultAvatars(
    String token,
    List<Map<String, dynamic>> items,
  ) async {
    final userIds = <String>{};
    for (final item in items) {
      final userId = item['userId']?.toString().trim() ?? '';
      if (userId.isNotEmpty) {
        userIds.add(userId);
      }
    }

    for (final userId in userIds) {
      if (_avatarByUserId.containsKey(userId) ||
          _avatarLoadingUserIds.contains(userId)) {
        continue;
      }

      _avatarLoadingUserIds.add(userId);
      try {
        final bytes = await ApiService.fetchUserAvatar(
          accessToken: token,
          userId: userId,
        );
        if (!mounted) return;
        setState(() {
          _avatarByUserId[userId] = bytes;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _avatarByUserId[userId] = null;
        });
      } finally {
        _avatarLoadingUserIds.remove(userId);
      }
    }
  }

  String _avatarInitials(Map<String, dynamic> item) {
    final firstName = item['firstName']?.toString().trim() ?? '';
    final lastName = item['lastName']?.toString().trim() ?? '';
    final first = firstName.isNotEmpty ? firstName.characters.first : '';
    final last = lastName.isNotEmpty ? lastName.characters.first : '';
    final initials = '$first$last'.trim();
    if (initials.isNotEmpty) return initials.toUpperCase();

    final email = item['email']?.toString().trim() ?? '';
    if (email.isNotEmpty) return email.characters.first.toUpperCase();
    return '?';
  }

  Future<void> _openProfile(Map<String, dynamic> item) async {
    final token = await SecureStorage.read('access_token');
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      await widget.onLogout();
      return;
    }

    try {
      final userId = item['userId']?.toString() ?? '';
      if (userId.isEmpty) return;
      final data = await ApiService.getProfileByUserId(
        accessToken: token,
        userId: userId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProfilePage(
            lang: _lang,
            isDark: _isDark,
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

  Future<void> _ensureSelfSearchItem(String token) async {
    if (_selfSearchItem != null) return;

    try {
      final profile = await ApiService.getProfile(accessToken: token);
      final user = profile['user'] as Map<String, dynamic>? ?? {};
      final userProfile = profile['userProfile'] as Map<String, dynamic>? ?? {};
      _selfSearchItem = {
        'userId': user['id']?.toString() ?? '',
        'firstName': user['firstName']?.toString() ?? '',
        'lastName': user['lastName']?.toString() ?? '',
        'email': user['email']?.toString() ?? '',
        'jobTitle': userProfile['jobTitle']?.toString() ?? '',
        'city': userProfile['city']?.toString() ?? '',
        'county': userProfile['county']?.toString() ?? '',
        'country': userProfile['country']?.toString() ?? '',
        'yearsExperience': userProfile['yearsExperience'],
      };
    } catch (_) {
      return;
    }
  }

  List<Map<String, dynamic>> _includeSelfInResults(
    List<Map<String, dynamic>> items, {
    required String query,
    required String field,
    required int page,
  }) {
    final self = _selfSearchItem;
    if (self == null || page != 1) {
      return items;
    }

    final selfUserId = self['userId']?.toString() ?? '';
    final alreadyPresent = items.any(
      (entry) => entry['userId']?.toString() == selfUserId,
    );
    if (alreadyPresent) {
      return items;
    }

    if (!_matchesSearch(self, query: query, field: field)) {
      return items;
    }

    return <Map<String, dynamic>>[self, ...items];
  }

  bool _matchesSearch(
    Map<String, dynamic> entry, {
    required String query,
    required String field,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }

    final name =
        '${entry['firstName']?.toString() ?? ''} ${entry['lastName']?.toString() ?? ''}'
            .toLowerCase();
    final email = (entry['email']?.toString() ?? '').toLowerCase();
    final jobTitle = (entry['jobTitle']?.toString() ?? '').toLowerCase();
    final city = (entry['city']?.toString() ?? '').toLowerCase();
    final county = (entry['county']?.toString() ?? '').toLowerCase();
    final country = (entry['country']?.toString() ?? '').toLowerCase();

    switch (field) {
      case 'name':
        return name.contains(normalized);
      case 'email':
        return email.contains(normalized);
      case 'jobTitle':
        return jobTitle.contains(normalized);
      default:
        return name.contains(normalized) ||
            email.contains(normalized) ||
            jobTitle.contains(normalized) ||
            city.contains(normalized) ||
            county.contains(normalized) ||
            country.contains(normalized);
    }
  }

  bool _isSelfResult(Map<String, dynamic> item) {
    final selfUserId = _selfSearchItem?['userId']?.toString() ?? '';
    if (selfUserId.isEmpty) return false;
    return item['userId']?.toString() == selfUserId;
  }

  @override
  Widget build(BuildContext context) {
    final maxPage = (_total / _pageSize).ceil().clamp(1, 1000000);
    final fieldOptions = <DropdownMenuItem<String>>[
      DropdownMenuItem(value: 'all', child: Text(t(_lang, 'searchFilterAll'))),
      DropdownMenuItem(value: 'name', child: Text(t(_lang, 'searchFilterName'))),
      DropdownMenuItem(value: 'email', child: Text(t(_lang, 'searchFilterEmail'))),
      DropdownMenuItem(value: 'jobTitle', child: Text(t(_lang, 'searchFilterJobTitle'))),
    ];

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text(_error!))
        : Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;

              if (compact) {
                return Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _runSearch(resetPage: true),
                      decoration: InputDecoration(
                        hintText: t(_lang, 'searchCandidatesJobs'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.close_rounded),
                            label: Text(t(_lang, 'closeSearch')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _runSearch(resetPage: true),
                            child: Text(t(_lang, 'searchAction')),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _runSearch(resetPage: true),
                      decoration: InputDecoration(
                        hintText: t(_lang, 'searchCandidatesJobs'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                            label: Text(t(_lang, 'closeSearch')),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => _runSearch(resetPage: true),
                            child: Text(t(_lang, 'searchAction')),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                t(_lang, 'searchFiltersLabel'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedField,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: fieldOptions,
                  onChanged: (value) {
                    if (value == null || value == _selectedField) return;
                    setState(() => _selectedField = value);
                    _runSearch(resetPage: true);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _items.isEmpty
                ? Center(child: Text(t(_lang, 'searchNoResults')))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final isSelf = _isSelfResult(item);
                      final name =
                          '${item['firstName']?.toString() ?? ''} ${item['lastName']?.toString() ?? ''}'
                              .trim();
                      final title = item['jobTitle']?.toString() ?? '';
                      final location = [
                        item['city']?.toString() ?? '',
                        item['county']?.toString() ?? '',
                        item['country']?.toString() ?? '',
                      ].where((entry) => entry.trim().isNotEmpty).join(', ');
                      final years = (item['yearsExperience'] as num?)?.toInt();
                      final userId = item['userId']?.toString() ?? '';
                      final avatarBytes = _avatarByUserId[userId];

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openProfile(item),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isSelf
                                ? Colors.green.withValues(alpha: 0.08)
                                : null,
                            border: Border.all(
                              color: isSelf
                                  ? Colors.green.withValues(alpha: 0.6)
                                  : Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.2),
                              width: isSelf ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 19,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.14),
                                    foregroundImage: avatarBytes != null
                                        ? MemoryImage(avatarBytes)
                                        : null,
                                    child: avatarBytes == null
                                        ? Text(
                                            _avatarInitials(item),
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      name.isEmpty
                                          ? item['email']?.toString() ?? '-'
                                          : name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (isSelf)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        color: Colors.green.withValues(alpha: 0.16),
                                        border: Border.all(
                                          color: Colors.green.withValues(alpha: 0.65),
                                        ),
                                      ),
                                      child: Text(
                                        t(_lang, 'searchSelfBadge'),
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (title.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(title),
                              ],
                              if (location.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(location),
                              ],
                              if (years != null) ...[
                                const SizedBox(height: 4),
                                Text('${t(_lang, 'yearsExperience')}: $years'),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _page > 1
                    ? () {
                        setState(() => _page -= 1);
                        _runSearch(resetPage: false);
                      }
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('$_page / $maxPage'),
              IconButton(
                onPressed: _page < maxPage
                    ? () {
                        setState(() => _page += 1);
                        _runSearch(resetPage: false);
                      }
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          ],
        ),
      ),
    );

    if (widget.useEmbeddedLayout) {
      return content;
    }

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
      child: content,
    );
  }
}
