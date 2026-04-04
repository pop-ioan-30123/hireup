import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/romania_locations.dart';
import '../../core/texts.dart';
import '../../services/api_service.dart';
import '../../services/secure_storage.dart';
import '../../widgets/authenticated_page_shell.dart';

part 'services_map_page.part.dart';
part 'services_categories_page.part.dart';
part 'services_posted_page.part.dart';
part 'services_upcoming_page.part.dart';

class ServicesPage extends StatefulWidget {
  final String lang;
  final bool isDark;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final Future<void> Function() onLogout;

  const ServicesPage({
    super.key,
    required this.lang,
    required this.isDark,
    required this.onLangChange,
    required this.onThemeChange,
    required this.onLogout,
  });

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  late String _currentLang;
  late bool _currentIsDark;
  Timer? _statusTicker;
  bool _didAttemptInitialMapOpen = false;

  _ActivityFilter _selectedFilter = _ActivityFilter.all;
  _SortOption _selectedSort = _SortOption.postedDesc;
  bool _isLoading = false;
  String? _loadErrorMessage;

  final List<_ActivityItem> _items = [];

  final Set<String> _appliedByMe = <String>{};
  final List<_ActivityNotification> _notificationTable =
      <_ActivityNotification>[];
  final Map<String, _AssignedProvider> _assignedProviderByActivity = {};

  _ServicesFlowStage _flowStage = _ServicesFlowStage.location;
  String? _selectedCounty;
  String? _selectedCity;
  String _selectedCategoryKey = _allCategoriesKey;

  static const _DualRating _myPostedActivitiesRating = _DualRating(
    labelKey: 'asPayer',
    rating: 0,
    reviewCount: 0,
  );

  static const _DualRating _myProvidedActivitiesRating = _DualRating(
    labelKey: 'asProvider',
    rating: 4.84,
    reviewCount: 41,
  );

  @override
  void initState() {
    super.initState();
    _currentLang = widget.lang;
    _currentIsDark = widget.isDark;
    _syncUnassignedDeadlineNotifications();
    unawaited(_refreshActivitiesFromApi());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openInitialServicesMapPage());
    });
    _statusTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      unawaited(_refreshActivitiesFromApi(silent: true));
    });
  }

  @override
  void dispose() {
    _statusTicker?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ServicesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lang != widget.lang && _currentLang != widget.lang) {
      _currentLang = widget.lang;
    }
    if (oldWidget.isDark != widget.isDark && _currentIsDark != widget.isDark) {
      _currentIsDark = widget.isDark;
    }
  }

  String _tr(String key) => t(_currentLang, _servicesTextKey(key));

  Future<void> _openInitialServicesMapPage() async {
    if (!mounted || _didAttemptInitialMapOpen) return;
    _didAttemptInitialMapOpen = true;
    if (_selectedCounty != null && _selectedCity != null) return;
    await _openServicesMapPage();
  }

  String _apiFilter() {
    switch (_selectedFilter) {
      case _ActivityFilter.all:
        return 'all';
      case _ActivityFilter.recurring:
        return 'recurring';
      case _ActivityFilter.oneTime:
        return 'oneTime';
    }
  }

  String _apiSort() {
    switch (_selectedSort) {
      case _SortOption.postedAsc:
        return 'postedAsc';
      case _SortOption.postedDesc:
        return 'postedDesc';
      case _SortOption.dueAsc:
        return 'dueAsc';
      case _SortOption.dueDesc:
        return 'dueDesc';
    }
  }

  String _normalizeCategoryKey(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return _fallbackCategoryKey;
    }

    if (_serviceCategories.any((category) => category.key == normalized)) {
      return normalized;
    }

    return _fallbackCategoryKey;
  }

  Future<Map<String, dynamic>> _loadOptionalActivitiesPayload(
    Future<Map<String, dynamic>> request,
  ) async {
    try {
      return await request;
    } catch (_) {
      return const <String, dynamic>{'items': <dynamic>[]};
    }
  }

  Future<void> _refreshActivitiesFromApi({bool silent = false}) async {
    final token = await SecureStorage.read('access_token');
    if (token == null || token.isEmpty) return;

    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final marketplace = await ApiService.listMarketplaceActivities(
        accessToken: token,
        filter: _apiFilter(),
        sort: _apiSort(),
        section: 'services',
        county: _selectedCounty,
        city: _selectedCity,
        categoryKey: _selectedCategoryKey == _allCategoriesKey
            ? null
            : _selectedCategoryKey,
      );
      final mine = await _loadOptionalActivitiesPayload(
        ApiService.listMyActivities(accessToken: token),
      );
      final upcoming = await _loadOptionalActivitiesPayload(
        ApiService.listUpcomingActivities(accessToken: token),
      );
      final notifications = await _loadOptionalActivitiesPayload(
        ApiService.listActivityNotifications(accessToken: token),
      );

      final merged = <String, _ActivityItem>{};
      final assignedById = <String, _AssignedProvider>{};
      final appliedByMe = <String>{};

      void absorb(List<dynamic> list) {
        for (final raw in list) {
          if (raw is! Map<String, dynamic>) continue;
          final item = _activityFromApi(raw);
          if (item.section != 'services') continue;
          merged[item.id] = item;

          final providerNode = raw['provider'];
          if (providerNode is Map<String, dynamic>) {
            final fullName = providerNode['fullName']?.toString().trim() ?? '';
            final split = fullName.split(RegExp(r'\s+'));
            final firstName = split.isNotEmpty ? split.first : 'Provider';
            final lastName = split.length > 1 ? split.sublist(1).join(' ') : '';

            assignedById[item.id] = _AssignedProvider(
              firstName: firstName,
              lastName: lastName,
              providerRating:
                  (providerNode['rating'] as num?)?.toDouble() ?? 5.0,
            );
          }

          if (raw['isUpcomingForCurrentUser'] == true) {
            appliedByMe.add(item.id);
          }
        }
      }

      absorb((marketplace['items'] as List<dynamic>?) ?? const []);
      absorb((mine['items'] as List<dynamic>?) ?? const []);
      absorb((upcoming['items'] as List<dynamic>?) ?? const []);

      final notificationsItems =
          (notifications['items'] as List<dynamic>?) ?? const [];

      if (!mounted) return;
      setState(() {
        _loadErrorMessage = null;
        _items
          ..clear()
          ..addAll(merged.values.toList());
        _appliedByMe
          ..clear()
          ..addAll(appliedByMe);
        _assignedProviderByActivity
          ..clear()
          ..addAll(assignedById);
        _notificationTable
          ..clear()
          ..addAll(
            notificationsItems.whereType<Map<String, dynamic>>().map(
              (node) => _ActivityNotification(
                title: node['title']?.toString() ?? _tr('activitiesTitle'),
                description: node['description']?.toString() ?? '',
                category: node['category']?.toString() ?? 'activity',
                type: node['type']?.toString() ?? 'info',
                sentAt:
                    DateTime.tryParse(node['sentAt']?.toString() ?? '') ??
                    DateTime.now(),
              ),
            ),
          );
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loadErrorMessage = error.message);
      if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadErrorMessage = _tr('activitiesLoadFailed'));
      if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_tr('activitiesLoadFailed'))));
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleBackNavigation() {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (rootNavigator.canPop()) {
      rootNavigator.pop();
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  _ActivityItem _activityFromApi(Map<String, dynamic> raw) {
    final owner = raw['owner'] as Map<String, dynamic>?;

    final categoryCandidate =
        raw['categoryKey']?.toString() ?? raw['category']?.toString();
    final normalizedSection = raw['section']?.toString().trim();

    return _ActivityItem(
      id: raw['id']?.toString() ?? '',
      title: raw['title']?.toString() ?? '',
      description: raw['description']?.toString() ?? '',
      amountRon: (raw['amountRon'] as num?)?.toDouble() ?? 0,
      isRecurring: raw['isRecurring'] == true,
      recurrenceLabel: raw['recurrenceLabel']?.toString(),
      mealIncluded: raw['mealIncluded'] == true,
      posterName: owner?['fullName']?.toString() ?? 'User',
      posterRating: (owner?['rating'] as num?)?.toDouble() ?? 5,
      reviewCount: (owner?['reviewCount'] as num?)?.toInt() ?? 0,
      dueAt:
          DateTime.tryParse(raw['startAt']?.toString() ?? '') ?? DateTime.now(),
      createdAt:
          DateTime.tryParse(raw['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      country: raw['country']?.toString() ?? '',
      county: raw['county']?.toString() ?? '',
      city: raw['city']?.toString() ?? '',
      durationHours: (raw['durationHours'] as num?)?.toInt() ?? 1,
      isPostedByCurrentUser: raw['isPostedByCurrentUser'] == true,
      status: raw['status']?.toString(),
      closeReason: raw['closeReason']?.toString(),
      section: normalizedSection == null || normalizedSection.isEmpty
          ? 'services'
          : normalizedSection,
      categoryKey: _normalizeCategoryKey(categoryCandidate),
      subcategoryKey: raw['subcategoryKey']?.toString(),
    );
  }

  bool _isWarningWindowNoProvider(_ActivityItem item, DateTime now) {
    return item.isPostedByCurrentUser &&
        item.status == 'open' &&
        item.closeReason != 'no_provider_by_deadline' &&
        !_assignedProviderByActivity.containsKey(item.id) &&
        item.dueAt.isAfter(now) &&
        item.dueAt.difference(now) <= const Duration(hours: 6);
  }

  bool _isClosedNoProvider(_ActivityItem item, DateTime now) {
    return item.isPostedByCurrentUser &&
        !_assignedProviderByActivity.containsKey(item.id) &&
        item.closeReason == 'no_provider_by_deadline' &&
        (item.status == 'closed' ||
            now.isAfter(item.dueAt) ||
            now.isAtSameMomentAs(item.dueAt));
  }

  void _syncUnassignedDeadlineNotifications() {
    // Notifications are sourced from backend `activity_notification` table.
  }

  String _formatActivitiesTimeOfDay(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  List<_ActivityItem> _availableItems() {
    _syncUnassignedDeadlineNotifications();
    final now = DateTime.now();

    final openItems = _items.where((item) {
      final isAssigned = _assignedProviderByActivity.containsKey(item.id);
      final appliedByMe = _appliedByMe.contains(item.id);
      final hiddenBecauseNoProviderCloseToDeadline =
          !_assignedProviderByActivity.containsKey(item.id) &&
          (item.dueAt.difference(now) <= const Duration(hours: 6));

      return !isAssigned &&
          !appliedByMe &&
          !hiddenBecauseNoProviderCloseToDeadline;
    });

    final filtered = openItems.where((item) {
      final matchesLocation =
          _selectedCounty == null ||
          _selectedCity == null ||
          (item.county.toLowerCase() == _selectedCounty!.toLowerCase() &&
              item.city.toLowerCase() == _selectedCity!.toLowerCase());
      if (!matchesLocation) return false;

      final matchesCategory =
          _selectedCategoryKey == _allCategoriesKey ||
          item.categoryKey == _selectedCategoryKey;
      if (!matchesCategory) return false;

      switch (_selectedFilter) {
        case _ActivityFilter.all:
          return true;
        case _ActivityFilter.recurring:
          return item.isRecurring;
        case _ActivityFilter.oneTime:
          return !item.isRecurring;
      }
    }).toList();

    filtered.sort((a, b) {
      switch (_selectedSort) {
        case _SortOption.postedAsc:
          return a.createdAt.compareTo(b.createdAt);
        case _SortOption.postedDesc:
          return b.createdAt.compareTo(a.createdAt);
        case _SortOption.dueAsc:
          return a.dueAt.compareTo(b.dueAt);
        case _SortOption.dueDesc:
          return b.dueAt.compareTo(a.dueAt);
      }
    });

    return filtered;
  }

  List<_ActivityItem> _postedItems() {
    return _items
        .where(
          (item) => item.isPostedByCurrentUser && item.section == 'services',
        )
        .toList();
  }

  List<_ActivityItem> _upcomingItems() {
    return _items
        .where(
          (item) =>
              _appliedByMe.contains(item.id) && item.section == 'services',
        )
        .toList();
  }

  Future<void> _onTapMarketplaceItem(_ActivityItem item) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_tr('applyDialogTitle')),
          content: Text(_tr('applyDialogBody')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_tr('confirmAction')),
            ),
          ],
        );
      },
    );

    if (approved != true) return;
    final token = await SecureStorage.read('access_token');
    if (token == null || token.isEmpty) return;

    try {
      await ApiService.acceptMarketplaceActivity(
        accessToken: token,
        activityId: item.id,
      );
      await _refreshActivitiesFromApi(silent: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _deletePostedActivity(String activityId) async {
    final token = await SecureStorage.read('access_token');
    if (token == null || token.isEmpty) return;

    try {
      await ApiService.deleteMarketplaceActivity(
        accessToken: token,
        activityId: activityId,
      );
      await _refreshActivitiesFromApi(silent: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _removeAssignedProvider(String activityId) async {
    final token = await SecureStorage.read('access_token');
    if (token == null || token.isEmpty) return;

    try {
      await ApiService.removeMarketplaceProvider(
        accessToken: token,
        activityId: activityId,
      );
      await _refreshActivitiesFromApi(silent: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _saveEditedActivity(_ActivityItem updated) async {
    final token = await SecureStorage.read('access_token');
    if (token == null || token.isEmpty) return;

    try {
      await ApiService.updateMarketplaceActivity(
        accessToken: token,
        activityId: updated.id,
        section: updated.section,
        categoryKey: updated.categoryKey,
        subcategoryKey: updated.subcategoryKey,
        title: updated.title,
        description: updated.description,
        amountRon: updated.amountRon,
        durationHours: updated.durationHours,
        country: updated.country,
        county: updated.county,
        city: updated.city,
        startAt: updated.dueAt,
        isRecurring: updated.isRecurring,
        recurrenceLabel: updated.recurrenceLabel,
        mealIncluded: updated.mealIncluded,
      );
      await _refreshActivitiesFromApi(silent: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openAddActivityForm() async {
    final created = await _showAddActivityDialog();
    if (created == null) return;
    final token = await SecureStorage.read('access_token');
    if (token == null || token.isEmpty) return;

    try {
      await ApiService.createMarketplaceActivity(
        accessToken: token,
        section: created.section,
        categoryKey: created.categoryKey,
        subcategoryKey: created.subcategoryKey,
        title: created.title,
        description: created.description,
        amountRon: created.amountRon,
        durationHours: created.durationHours,
        country: created.country,
        county: created.county,
        city: created.city,
        startAt: created.dueAt,
        isRecurring: created.isRecurring,
        recurrenceLabel: created.recurrenceLabel,
        mealIncluded: created.mealIncluded,
      );
      await _refreshActivitiesFromApi(silent: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openAddActivityFormGuarded() async {
    if (_selectedCounty == null || _selectedCity == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecteaza mai intai judetul si localitatea.'),
        ),
      );
      return;
    }

    await _openAddActivityForm();
  }

  Future<_ActivityItem?> _showAddActivityDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final durationController = TextEditingController(text: '2');
    final countryController = TextEditingController(text: 'Romania');
    final countyController = TextEditingController(text: _selectedCounty ?? '');
    final cityController = TextEditingController(text: _selectedCity ?? '');

    var dueAt = DateTime.now().add(const Duration(days: 1));
    var startTime = TimeOfDay.fromDateTime(dueAt);
    var isRecurring = false;
    var recurrencePattern = _RecurrencePattern.weekly;
    final selectedWeekdays = <int>{DateTime.now().weekday};
    var mealIncluded = false;
    String? selectedCategoryKey = _selectedCategoryKey == _allCategoriesKey
        ? null
        : _selectedCategoryKey;
    String? selectedSubcategoryKey;

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(_tr('addActivity')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: _tr('title')),
                    ),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: _tr('description'),
                      ),
                    ),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: _tr('priceRon')),
                    ),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: _tr('durationHours'),
                      ),
                    ),
                    if ((int.tryParse(durationController.text.trim()) ?? 0) > 4)
                      CheckboxListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_tr('mealIncludedToggle')),
                        value: mealIncluded,
                        onChanged: (value) {
                          setDialogState(() => mealIncluded = value ?? false);
                        },
                      ),
                    TextField(
                      controller: countryController,
                      readOnly: true,
                      decoration: InputDecoration(labelText: _tr('country')),
                    ),
                    TextField(
                      controller: countyController,
                      readOnly: true,
                      decoration: InputDecoration(labelText: _tr('county')),
                    ),
                    TextField(
                      controller: cityController,
                      readOnly: true,
                      decoration: InputDecoration(labelText: _tr('city')),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedCategoryKey == _allCategoriesKey)
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategoryKey,
                        decoration: const InputDecoration(
                          labelText: 'Categoria serviciului',
                        ),
                        items: _serviceCategories
                            .where(
                              (category) => category.key != _allCategoriesKey,
                            )
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category.key,
                                child: Text(category.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedCategoryKey = value;
                            selectedSubcategoryKey = null;
                          });
                        },
                      )
                    else
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Categoria serviciului',
                        ),
                        child: Text(
                          _serviceCategoryLabel(selectedCategoryKey),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSubcategoryKey,
                      decoration: const InputDecoration(
                        labelText: 'Subcategorie',
                      ),
                      items: _subcategoriesForCategory(selectedCategoryKey)
                          .map(
                            (subcategory) => DropdownMenuItem<String>(
                              value: subcategory.key,
                              child: Text(subcategory.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        setDialogState(() => selectedSubcategoryKey = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_tr('dueDate')}: ${dueAt.day}.${dueAt.month}.${dueAt.year}',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 1),
                              ),
                              lastDate: DateTime(2032, 12, 31),
                              initialDate: dueAt,
                            );
                            if (picked == null) return;
                            setDialogState(() => dueAt = picked);
                          },
                          child: Text(_tr('chooseDate')),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_tr('startTime')}: ${_formatActivitiesTimeOfDay(startTime)}',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: startTime,
                            );
                            if (picked == null) return;
                            setDialogState(() => startTime = picked);
                          },
                          child: Text(_tr('chooseTime')),
                        ),
                      ],
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_tr('recurringToggle')),
                      value: isRecurring,
                      onChanged: (value) {
                        setDialogState(() => isRecurring = value);
                      },
                    ),
                    if (isRecurring)
                      DropdownButtonFormField<_RecurrencePattern>(
                        initialValue: recurrencePattern,
                        decoration: InputDecoration(
                          labelText: _tr('recurrenceType'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: _RecurrencePattern.daily,
                            child: Text(_tr('recurrenceDaily')),
                          ),
                          DropdownMenuItem(
                            value: _RecurrencePattern.weekly,
                            child: Text(_tr('recurrenceWeekly')),
                          ),
                          DropdownMenuItem(
                            value: _RecurrencePattern.biWeekly,
                            child: Text(_tr('recurrenceBiWeekly')),
                          ),
                          DropdownMenuItem(
                            value: _RecurrencePattern.monthly,
                            child: Text(_tr('recurrenceMonthly')),
                          ),
                          DropdownMenuItem(
                            value: _RecurrencePattern.byDays,
                            child: Text(_tr('recurrenceByDays')),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => recurrencePattern = value);
                        },
                      ),
                    if (isRecurring &&
                        recurrencePattern == _RecurrencePattern.byDays)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tr('chooseWeekdays'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var index = 0; index < 7; index++)
                                  FilterChip(
                                    label: Text(
                                      _tr(
                                        [
                                          'weekdayMon',
                                          'weekdayTue',
                                          'weekdayWed',
                                          'weekdayThu',
                                          'weekdayFri',
                                          'weekdaySat',
                                          'weekdaySun',
                                        ][index],
                                      ),
                                    ),
                                    selected: selectedWeekdays.contains(
                                      index + 1,
                                    ),
                                    onSelected: (selected) {
                                      setDialogState(() {
                                        final day = index + 1;
                                        if (selected) {
                                          selectedWeekdays.add(day);
                                        } else {
                                          selectedWeekdays.remove(day);
                                        }
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(_tr('cancel')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(_tr('save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (approved != true) return null;

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final amount = double.tryParse(amountController.text.trim());
    final duration = int.tryParse(durationController.text.trim());
    final country = countryController.text.trim();
    final county = countyController.text.trim();
    final city = cityController.text.trim();
    final startAt = DateTime(
      dueAt.year,
      dueAt.month,
      dueAt.day,
      startTime.hour,
      startTime.minute,
    );

    final resolvedCategoryKey = _normalizeCategoryKey(selectedCategoryKey);

    final recurrence = switch (recurrencePattern) {
      _RecurrencePattern.daily => _tr('recurrenceDaily'),
      _RecurrencePattern.weekly => _tr('recurrenceWeekly'),
      _RecurrencePattern.biWeekly => _tr('recurrenceBiWeekly'),
      _RecurrencePattern.monthly => _tr('recurrenceMonthly'),
      _RecurrencePattern.byDays => [
        if (selectedWeekdays.contains(1)) _tr('weekdayMon'),
        if (selectedWeekdays.contains(2)) _tr('weekdayTue'),
        if (selectedWeekdays.contains(3)) _tr('weekdayWed'),
        if (selectedWeekdays.contains(4)) _tr('weekdayThu'),
        if (selectedWeekdays.contains(5)) _tr('weekdayFri'),
        if (selectedWeekdays.contains(6)) _tr('weekdaySat'),
        if (selectedWeekdays.contains(7)) _tr('weekdaySun'),
      ].join(', '),
    };

    if (title.isEmpty ||
        description.isEmpty ||
        amount == null ||
        amount <= 0 ||
        duration == null ||
        duration <= 0 ||
        country.isEmpty ||
        county.isEmpty ||
        city.isEmpty ||
        resolvedCategoryKey == _fallbackCategoryKey ||
        (isRecurring && recurrence.isEmpty) ||
        startAt.isBefore(DateTime.now())) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_tr('invalidData'))));
      return null;
    }

    final id = 'a${DateTime.now().microsecondsSinceEpoch}';
    return _ActivityItem(
      id: id,
      title: title,
      description: description,
      amountRon: amount,
      isRecurring: isRecurring,
      recurrenceLabel: isRecurring ? recurrence : null,
      mealIncluded: (duration > 4) ? mealIncluded : false,
      posterName: _tr('youLabel'),
      posterRating: 5,
      reviewCount: 0,
      dueAt: startAt,
      createdAt: DateTime.now(),
      country: country,
      county: county,
      city: city,
      durationHours: duration,
      isPostedByCurrentUser: true,
      section: 'services',
      categoryKey: resolvedCategoryKey,
      subcategoryKey: selectedSubcategoryKey,
    );
  }

  Widget _locationSelectionSection(double horizontalPadding) {
    final scheme = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          12,
          horizontalPadding,
          0,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1) Alege locatia ta',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Apasa pe un judet de pe harta, apoi selecteaza localitatea/comuna.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _locationBadge(
                    icon: Icons.map_outlined,
                    text: _selectedCounty == null
                        ? 'Judet nesetat'
                        : 'Judet: $_selectedCounty',
                  ),
                  _locationBadge(
                    icon: Icons.location_city_outlined,
                    text: _selectedCity == null
                        ? 'Localitate nesetata'
                        : 'Localitate: $_selectedCity',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _openServicesMapPage,
                  icon: Icon(
                    _selectedCounty == null
                        ? Icons.map_outlined
                        : Icons.edit_location_alt_rounded,
                  ),
                  label: Text(
                    _selectedCounty == null || _selectedCity == null
                        ? 'Deschide harta serviciilor'
                        : 'Actualizeaza locatia selectata',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationBadge({required IconData icon, required String text}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoriesSection(double horizontalPadding) {
    final scheme = Theme.of(context).colorScheme;
    final categoryLabel = _serviceCategoryLabel(_selectedCategoryKey);

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          12,
          horizontalPadding,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '2) Selecteaza categoria de servicii',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _locationBadge(
                  icon: Icons.map_outlined,
                  text: _selectedCounty ?? 'Judet nesetat',
                ),
                _locationBadge(
                  icon: Icons.place_outlined,
                  text: _selectedCity ?? 'Localitate nesetata',
                ),
                _locationBadge(
                  icon: Icons.category_outlined,
                  text: categoryLabel,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(
                      () => _flowStage = _ServicesFlowStage.location,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Inapoi la harta'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _selectedCounty != null && _selectedCity != null
                        ? _openServicesCategoriesPage
                        : null,
                    icon: Icon(
                      _selectedCategoryKey == _allCategoriesKey
                          ? Icons.category_outlined
                          : Icons.edit_rounded,
                    ),
                    label: Text(
                      _selectedCategoryKey == _allCategoriesKey
                          ? 'Deschide categoriile de servicii'
                          : 'Schimba categoria selectata',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listingHeaderSection(double horizontalPadding) {
    final county = _selectedCounty ?? '-';
    final city = _selectedCity ?? '-';
    final categoryLabel = _serviceCategoryLabel(_selectedCategoryKey);

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          12,
          horizontalPadding,
          0,
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _locationBadge(icon: Icons.map_outlined, text: county),
            _locationBadge(icon: Icons.place_outlined, text: city),
            _locationBadge(icon: Icons.category_outlined, text: categoryLabel),
            OutlinedButton.icon(
              onPressed: _openServicesCategoriesPage,
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Schimba selectia'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPostedActivities() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PostedActivitiesPage(
          lang: _currentLang,
          isDark: _currentIsDark,
          onLangChange: (lang) {
            setState(() => _currentLang = lang);
            widget.onLangChange(lang);
          },
          onThemeChange: (isDark) {
            setState(() => _currentIsDark = isDark);
            widget.onThemeChange(isDark);
          },
          onLogout: widget.onLogout,
          tr: _tr,
          itemsProvider: _postedItems,
          onCreateActivity: _openAddActivityForm,
          assignedProviderFor: (activityId) =>
              _assignedProviderByActivity[activityId],
          onDeleteActivity: _deletePostedActivity,
          onRemoveAssignedProvider: _removeAssignedProvider,
          onSaveEditedActivity: _saveEditedActivity,
          isWarningWindowNoProvider: (item) =>
              _isWarningWindowNoProvider(item, DateTime.now()),
          isClosedNoProvider: (item) =>
              _isClosedNoProvider(item, DateTime.now()),
        ),
      ),
    );
    await _refreshActivitiesFromApi(silent: true);
  }

  Future<void> _openServicesMapPage() async {
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => _ServicesMapPage(
          lang: _currentLang,
          isDark: _currentIsDark,
          onLangChange: (lang) {
            setState(() => _currentLang = lang);
            widget.onLangChange(lang);
          },
          onThemeChange: (isDark) {
            setState(() => _currentIsDark = isDark);
            widget.onThemeChange(isDark);
          },
          onLogout: widget.onLogout,
          initialCounty: _selectedCounty,
          initialCity: _selectedCity,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _selectedCounty = result['county'];
      _selectedCity = result['city'];
      _flowStage = _ServicesFlowStage.categories;
    });

    await _openServicesCategoriesPage();
  }

  Future<void> _openServicesCategoriesPage() async {
    final county = _selectedCounty;
    final city = _selectedCity;
    if (county == null || city == null) return;

    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => _ServicesCategoriesPage(
          lang: _currentLang,
          isDark: _currentIsDark,
          onLangChange: (lang) {
            setState(() => _currentLang = lang);
            widget.onLangChange(lang);
          },
          onThemeChange: (isDark) {
            setState(() => _currentIsDark = isDark);
            widget.onThemeChange(isDark);
          },
          onLogout: widget.onLogout,
          selectedCounty: county,
          selectedCity: city,
          initialCategoryKey: _selectedCategoryKey,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _selectedCategoryKey = _normalizeCategoryKey(result['categoryKey']);
      _flowStage = _ServicesFlowStage.listings;
    });
    await _refreshActivitiesFromApi(silent: true);
  }

  Future<void> _openUpcomingEvents() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _UpcomingEventsPage(
          lang: _currentLang,
          isDark: _currentIsDark,
          onLangChange: (lang) {
            setState(() => _currentLang = lang);
            widget.onLangChange(lang);
          },
          onThemeChange: (isDark) {
            setState(() => _currentIsDark = isDark);
            widget.onThemeChange(isDark);
          },
          onLogout: widget.onLogout,
          tr: _tr,
          itemsProvider: _upcomingItems,
        ),
      ),
    );
    await _refreshActivitiesFromApi(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final activities = _availableItems();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: AuthenticatedPageShell(
        lang: _currentLang,
        isDark: _currentIsDark,
        onLangChange: (lang) {
          setState(() => _currentLang = lang);
          widget.onLangChange(lang);
        },
        onThemeChange: (isDark) {
          setState(() => _currentIsDark = isDark);
          widget.onThemeChange(isDark);
        },
        onLogout: widget.onLogout,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 1100
                ? 32.0
                : constraints.maxWidth >= 760
                ? 20.0
                : 12.0;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(child: _heroSection()),
                ),
                if (_flowStage == _ServicesFlowStage.location)
                  _locationSelectionSection(horizontalPadding),
                if (_flowStage == _ServicesFlowStage.categories)
                  _categoriesSection(horizontalPadding),
                if (_flowStage == _ServicesFlowStage.listings)
                  _listingHeaderSection(horizontalPadding),
                if (_flowStage == _ServicesFlowStage.listings)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyHeaderDelegate(
                      height: _controlSectionHeight(constraints.maxWidth),
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          14,
                          horizontalPadding,
                          8,
                        ),
                        child: _controlSection(constraints.maxWidth),
                      ),
                    ),
                  ),
                if (_flowStage == _ServicesFlowStage.listings && _isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  ),
                if (_flowStage == _ServicesFlowStage.listings &&
                    !_isLoading &&
                    activities.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        10,
                        horizontalPadding,
                        24,
                      ),
                      child: _emptyStateCard(),
                    ),
                  )
                else if (_flowStage == _ServicesFlowStage.listings)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      6,
                      horizontalPadding,
                      24,
                    ),
                    sliver: SliverList.builder(
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        final item = activities[index];
                        final canOpenApplyDialog = !item.isPostedByCurrentUser;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ActivityAnnouncementTile(
                            item: item,
                            lang: _currentLang,
                            isDark: _currentIsDark,
                            tr: _tr,
                            onTap: canOpenApplyDialog
                                ? () => _onTapMarketplaceItem(item)
                                : null,
                            trailingAction: null,
                            disableHoverEffects: !canOpenApplyDialog,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _controlSectionHeight(double maxWidth) => maxWidth < 980 ? 306 : 82;

  Widget _heroSection() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.92),
            scheme.secondary.withValues(alpha: 0.88),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.task_alt_rounded, color: Colors.white),
              ),
              IconButton(
                onPressed: _handleBackNavigation,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                tooltip: _tr('back'),
              ),
              Text(
                _tr('activitiesTitle'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openAddActivityFormGuarded,
                icon: const Icon(Icons.add_rounded),
                label: Text(_tr('addActivity')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.32)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _userRatingPanel(_myPostedActivitiesRating),
              _userRatingPanel(_myProvidedActivitiesRating),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyStateCard() {
    final scheme = Theme.of(context).colorScheme;
    final hasError = _loadErrorMessage != null && _loadErrorMessage!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasError ? _tr('activitiesLoadFailed') : _tr('noActivitiesFound'),
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 6),
            Text(
              _loadErrorMessage!,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => unawaited(_refreshActivitiesFromApi()),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_tr('retry')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _userRatingPanel(_DualRating rating) {
    final displayRating = rating.reviewCount == 0 ? 5.0 : rating.rating;

    return Container(
      constraints: const BoxConstraints(minWidth: 215),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr(rating.labelKey),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _RatingStars(rating: displayRating, starSize: 16),
              const SizedBox(width: 6),
              Text(
                displayRating.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${rating.reviewCount})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controlSection(double maxWidth) {
    final scheme = Theme.of(context).colorScheme;
    final compact = maxWidth < 980;

    final controls = [
      SizedBox(
        width: 210,
        height: 46,
        child: ElevatedButton.icon(
          onPressed: _openAddActivityFormGuarded,
          icon: const Icon(Icons.add_rounded),
          label: Text(_tr('addActivity'), overflow: TextOverflow.ellipsis),
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      SizedBox(
        width: 210,
        height: 46,
        child: OutlinedButton.icon(
          onPressed: _openPostedActivities,
          icon: const Icon(Icons.assignment_rounded),
          label: Text(_tr('postedActivities'), overflow: TextOverflow.ellipsis),
        ),
      ),
      SizedBox(
        width: 210,
        height: 46,
        child: OutlinedButton.icon(
          onPressed: _openUpcomingEvents,
          icon: const Icon(Icons.event_available_rounded),
          label: Text(_tr('upcomingEvents'), overflow: TextOverflow.ellipsis),
        ),
      ),
      SizedBox(
        width: 220,
        height: 46,
        child: DropdownButtonFormField<_ActivityFilter>(
          initialValue: _selectedFilter,
          isExpanded: true,
          decoration: _dropdownDecoration(scheme),
          items: [
            DropdownMenuItem(
              value: _ActivityFilter.all,
              child: Text(
                _tr('allActivities'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: _ActivityFilter.recurring,
              child: Text(
                _tr('recurringActivities'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: _ActivityFilter.oneTime,
              child: Text(
                _tr('oneTimeActivities'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedFilter = value);
            unawaited(_refreshActivitiesFromApi(silent: true));
          },
        ),
      ),
      SizedBox(
        width: 220,
        height: 46,
        child: DropdownButtonFormField<_SortOption>(
          initialValue: _selectedSort,
          isExpanded: true,
          decoration: _dropdownDecoration(scheme),
          items: [
            DropdownMenuItem(
              value: _SortOption.postedDesc,
              child: Text(
                _tr('sortPostedDesc'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: _SortOption.postedAsc,
              child: Text(
                _tr('sortPostedAsc'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: _SortOption.dueAsc,
              child: Text(_tr('sortDueAsc'), overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: _SortOption.dueDesc,
              child: Text(_tr('sortDueDesc'), overflow: TextOverflow.ellipsis),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedSort = value);
            unawaited(_refreshActivitiesFromApi(silent: true));
          },
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < controls.length; index++) ...[
                  controls[index],
                  if (index < controls.length - 1) const SizedBox(height: 8),
                ],
              ],
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < controls.length; index++) ...[
                    controls[index],
                    if (index < controls.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
    );
  }

  InputDecoration _dropdownDecoration(ColorScheme scheme) {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.8)),
      ),
    );
  }
}

class _ActivityAnnouncementTile extends StatefulWidget {
  final _ActivityItem item;
  final String lang;
  final bool isDark;
  final String Function(String key) tr;
  final VoidCallback? onTap;
  final Widget? trailingAction;
  final _AssignedProvider? assignedProvider;
  final VoidCallback? onRemoveAssignedProvider;
  final bool disableHoverEffects;
  final Color? backgroundOverride;

  const _ActivityAnnouncementTile({
    required this.item,
    required this.lang,
    required this.isDark,
    required this.tr,
    required this.onTap,
    required this.trailingAction,
    this.assignedProvider,
    this.onRemoveAssignedProvider,
    this.disableHoverEffects = false,
    this.backgroundOverride,
  });

  @override
  State<_ActivityAnnouncementTile> createState() =>
      _ActivityAnnouncementTileState();
}

class _ActivityAnnouncementTileState extends State<_ActivityAnnouncementTile> {
  bool _hovered = false;

  String _tr(String key) => widget.tr(key);

  String _formatDate(DateTime date) {
    final monthKey = 'monthName${date.month.toString().padLeft(2, '0')}';
    return '${date.day} ${t(widget.lang, monthKey)}';
  }

  String _formatTime(DateTime date) {
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff <= 0) return _tr('today');
    if (diff == 1) return _tr('yesterday');

    final template = _tr('daysAgoTemplate');
    return template.replaceAll('{days}', diff.toString());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isInteractive = widget.onTap != null;
    final hoverEnabled = !widget.disableHoverEffects && isInteractive;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        final priceText = widget.item.isRecurring
            ? '${widget.item.amountRon.toStringAsFixed(0)} RON / ${_tr('perDay')}'
            : '${widget.item.amountRon.toStringAsFixed(0)} RON';

        final tileContent = Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.backgroundOverride ?? scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? scheme.primary.withValues(alpha: 0.45)
                  : scheme.outline.withValues(alpha: 0.16),
              width: _hovered ? 1.3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: _hovered ? 0.16 : 0.08),
                blurRadius: _hovered ? 18 : 12,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _leftPane(priceText, compact),
                        const SizedBox(height: 12),
                        _centerPane(compact),
                        const SizedBox(height: 12),
                        _rightPane(compact),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _leftPane(priceText, compact),
                        const SizedBox(width: 16),
                        Expanded(child: _centerPane(compact)),
                        const SizedBox(width: 16),
                        _rightPane(compact),
                      ],
                    ),
              if (widget.assignedProvider != null) ...[
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: scheme.outline.withValues(alpha: 0.22),
                ),
                const SizedBox(height: 10),
                _assignedProviderSection(
                  widget.assignedProvider!,
                  onRemoveAssignedProvider: widget.onRemoveAssignedProvider,
                ),
              ],
            ],
          ),
        );

        return MouseRegion(
          cursor: isInteractive
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) {
            if (hoverEnabled) {
              setState(() => _hovered = true);
            }
          },
          onExit: (_) {
            if (hoverEnabled) {
              setState(() => _hovered = false);
            }
          },
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              scale: _hovered && hoverEnabled ? 1.01 : 1,
              child: Stack(
                children: [
                  tileContent,
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                        child: SizedBox(
                          height: 3,
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOut,
                            alignment: _hovered
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              width: 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [scheme.primary, scheme.secondary],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _leftPane(String priceText, bool compact) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: compact ? double.infinity : 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            priceText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 26 : 30,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          CircleAvatar(
            radius: 34,
            backgroundColor: scheme.primary.withValues(alpha: 0.14),
            child: Text(
              widget.item.posterName.characters.first,
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerPane(bool compact) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.item.title,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          widget.item.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.84),
            fontSize: 21,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              widget.item.posterName,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                height: 1,
              ),
            ),
            _infoBadge(icon: Icons.payments_rounded, label: _tr('payerBadge')),
            _RatingStars(rating: widget.item.posterRating, starSize: 16),
            Text(
              widget.item.posterRating.toStringAsFixed(2),
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 17,
                height: 1,
              ),
            ),
            Text(
              '(${widget.item.reviewCount})',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
                fontSize: 17,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _infoBadge(
              icon: Icons.category_rounded,
              label: _serviceCategoryLabel(widget.item.categoryKey),
            ),
            if (widget.item.subcategoryKey != null &&
                widget.item.subcategoryKey!.isNotEmpty)
              _infoBadge(
                icon: Icons.label_outline_rounded,
                label: _serviceSubcategoryLabel(
                  widget.item.categoryKey,
                  widget.item.subcategoryKey,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 16,
              color: scheme.onSurface.withValues(alpha: 0.68),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${widget.item.country}, ${widget.item.county}, ${widget.item.city}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.74),
                  fontSize: 18,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _rightPane(bool compact) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: compact ? double.infinity : 260,
      child: Column(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          if (widget.trailingAction != null) ...[
            Align(
              alignment: compact ? Alignment.centerLeft : Alignment.centerRight,
              child: widget.trailingAction!,
            ),
            const SizedBox(height: 4),
          ],
          Text(
            _formatDate(widget.item.dueAt),
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 21,
              height: 1,
            ),
            textAlign: compact ? TextAlign.start : TextAlign.end,
          ),
          const SizedBox(height: 4),
          Text(
            '${_tr('startTime')}: ${_formatTime(widget.item.dueAt)}',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1,
            ),
            textAlign: compact ? TextAlign.start : TextAlign.end,
          ),
          const SizedBox(height: 4),
          Text(
            '${_tr('postedLabel')}: ${_formatRelativeDate(widget.item.createdAt)}',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.58),
              fontSize: 18,
              height: 1,
            ),
            textAlign: compact ? TextAlign.start : TextAlign.end,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              if (widget.item.isRecurring)
                _infoBadge(
                  icon: Icons.repeat_rounded,
                  label: widget.item.recurrenceLabel ?? _tr('recurringDefault'),
                ),
              if (widget.item.durationHours > 4)
                if (widget.item.mealIncluded)
                  _infoBadge(
                    icon: Icons.restaurant_rounded,
                    label: _tr('mealIncluded'),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBadge({required IconData icon, required String label}) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: scheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _assignedProviderSection(
    _AssignedProvider provider, {
    VoidCallback? onRemoveAssignedProvider,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            child: Text(
              provider.initials,
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${provider.firstName} ${provider.lastName}',
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          _RatingStars(rating: provider.providerRating, starSize: 14),
          const SizedBox(width: 6),
          Text(provider.providerRating.toStringAsFixed(2)),
          const SizedBox(width: 12),
          _infoBadge(
            icon: Icons.work_history_rounded,
            label: _tr('providerBadge'),
          ),
          if (onRemoveAssignedProvider != null) ...[
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: onRemoveAssignedProvider,
              icon: const Icon(Icons.person_remove_alt_1_rounded, size: 16),
              label: Text(_tr('removeProvider')),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  final double rating;
  final double starSize;

  const _RatingStars({required this.rating, required this.starSize});

  @override
  Widget build(BuildContext context) {
    final clamped = rating.clamp(0, 5).toDouble();

    return SizedBox(
      width: starSize * 5,
      height: starSize,
      child: Stack(
        children: [
          Row(
            children: List.generate(
              5,
              (_) => Icon(
                Icons.star_rounded,
                size: starSize,
                color: Colors.amber.withValues(alpha: 0.28),
              ),
            ),
          ),
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: clamped / 5,
              child: Row(
                children: List.generate(
                  5,
                  (_) => Icon(
                    Icons.star_rounded,
                    size: starSize,
                    color: Colors.amber,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _StickyHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}

enum _ActivityFilter { all, recurring, oneTime }

enum _SortOption { postedAsc, postedDesc, dueAsc, dueDesc }

enum _RecurrencePattern { daily, weekly, biWeekly, monthly, byDays }

enum _ServicesFlowStage { location, categories, listings }

const String _allCategoriesKey = 'all_categories';
const String _fallbackCategoryKey = 'other_services';

class _ServiceCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color tint;
  final List<_ServiceSubcategory> subcategories;

  const _ServiceCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.tint,
    this.subcategories = const <_ServiceSubcategory>[],
  });
}

class _ServiceSubcategory {
  final String key;
  final String label;

  const _ServiceSubcategory({required this.key, required this.label});
}

const List<_ServiceCategory> _serviceCategories = [
  _ServiceCategory(
    key: _allCategoriesKey,
    label: 'Toate categoriile',
    icon: Icons.apps_rounded,
    tint: Color(0xFF7F8C8D),
  ),
  _ServiceCategory(
    key: 'home_repairs',
    label: 'Mesteri si reparatii',
    icon: Icons.handyman_rounded,
    tint: Color(0xFF3867D6),
    subcategories: [
      _ServiceSubcategory(key: 'electrice', label: 'Electrice'),
      _ServiceSubcategory(key: 'instalatii', label: 'Instalatii'),
      _ServiceSubcategory(key: 'zugravit', label: 'Zugravit'),
    ],
  ),
  _ServiceCategory(
    key: 'events_entertainment',
    label: 'Evenimente si entertainment',
    icon: Icons.celebration_rounded,
    tint: Color(0xFF20BF6B),
    subcategories: [
      _ServiceSubcategory(key: 'dj', label: 'DJ'),
      _ServiceSubcategory(key: 'mc', label: 'MC / Animator'),
      _ServiceSubcategory(key: 'show', label: 'Show tematic'),
    ],
  ),
  _ServiceCategory(
    key: 'babysitting_childcare',
    label: 'Babysitting si ingrijire copii',
    icon: Icons.child_friendly_rounded,
    tint: Color(0xFFEB3B5A),
    subcategories: [
      _ServiceSubcategory(key: 'ocazional', label: 'Ocazional'),
      _ServiceSubcategory(key: 'program_fix', label: 'Program fix'),
      _ServiceSubcategory(key: 'dupa_scoala', label: 'After-school'),
    ],
  ),
  _ServiceCategory(
    key: 'event_planning',
    label: 'Event planning si organizare',
    icon: Icons.event_note_rounded,
    tint: Color(0xFFF7B731),
    subcategories: [
      _ServiceSubcategory(key: 'nunti', label: 'Nunti'),
      _ServiceSubcategory(key: 'botez', label: 'Botez'),
      _ServiceSubcategory(key: 'corporate', label: 'Corporate'),
    ],
  ),
  _ServiceCategory(
    key: 'photo_video',
    label: 'Foto video',
    icon: Icons.photo_camera_back_rounded,
    tint: Color(0xFF8854D0),
    subcategories: [
      _ServiceSubcategory(key: 'fotograf', label: 'Fotograf'),
      _ServiceSubcategory(key: 'videograf', label: 'Videograf'),
      _ServiceSubcategory(key: 'editare', label: 'Editare media'),
    ],
  ),
  _ServiceCategory(
    key: 'local_artists',
    label: 'Artisti locali',
    icon: Icons.music_note_rounded,
    tint: Color(0xFF0FB9B1),
    subcategories: [
      _ServiceSubcategory(key: 'solist', label: 'Solist'),
      _ServiceSubcategory(key: 'formatie', label: 'Formatie'),
      _ServiceSubcategory(key: 'instrumentist', label: 'Instrumentist'),
    ],
  ),
  _ServiceCategory(
    key: 'tutoring_courses',
    label: 'Meditatii si cursuri',
    icon: Icons.school_rounded,
    tint: Color(0xFF2D98DA),
    subcategories: [
      _ServiceSubcategory(key: 'matematica', label: 'Matematica'),
      _ServiceSubcategory(key: 'limbi_straine', label: 'Limbi straine'),
      _ServiceSubcategory(key: 'programare', label: 'Programare'),
    ],
  ),
  _ServiceCategory(
    key: 'culinary_catering',
    label: 'Culinar si catering',
    icon: Icons.restaurant_menu_rounded,
    tint: Color(0xFFFA8231),
    subcategories: [
      _ServiceSubcategory(
        key: 'catering_eveniment',
        label: 'Catering eveniment',
      ),
      _ServiceSubcategory(key: 'chef_acasa', label: 'Chef la domiciliu'),
      _ServiceSubcategory(key: 'deserturi', label: 'Deserturi artizanale'),
    ],
  ),
  _ServiceCategory(
    key: 'beauty_personal_care',
    label: 'Beauty si ingrijire personala',
    icon: Icons.spa_rounded,
    tint: Color(0xFFFF6B81),
    subcategories: [
      _ServiceSubcategory(key: 'makeup', label: 'Make-up'),
      _ServiceSubcategory(key: 'coafor', label: 'Coafor'),
      _ServiceSubcategory(key: 'manichiura', label: 'Manichiura'),
    ],
  ),
  _ServiceCategory(
    key: 'cleaning_maintenance',
    label: 'Curatenie si intretinere',
    icon: Icons.cleaning_services_rounded,
    tint: Color(0xFF45AAF2),
    subcategories: [
      _ServiceSubcategory(key: 'residential', label: 'Curatenie rezidentiala'),
      _ServiceSubcategory(key: 'birouri', label: 'Curatenie birouri'),
      _ServiceSubcategory(key: 'after_constructor', label: 'Dupa renovare'),
    ],
  ),
  _ServiceCategory(
    key: 'transport_moving',
    label: 'Transport si mutari',
    icon: Icons.local_shipping_rounded,
    tint: Color(0xFF4B6584),
    subcategories: [
      _ServiceSubcategory(key: 'mutari', label: 'Mutari locuinta'),
      _ServiceSubcategory(key: 'livrare', label: 'Livrari rapide'),
      _ServiceSubcategory(
        key: 'transport_persoane',
        label: 'Transport persoane',
      ),
    ],
  ),
  _ServiceCategory(
    key: 'it_digital_services',
    label: 'IT si servicii digitale',
    icon: Icons.computer_rounded,
    tint: Color(0xFF26DE81),
    subcategories: [
      _ServiceSubcategory(key: 'web', label: 'Website / Magazin online'),
      _ServiceSubcategory(key: 'support', label: 'Suport tehnic'),
      _ServiceSubcategory(key: 'design', label: 'Design grafic'),
    ],
  ),
  _ServiceCategory(
    key: 'health_wellness',
    label: 'Sanatate si wellness',
    icon: Icons.health_and_safety_rounded,
    tint: Color(0xFF2ECC71),
    subcategories: [
      _ServiceSubcategory(key: 'masaj', label: 'Masaj'),
      _ServiceSubcategory(key: 'kineto', label: 'Kinetoterapie'),
      _ServiceSubcategory(key: 'fitness', label: 'Antrenor personal'),
    ],
  ),
  _ServiceCategory(
    key: 'pet_services',
    label: 'Servicii pentru animale',
    icon: Icons.pets_rounded,
    tint: Color(0xFF8E44AD),
    subcategories: [
      _ServiceSubcategory(key: 'pet_sitting', label: 'Pet sitting'),
      _ServiceSubcategory(key: 'grooming', label: 'Grooming'),
      _ServiceSubcategory(key: 'pet_transport', label: 'Transport animale'),
    ],
  ),
  _ServiceCategory(
    key: _fallbackCategoryKey,
    label: 'Alte servicii',
    icon: Icons.more_horiz_rounded,
    tint: Color(0xFF95A5A6),
    subcategories: [_ServiceSubcategory(key: 'diverse', label: 'Diverse')],
  ),
];

String _serviceCategoryLabel(String? categoryKey) {
  final key = categoryKey ?? _fallbackCategoryKey;
  final match = _serviceCategories.firstWhere(
    (category) => category.key == key,
    orElse: () => _serviceCategories.last,
  );
  return match.label;
}

List<_ServiceSubcategory> _subcategoriesForCategory(String? categoryKey) {
  if (categoryKey == null || categoryKey == _allCategoriesKey) {
    return const [];
  }

  final match = _serviceCategories.firstWhere(
    (category) => category.key == categoryKey,
    orElse: () => _serviceCategories.last,
  );

  return match.subcategories;
}

String _serviceSubcategoryLabel(String? categoryKey, String? subcategoryKey) {
  if (subcategoryKey == null || subcategoryKey.isEmpty) return '';

  final subcategories = _subcategoriesForCategory(categoryKey);
  for (final subcategory in subcategories) {
    if (subcategory.key == subcategoryKey) {
      return subcategory.label;
    }
  }
  return subcategoryKey;
}

String _servicesTextKey(String key) {
  switch (key) {
    case 'activitiesTitle':
      return 'servicesTitle';
    case 'addActivity':
      return 'addService';
    case 'postedActivities':
      return 'postedServices';
    case 'upcomingEvents':
      return 'upcomingServices';
    case 'allActivities':
      return 'allServices';
    case 'recurringActivities':
      return 'recurringServices';
    case 'oneTimeActivities':
      return 'oneTimeServices';
    case 'deleteActivityTooltip':
      return 'deleteServiceTooltip';
    case 'noPostedActivities':
      return 'noPostedServices';
    case 'noUpcomingActivities':
      return 'noUpcomingServices';
    case 'noActivitiesFound':
      return 'noServicesFound';
    case 'applyDialogTitle':
      return 'applyDialogTitleService';
    case 'applyDialogBody':
      return 'applyDialogBodyService';
    case 'editActivity':
      return 'editService';
    case 'dueDate':
      return 'serviceDate';
    case 'recurringToggle':
      return 'recurringServiceToggle';
    case 'activitiesLoadFailed':
      return 'servicesLoadFailed';
    default:
      return key;
  }
}

class _DualRating {
  final String labelKey;
  final double rating;
  final int reviewCount;

  const _DualRating({
    required this.labelKey,
    required this.rating,
    required this.reviewCount,
  });
}

class _AssignedProvider {
  final String firstName;
  final String lastName;
  final double providerRating;

  const _AssignedProvider({
    required this.firstName,
    required this.lastName,
    required this.providerRating,
  });

  String get initials {
    final first = firstName.isEmpty ? '' : firstName[0];
    final last = lastName.isEmpty ? '' : lastName[0];
    return '$first$last'.toUpperCase();
  }
}

class _ActivityItem {
  final String id;
  final String title;
  final String description;
  final double amountRon;
  final bool isRecurring;
  final String? recurrenceLabel;
  final bool mealIncluded;
  final String posterName;
  final double posterRating;
  final int reviewCount;
  final DateTime dueAt;
  final DateTime createdAt;
  final String country;
  final String county;
  final String city;
  final int durationHours;
  final bool isPostedByCurrentUser;
  final String? status;
  final String? closeReason;
  final String section;
  final String categoryKey;
  final String? subcategoryKey;

  const _ActivityItem({
    required this.id,
    required this.title,
    required this.description,
    required this.amountRon,
    required this.isRecurring,
    this.recurrenceLabel,
    this.mealIncluded = false,
    required this.posterName,
    required this.posterRating,
    required this.reviewCount,
    required this.dueAt,
    required this.createdAt,
    required this.country,
    required this.county,
    required this.city,
    required this.durationHours,
    required this.isPostedByCurrentUser,
    this.status,
    this.closeReason,
    this.section = 'services',
    this.categoryKey = _fallbackCategoryKey,
    this.subcategoryKey,
  });

  _ActivityItem copyWith({
    String? title,
    String? description,
    double? amountRon,
    int? durationHours,
    bool? mealIncluded,
    DateTime? dueAt,
    String? status,
    String? closeReason,
    String? section,
    String? categoryKey,
    String? subcategoryKey,
  }) {
    return _ActivityItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      amountRon: amountRon ?? this.amountRon,
      isRecurring: isRecurring,
      recurrenceLabel: recurrenceLabel,
      mealIncluded: mealIncluded ?? this.mealIncluded,
      posterName: posterName,
      posterRating: posterRating,
      reviewCount: reviewCount,
      dueAt: dueAt ?? this.dueAt,
      createdAt: createdAt,
      country: country,
      county: county,
      city: city,
      durationHours: durationHours ?? this.durationHours,
      isPostedByCurrentUser: isPostedByCurrentUser,
      status: status ?? this.status,
      closeReason: closeReason ?? this.closeReason,
      section: section ?? this.section,
      categoryKey: categoryKey ?? this.categoryKey,
      subcategoryKey: subcategoryKey ?? this.subcategoryKey,
    );
  }
}

class _ActivityNotification {
  final String title;
  final String description;
  final String category;
  final String type;
  final DateTime sentAt;

  const _ActivityNotification({
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    required this.sentAt,
  });

  DateTime get sentDate => DateTime(sentAt.year, sentAt.month, sentAt.day);

  TimeOfDay get sentTime => TimeOfDay.fromDateTime(sentAt);
}
