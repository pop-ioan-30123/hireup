part of 'package:careersuitup/pages/services/services_page.dart';

class _PostedActivitiesPage extends StatefulWidget {
  final String lang;
  final bool isDark;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final Future<void> Function() onLogout;
  final String Function(String key) tr;
  final List<_ActivityItem> Function() itemsProvider;
  final Future<void> Function() onCreateActivity;
  final _AssignedProvider? Function(String activityId) assignedProviderFor;
  final Future<void> Function(String activityId) onDeleteActivity;
  final Future<void> Function(String activityId) onRemoveAssignedProvider;
  final Future<void> Function(_ActivityItem updated) onSaveEditedActivity;
  final bool Function(_ActivityItem item) isWarningWindowNoProvider;
  final bool Function(_ActivityItem item) isClosedNoProvider;

  const _PostedActivitiesPage({
    required this.lang,
    required this.isDark,
    required this.onLangChange,
    required this.onThemeChange,
    required this.onLogout,
    required this.tr,
    required this.itemsProvider,
    required this.onCreateActivity,
    required this.assignedProviderFor,
    required this.onDeleteActivity,
    required this.onRemoveAssignedProvider,
    required this.onSaveEditedActivity,
    required this.isWarningWindowNoProvider,
    required this.isClosedNoProvider,
  });

  @override
  State<_PostedActivitiesPage> createState() => _PostedActivitiesPageState();
}

class _PostedActivitiesPageState extends State<_PostedActivitiesPage> {
  late String _lang;
  late bool _isDark;
  Timer? _statusTicker;

  String _formatPostedTimeOfDay(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  void initState() {
    super.initState();
    _lang = widget.lang;
    _isDark = widget.isDark;
    _statusTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _statusTicker?.cancel();
    super.dispose();
  }

  String _tr(String key) => t(_lang, _servicesTextKey(key));

  _RecurrencePattern _patternFromLabel(String? label) {
    final value = label?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return _RecurrencePattern.weekly;

    if (value.contains('zilnic') || value.contains('daily')) {
      return _RecurrencePattern.daily;
    }
    if (value.contains('2 săptăm') ||
        value.contains('2 saptam') ||
        value.contains('every 2 week')) {
      return _RecurrencePattern.biWeekly;
    }
    if (value.contains('lunar') || value.contains('monthly')) {
      return _RecurrencePattern.monthly;
    }

    const byDaysHints = [
      'luni',
      'marți',
      'marti',
      'miercuri',
      'joi',
      'vineri',
      'sâmbătă',
      'sambata',
      'duminică',
      'duminica',
      'mon',
      'tue',
      'wed',
      'thu',
      'fri',
      'sat',
      'sun',
    ];
    if (byDaysHints.any(value.contains)) {
      return _RecurrencePattern.byDays;
    }

    return _RecurrencePattern.weekly;
  }

  Set<int> _weekdaysFromLabel(String? label) {
    final value = label?.trim().toLowerCase() ?? '';
    final selected = <int>{};

    if (value.contains('luni') || value.contains('mon')) selected.add(1);
    if (value.contains('marți') ||
        value.contains('marti') ||
        value.contains('tue')) {
      selected.add(2);
    }
    if (value.contains('miercuri') || value.contains('wed')) selected.add(3);
    if (value.contains('joi') || value.contains('thu')) selected.add(4);
    if (value.contains('vineri') || value.contains('fri')) selected.add(5);
    if (value.contains('sâmbătă') ||
        value.contains('sambata') ||
        value.contains('sat')) {
      selected.add(6);
    }
    if (value.contains('duminică') ||
        value.contains('duminica') ||
        value.contains('sun')) {
      selected.add(7);
    }

    if (selected.isEmpty) {
      selected.add(DateTime.now().weekday);
    }
    return selected;
  }

  Future<void> _editActivity(_ActivityItem item) async {
    final titleController = TextEditingController(text: item.title);
    final descriptionController = TextEditingController(text: item.description);
    final amountController = TextEditingController(
      text: item.amountRon.toStringAsFixed(0),
    );
    final durationController = TextEditingController(
      text: item.durationHours.toString(),
    );
    var dueAt = item.dueAt;
    var startTime = TimeOfDay.fromDateTime(item.dueAt);
    var mealIncluded = item.mealIncluded;
    var isRecurring = item.isRecurring;
    var recurrencePattern = _patternFromLabel(item.recurrenceLabel);
    final selectedWeekdays = _weekdaysFromLabel(item.recurrenceLabel);

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(_tr('editActivity')),
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
                    decoration: InputDecoration(labelText: _tr('description')),
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
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2032, 12, 31),
                            initialDate: dueAt,
                          );
                          if (picked == null) return;
                          setDialogState(() {
                            dueAt = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              startTime.hour,
                              startTime.minute,
                            );
                          });
                        },
                        child: Text(_tr('chooseDate')),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_tr('startTime')}: ${_formatPostedTimeOfDay(startTime)}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: startTime,
                          );
                          if (picked == null) return;
                          setDialogState(() {
                            startTime = picked;
                            dueAt = DateTime(
                              dueAt.year,
                              dueAt.month,
                              dueAt.day,
                              startTime.hour,
                              startTime.minute,
                            );
                          });
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
          ),
        );
      },
    );

    if (approved != true) return;

    final parsedAmount = double.tryParse(amountController.text.trim());
    final parsedDuration = int.tryParse(durationController.text.trim());
    final startAt = DateTime(
      dueAt.year,
      dueAt.month,
      dueAt.day,
      startTime.hour,
      startTime.minute,
    );
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

    if (parsedAmount == null ||
        parsedDuration == null ||
        parsedDuration <= 0 ||
        (isRecurring && recurrence.isEmpty) ||
        startAt.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_tr('invalidData'))));
      return;
    }

    final updated = _ActivityItem(
      id: item.id,
      section: item.section,
      categoryKey: item.categoryKey,
      subcategoryKey: item.subcategoryKey,
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      amountRon: parsedAmount,
      isRecurring: isRecurring,
      recurrenceLabel: isRecurring ? recurrence : null,
      mealIncluded: parsedDuration > 4 ? mealIncluded : false,
      posterName: item.posterName,
      posterRating: item.posterRating,
      reviewCount: item.reviewCount,
      dueAt: startAt,
      createdAt: item.createdAt,
      country: item.country,
      county: item.county,
      city: item.city,
      durationHours: parsedDuration,
      isPostedByCurrentUser: item.isPostedByCurrentUser,
      status: item.status,
      closeReason: item.closeReason,
    );

    await widget.onSaveEditedActivity(updated);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = widget.itemsProvider();

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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: _tr('back'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _tr('postedActivities'),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await widget.onCreateActivity();
                  if (!mounted) return;
                  setState(() {});
                },
                icon: const Icon(Icons.add_rounded),
                label: Text(_tr('addActivity')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(_tr('noPostedActivities'))
          else
            ...items.map((item) {
              final assigned = widget.assignedProviderFor(item.id);
              final inWarningWindow = widget.isWarningWindowNoProvider(item);
              final isClosed = widget.isClosedNoProvider(item);

              final tileColor = assigned != null
                  ? Color.lerp(
                      Colors.green.withValues(alpha: 0.28),
                      Theme.of(context).colorScheme.surface,
                      0.32,
                    )
                  : inWarningWindow || isClosed
                  ? Color.lerp(
                      Colors.red.withValues(alpha: isClosed ? 0.28 : 0.18),
                      Theme.of(context).colorScheme.surface,
                      0.3,
                    )
                  : null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ActivityAnnouncementTile(
                      item: item,
                      lang: _lang,
                      isDark: _isDark,
                      tr: _tr,
                      backgroundOverride: tileColor,
                      assignedProvider: assigned,
                      onRemoveAssignedProvider: assigned != null
                          ? () async {
                              await widget.onRemoveAssignedProvider(item.id);
                              if (!mounted) return;
                              setState(() {});
                            }
                          : null,
                      disableHoverEffects: assigned != null || isClosed,
                      onTap: () {
                        if (assigned == null && !isClosed) {
                          _editActivity(item);
                        }
                      },
                      trailingAction: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () async {
                              await widget.onDeleteActivity(item.id);
                              if (!mounted) return;
                              setState(() {});
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                            tooltip: _tr('deleteActivityTooltip'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
