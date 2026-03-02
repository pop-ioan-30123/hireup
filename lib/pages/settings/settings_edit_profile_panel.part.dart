part of '../settings_page.dart';

extension _SettingsEditProfilePanel on _SettingsPageState {
  void setState(VoidCallback fn) => _setSettingsState(fn);

  Widget _buildEditProfilePanel() {
    final accountType = profileData?['accountType'] as String? ?? 'user';
    final user = profileData?['user'] as Map<String, dynamic>? ?? {};
    final companyProfile =
        profileData?['companyProfile'] as Map<String, dynamic>? ?? {};

    final sectionOrder = accountType == 'user'
        ? const [
            'account',
            'location',
            'profile',
            'experience',
            'skills',
            'education',
            'projects',
            'social',
            'attachments',
          ]
        : const ['account', 'company', 'hr'];
    final selectedSectionId = _selectedEditProfileSubcategory;

    bool showSection(String id) {
      if (selectedSectionId == null) return true;
      if (id == 'skills' && selectedSectionId.startsWith('skills_')) {
        return true;
      }
      return selectedSectionId == id;
    }

    for (int index = 0; index < sectionOrder.length; index += 1) {
      final sectionId = sectionOrder[index];
      _editProfileSectionExpanded.putIfAbsent(sectionId, () => index == 0);
    }

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white,
                foregroundImage: avatarBytes != null
                    ? MemoryImage(avatarBytes!)
                    : null,
                child: avatarBytes == null
                    ? const Icon(
                        Icons.person,
                        color: Colors.deepPurple,
                        size: 30,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t(widget.lang, 'settings'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (showSection('account'))
            _groupedSection(
              id: 'account',
              title: t(widget.lang, 'accountDetails'),
              children: [
                _readOnlyRow(
                  t(widget.lang, 'first'),
                  user['firstName']?.toString() ?? '-',
                  alwaysOpen: true,
                ),
                _readOnlyRow(
                  t(widget.lang, 'last'),
                  user['lastName']?.toString() ?? '-',
                  alwaysOpen: true,
                ),
                _readOnlyRow(
                  t(widget.lang, 'email'),
                  user['email']?.toString() ?? '-',
                  alwaysOpen: true,
                ),
                _readOnlyRow(
                  t(widget.lang, 'profilePhoto'),
                  avatarBytes != null
                      ? t(widget.lang, 'photoSet')
                      : t(widget.lang, 'photoMissing'),
                  alwaysOpen: true,
                ),
                _readOnlyRow(
                  t(widget.lang, 'password'),
                  '********',
                  alwaysLocked: true,
                  obscure: true,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          t(widget.lang, 'gender'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<String>(
                          initialValue: accountGender,
                          menuMaxHeight: 280,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'male',
                              child: Text(t(widget.lang, 'genderMale')),
                            ),
                            DropdownMenuItem(
                              value: 'female',
                              child: Text(t(widget.lang, 'genderFemale')),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => accountGender = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      _visibilityToggle(visibilityKey: 'showGender'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          t(widget.lang, 'birthDate'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: InkWell(
                          onTap: _pickAccountBirthDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              hintText: t(widget.lang, 'pickBirthDate'),
                              suffixIcon: const Icon(Icons.calendar_month),
                            ),
                            child: Text(
                              accountBirthDate == null
                                  ? t(widget.lang, 'pickBirthDate')
                                  : _formatBirthDate(accountBirthDate!),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _visibilityToggle(visibilityKey: 'showBirthDate'),
                    ],
                  ),
                ),
                _readOnlyVisibilityRow(
                  label: t(widget.lang, 'accountCreatedDate'),
                  value: accountCreatedAt == null
                      ? '-'
                      : _formatDateDisplay(accountCreatedAt!),
                  visibilityKey: 'showAccountCreatedDate',
                  disabled: true,
                ),
                _readOnlyVisibilityRow(
                  label: t(widget.lang, 'accountCreatedTime'),
                  value: accountCreatedAt == null
                      ? '-'
                      : _formatTimeDisplay(accountCreatedAt!),
                  visibilityKey: 'showAccountCreatedTime',
                  disabled: true,
                ),
              ],
            ),

          if (accountType == 'user') ...[
            if (showSection('location')) const SizedBox(height: 16),
            if (showSection('location')) _groupedSection(
              id: 'location',
              title: t(widget.lang, 'locationDetails'),
              children: [
                _phoneRow(),
                _dropdownRow(
                  label: t(widget.lang, 'country'),
                  visibilityKey: 'showCountry',
                  child: DropdownMenu<String>(
                    initialSelection: userCountry,
                    width: double.infinity,
                    menuHeight: 280,
                    enabled: false,
                    dropdownMenuEntries: RomaniaLocations.countries
                        .map(
                          (value) =>
                              DropdownMenuEntry(value: value, label: value),
                        )
                        .toList(),
                    onSelected: null,
                  ),
                ),
                _dropdownRow(
                  label: t(widget.lang, 'county'),
                  visibilityKey: 'showCounty',
                  child: DropdownMenu<String>(
                    key: ValueKey('settings_county_${userCounty ?? 'none'}'),
                    initialSelection: userCounty,
                    width: double.infinity,
                    menuHeight: 280,
                    enableSearch: true,
                    enableFilter: true,
                    requestFocusOnTap: true,
                    dropdownMenuEntries: RomaniaLocations.counties
                        .map(
                          (value) =>
                              DropdownMenuEntry(value: value, label: value),
                        )
                        .toList(),
                    onSelected: (value) {
                      setState(() {
                        userCounty = value;
                        userCity = null;
                      });
                    },
                  ),
                ),
                _dropdownRow(
                  label: t(widget.lang, 'city'),
                  visibilityKey: 'showCity',
                  child: DropdownMenu<String>(
                    key: ValueKey('settings_city_${userCounty ?? 'none'}'),
                    initialSelection: userCity,
                    width: double.infinity,
                    menuHeight: 280,
                    enableSearch: true,
                    enableFilter: true,
                    requestFocusOnTap: true,
                    dropdownMenuEntries:
                        RomaniaLocations.localitiesForCounty(userCounty)
                            .map(
                              (value) =>
                                  DropdownMenuEntry(value: value, label: value),
                            )
                            .toList(),
                    onSelected: (value) => setState(() => userCity = value),
                  ),
                ),
              ],
            ),
            if (showSection('profile')) const SizedBox(height: 16),
            if (showSection('profile')) _groupedSection(
              id: 'profile',
              title: t(widget.lang, 'profileDetails'),
              children: [
                _editableRow(
                  label: t(widget.lang, 'professionalTitle'),
                  controller: professionalTitleCtrl,
                  visibilityKey: 'showJobTitle',
                ),
                _dropdownRow(
                  label: t(widget.lang, 'professionalStatus'),
                  visibilityKey: 'showProfessionalStatus',
                  child: DropdownMenu<String>(
                    key: ValueKey(
                      'settings_prof_status_${userProfessionalStatus ?? 'none'}',
                    ),
                    initialSelection: userProfessionalStatus,
                    width: double.infinity,
                    menuHeight: 280,
                    dropdownMenuEntries: _professionalStatusEntries,
                    onSelected: (value) =>
                        setState(() => userProfessionalStatus = value),
                  ),
                ),
                _editableRow(
                  label: t(widget.lang, 'yearsExperience'),
                  controller: yearsExperienceCtrl,
                  visibilityKey: 'showYearsExperience',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                ),
                _editableRow(
                  label: t(widget.lang, 'profileSummary'),
                  controller: profileSummaryCtrl,
                  visibilityKey: 'showProfileSummary',
                  maxLines: 4,
                ),
              ],
            ),
            if (showSection('experience')) const SizedBox(height: 16),
            if (showSection('experience')) _groupedSection(
              id: 'experience',
              title: t(widget.lang, 'experienceSection'),
              children: _buildExperienceEditorSection(),
            ),
            if (showSection('skills')) const SizedBox(height: 16),
            if (showSection('skills')) _groupedSection(
              id: 'skills',
              title: t(widget.lang, 'skillsSection'),
              children: _buildSkillsEditorSection(selectedSectionId),
            ),
            if (showSection('education')) const SizedBox(height: 16),
            if (showSection('education')) _groupedSection(
              id: 'education',
              title: t(widget.lang, 'educationSection'),
              children: _buildEducationEditorSection(),
            ),
            if (showSection('projects')) const SizedBox(height: 16),
            if (showSection('projects')) _groupedSection(
              id: 'projects',
              title: t(widget.lang, 'projectsSection'),
              children: _buildProjectsEditorSection(),
            ),
            if (showSection('social')) const SizedBox(height: 16),
            if (showSection('social')) _groupedSection(
              id: 'social',
              title: t(widget.lang, 'socialLinks'),
              children: [
                _editableRow(
                  label: 'LinkedIn',
                  controller: linkedInCtrl,
                  visibilityKey: 'showLinkedIn',
                  keyboardType: TextInputType.url,
                ),
                _editableRow(
                  label: 'GitHub',
                  controller: githubCtrl,
                  visibilityKey: 'showGithub',
                  keyboardType: TextInputType.url,
                ),
                _editableRow(
                  label: 'YouTube',
                  controller: youtubeCtrl,
                  visibilityKey: 'showYoutube',
                  keyboardType: TextInputType.url,
                ),
                _editableRow(
                  label: 'Instagram',
                  controller: instagramCtrl,
                  visibilityKey: 'showInstagram',
                  keyboardType: TextInputType.url,
                ),
                _editableRow(
                  label: 'TikTok',
                  controller: tiktokCtrl,
                  visibilityKey: 'showTiktok',
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
            if (showSection('attachments')) const SizedBox(height: 14),
            if (showSection('attachments')) _groupedSection(
              id: 'attachments',
              title: t(widget.lang, 'attachments'),
              children: [
                Row(
                  children: [
                    Expanded(child: Text(t(widget.lang, 'cvAttachmentSection'))),
                    ElevatedButton(
                      onPressed: _uploadCv,
                      child: Text(t(widget.lang, 'uploadCv')),
                    ),
                    const SizedBox(width: 10),
                    _visibilityToggle(visibilityKey: 'showCv'),
                  ],
                ),
              ],
            ),
          ],

          if (accountType == 'company') ...[
            if (showSection('company')) const SizedBox(height: 16),
            if (showSection('company')) _groupedSection(
              id: 'company',
              title: t(widget.lang, 'companyDetails'),
              children: [
                _editableRow(
                  label: t(widget.lang, 'companyName'),
                  controller: companyNameCtrl,
                  visibilityKey: 'showCompanyName',
                ),
                _editableRow(
                  label: t(widget.lang, 'county'),
                  controller: companyCountyCtrl,
                  visibilityKey: 'showCompanyCounty',
                ),
                _editableRow(
                  label: t(widget.lang, 'city'),
                  controller: companyCityCtrl,
                  visibilityKey: 'showCompanyCity',
                ),
              ],
            ),
            if (showSection('hr')) const SizedBox(height: 16),
            if (showSection('hr')) _groupedSection(
              id: 'hr',
              title: t(widget.lang, 'hrDetails'),
              children: [
                _readOnlyRow(
                  t(widget.lang, 'hrFirstName'),
                  companyProfile['hrFirstName']?.toString() ?? '-',
                  alwaysOpen: true,
                ),
                _readOnlyRow(
                  t(widget.lang, 'hrLastName'),
                  companyProfile['hrLastName']?.toString() ?? '-',
                  alwaysOpen: true,
                ),
                _readOnlyRow(
                  t(widget.lang, 'hrEmail'),
                  companyProfile['hrEmail']?.toString() ?? '-',
                  alwaysOpen: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildExperienceEditorSection() {
    final monthOptions = List<int>.generate(12, (index) => index + 1);
    final yearOptions = _experienceYearOptions;

    final widgets = <Widget>[
      Text(
        t(widget.lang, 'experienceMaxThreeHint'),
        style: TextStyle(color: Theme.of(context).hintColor),
      ),
      const SizedBox(height: 10),
    ];

    if (_experienceDrafts.isEmpty) {
      widgets.add(
        Text(
          t(widget.lang, 'experienceEmptyState'),
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }

    for (int index = 0; index < _experienceDrafts.length; index += 1) {
      final experience = _experienceDrafts[index];
      final endYearOptions = _endYearOptionsFor(experience.startYear);
      final currentEndYear = experience.endYear;
      final endMonthOptions = _endMonthOptionsFor(
        startYear: experience.startYear,
        startMonth: experience.startMonth,
        endYear: currentEndYear,
      );
      widgets.add(
        Container(
          key: ValueKey('experience_card_${experience.id}'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${t(widget.lang, 'experienceItemLabel')} ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _entryVisibilityToggle(
                    isOpen: experience.showOnProfile,
                    onChanged: (value) =>
                        setState(() => experience.showOnProfile = value),
                  ),
                  IconButton(
                    onPressed: () => _removeExperienceDraft(experience),
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: t(widget.lang, 'delete'),
                  ),
                ],
              ),
              TextField(
                controller: experience.companyCtrl,
                decoration: InputDecoration(
                  labelText: t(widget.lang, 'companyName'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: experience.positionCtrl,
                decoration: InputDecoration(
                  labelText: t(widget.lang, 'professionalTitle'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: experience.descriptionCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: t(widget.lang, 'experienceShortDescription'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownMenu<int>(
                      key: ValueKey('experience_start_month_${experience.id}'),
                      initialSelection: experience.startMonth,
                      width: double.infinity,
                      menuHeight: 280,
                      label: Text(t(widget.lang, 'startMonth')),
                      inputDecorationTheme: const InputDecorationTheme(
                        border: OutlineInputBorder(),
                      ),
                      dropdownMenuEntries: monthOptions
                          .map(
                            (month) => DropdownMenuEntry(
                              value: month,
                              label: _monthOptionLabel(month),
                            ),
                          )
                          .toList(growable: false),
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          experience.startMonth = value;
                          if (_isEndDateBeforeStart(
                            startMonth: experience.startMonth,
                            startYear: experience.startYear,
                            endMonth: experience.endMonth,
                            endYear: experience.endYear,
                          )) {
                            experience.endYear = experience.startYear;
                            experience.endMonth = experience.startMonth;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownMenu<int>(
                      key: ValueKey('experience_start_year_${experience.id}'),
                      initialSelection: experience.startYear,
                      width: double.infinity,
                      menuHeight: 280,
                      label: Text(t(widget.lang, 'startYear')),
                      inputDecorationTheme: const InputDecorationTheme(
                        border: OutlineInputBorder(),
                      ),
                      dropdownMenuEntries: yearOptions
                          .map(
                            (year) => DropdownMenuEntry(
                              value: year,
                              label: year.toString(),
                            ),
                          )
                          .toList(growable: false),
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          experience.startYear = value;
                          if (_isEndDateBeforeStart(
                            startMonth: experience.startMonth,
                            startYear: experience.startYear,
                            endMonth: experience.endMonth,
                            endYear: experience.endYear,
                          )) {
                            experience.endYear = experience.startYear;
                            experience.endMonth = experience.startMonth;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: experience.isCurrent,
                title: Text(t(widget.lang, 'experienceCurrentRole')),
                onChanged: (value) {
                  setState(() {
                    experience.isCurrent = value;
                    if (value) {
                      experience.endMonth = null;
                      experience.endYear = null;
                    } else {
                      experience.endMonth ??= experience.startMonth;
                      experience.endYear ??= experience.startYear;
                    }
                  });
                },
              ),
              if (!experience.isCurrent)
                Row(
                  children: [
                    Expanded(
                      child: DropdownMenu<int>(
                        key: ValueKey('experience_end_month_${experience.id}'),
                        initialSelection: experience.endMonth,
                        width: double.infinity,
                        menuHeight: 280,
                        label: Text(t(widget.lang, 'endMonth')),
                        inputDecorationTheme: const InputDecorationTheme(
                          border: OutlineInputBorder(),
                        ),
                        dropdownMenuEntries: endMonthOptions
                            .map(
                              (month) => DropdownMenuEntry(
                                value: month,
                                label: _monthOptionLabel(month),
                              ),
                            )
                            .toList(growable: false),
                        onSelected: (value) {
                          if (value == null) return;
                          setState(() => experience.endMonth = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownMenu<int>(
                        key: ValueKey('experience_end_year_${experience.id}'),
                        initialSelection: experience.endYear,
                        width: double.infinity,
                        menuHeight: 280,
                        label: Text(t(widget.lang, 'endYear')),
                        inputDecorationTheme: const InputDecorationTheme(
                          border: OutlineInputBorder(),
                        ),
                        dropdownMenuEntries: endYearOptions
                            .map(
                              (year) => DropdownMenuEntry(
                                value: year,
                                label: year.toString(),
                              ),
                            )
                            .toList(growable: false),
                        onSelected: (value) {
                          if (value == null) return;
                          setState(() {
                            experience.endYear = value;
                            final validMonths = _endMonthOptionsFor(
                              startYear: experience.startYear,
                              startMonth: experience.startMonth,
                              endYear: experience.endYear,
                            );
                            if (!validMonths.contains(experience.endMonth)) {
                              experience.endMonth = validMonths.first;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    widgets.add(
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
            onPressed: _experienceDrafts.length >= _SettingsPageState._maxExperienceDrafts
              ? null
              : _addExperienceDraft,
          icon: const Icon(Icons.add_rounded),
          label: Text(t(widget.lang, 'addExperienceItem')),
        ),
      ),
    );

    return widgets;
  }

  List<Widget> _buildEducationEditorSection() {
    final monthOptions = List<int>.generate(12, (index) => index + 1);
    final yearOptions = _experienceYearOptions;

    final widgets = <Widget>[
      Text(
        t(widget.lang, 'educationMaxThreeHint'),
        style: TextStyle(color: Theme.of(context).hintColor),
      ),
      const SizedBox(height: 10),
    ];

    if (_educationDrafts.isEmpty) {
      widgets.add(
        Text(
          t(widget.lang, 'educationEmptyState'),
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }

    for (int index = 0; index < _educationDrafts.length; index += 1) {
      final education = _educationDrafts[index];
      final level = education.educationLevel;
      final isUniversityLevel = _isUniversityEducationLevel(level);
      final endYearOptions = _endYearOptionsFor(education.startYear);
      final currentEndYear = education.endYear;
      final endMonthOptions = _endMonthOptionsFor(
        startYear: education.startYear,
        startMonth: education.startMonth,
        endYear: currentEndYear,
      );
      widgets.add(
        Container(
          key: ValueKey('education_card_${education.id}'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${t(widget.lang, 'educationItemLabel')} ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _entryVisibilityToggle(
                    isOpen: education.showOnProfile,
                    onChanged: (value) =>
                        setState(() => education.showOnProfile = value),
                  ),
                  IconButton(
                    onPressed: () => _removeEducationDraft(education),
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: t(widget.lang, 'delete'),
                  ),
                ],
              ),
              DropdownMenu<String>(
                key: ValueKey('education_level_${education.id}_${level ?? 'none'}'),
                initialSelection: level,
                width: double.infinity,
                menuHeight: 280,
                enableSearch: true,
                enableFilter: true,
                requestFocusOnTap: true,
                label: Text(t(widget.lang, 'educationFormLabel')),
                inputDecorationTheme: const InputDecorationTheme(
                  border: OutlineInputBorder(),
                ),
                dropdownMenuEntries: _educationLevels
                    .map((value) => DropdownMenuEntry(value: value, label: value))
                    .toList(growable: false),
                onSelected: (value) {
                  setState(() {
                    education.educationLevel = value;
                    if (!_isUniversityEducationLevel(value)) {
                      education.specializationCtrl.clear();
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: education.universityCtrl,
                decoration: InputDecoration(
                  labelText: _educationInstitutionLabelForLevel(level),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (isUniversityLevel) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: education.specializationCtrl,
                  decoration: InputDecoration(
                    labelText: t(widget.lang, 'educationFacultySpecializationOptional'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownMenu<int>(
                      key: ValueKey('education_start_month_${education.id}'),
                      initialSelection: education.startMonth,
                      width: double.infinity,
                      menuHeight: 280,
                      label: Text(t(widget.lang, 'startMonth')),
                      inputDecorationTheme: const InputDecorationTheme(
                        border: OutlineInputBorder(),
                      ),
                      dropdownMenuEntries: monthOptions
                          .map(
                            (month) => DropdownMenuEntry(
                              value: month,
                              label: _monthOptionLabel(month),
                            ),
                          )
                          .toList(growable: false),
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          education.startMonth = value;
                          if (_isEndDateBeforeStart(
                            startMonth: education.startMonth,
                            startYear: education.startYear,
                            endMonth: education.endMonth,
                            endYear: education.endYear,
                          )) {
                            education.endYear = education.startYear;
                            education.endMonth = education.startMonth;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownMenu<int>(
                      key: ValueKey('education_start_year_${education.id}'),
                      initialSelection: education.startYear,
                      width: double.infinity,
                      menuHeight: 280,
                      label: Text(t(widget.lang, 'startYear')),
                      inputDecorationTheme: const InputDecorationTheme(
                        border: OutlineInputBorder(),
                      ),
                      dropdownMenuEntries: yearOptions
                          .map(
                            (year) => DropdownMenuEntry(
                              value: year,
                              label: year.toString(),
                            ),
                          )
                          .toList(growable: false),
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          education.startYear = value;
                          if (_isEndDateBeforeStart(
                            startMonth: education.startMonth,
                            startYear: education.startYear,
                            endMonth: education.endMonth,
                            endYear: education.endYear,
                          )) {
                            education.endYear = education.startYear;
                            education.endMonth = education.startMonth;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: education.isCurrent,
                title: Text(t(widget.lang, 'educationCurrentRole')),
                onChanged: (value) {
                  setState(() {
                    education.isCurrent = value;
                    if (value) {
                      education.endMonth = null;
                      education.endYear = null;
                    } else {
                      education.endMonth ??= education.startMonth;
                      education.endYear ??= education.startYear;
                    }
                  });
                },
              ),
              if (!education.isCurrent)
                Row(
                  children: [
                    Expanded(
                      child: DropdownMenu<int>(
                        key: ValueKey('education_end_month_${education.id}'),
                        initialSelection: education.endMonth,
                        width: double.infinity,
                        menuHeight: 280,
                        label: Text(t(widget.lang, 'endMonth')),
                        inputDecorationTheme: const InputDecorationTheme(
                          border: OutlineInputBorder(),
                        ),
                        dropdownMenuEntries: endMonthOptions
                            .map(
                              (month) => DropdownMenuEntry(
                                value: month,
                                label: _monthOptionLabel(month),
                              ),
                            )
                            .toList(growable: false),
                        onSelected: (value) {
                          if (value == null) return;
                          setState(() => education.endMonth = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownMenu<int>(
                        key: ValueKey('education_end_year_${education.id}'),
                        initialSelection: education.endYear,
                        width: double.infinity,
                        menuHeight: 280,
                        label: Text(t(widget.lang, 'endYear')),
                        inputDecorationTheme: const InputDecorationTheme(
                          border: OutlineInputBorder(),
                        ),
                        dropdownMenuEntries: endYearOptions
                            .map(
                              (year) => DropdownMenuEntry(
                                value: year,
                                label: year.toString(),
                              ),
                            )
                            .toList(growable: false),
                        onSelected: (value) {
                          if (value == null) return;
                          setState(() {
                            education.endYear = value;
                            final validMonths = _endMonthOptionsFor(
                              startYear: education.startYear,
                              startMonth: education.startMonth,
                              endYear: education.endYear,
                            );
                            if (!validMonths.contains(education.endMonth)) {
                              education.endMonth = validMonths.first;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    widgets.add(
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
            onPressed: _educationDrafts.length >= _SettingsPageState._maxEducationDrafts
              ? null
              : _addEducationDraft,
          icon: const Icon(Icons.add_rounded),
          label: Text(t(widget.lang, 'addEducationItem')),
        ),
      ),
    );

    return widgets;
  }

  List<Widget> _buildSkillsEditorSection(String? selectedSectionId) {
    final showLanguages = selectedSectionId == null ||
        selectedSectionId == 'skills' ||
        selectedSectionId == 'skills_languages';
    final showSoft = selectedSectionId == null ||
        selectedSectionId == 'skills' ||
        selectedSectionId == 'skills_soft';
    final showHard = selectedSectionId == null ||
        selectedSectionId == 'skills' ||
        selectedSectionId == 'skills_hard';

    final widgets = <Widget>[];
    if (showLanguages) {
      widgets.addAll(
        _buildSkillCategoryEditor(
          category: _SkillCategory.language,
          title: t(widget.lang, 'skillsLanguages'),
          addLabel: t(widget.lang, 'addLanguageSkill'),
        ),
      );
    }
    if (showSoft) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 10));
      }
      widgets.addAll(
        _buildSkillCategoryEditor(
          category: _SkillCategory.soft,
          title: t(widget.lang, 'skillsSoft'),
          addLabel: t(widget.lang, 'addSoftSkill'),
        ),
      );
    }
    if (showHard) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 10));
      }
      widgets.addAll(
        _buildSkillCategoryEditor(
          category: _SkillCategory.hard,
          title: t(widget.lang, 'skillsHard'),
          addLabel: t(widget.lang, 'addHardSkill'),
        ),
      );
    }

    if (widgets.isEmpty) {
      widgets.add(
        Text(
          t(widget.lang, 'skillsEmptyState'),
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildProjectsEditorSection() {
    final monthOptions = List<int>.generate(12, (index) => index + 1);
    final yearOptions = _experienceYearOptions;

    final widgets = <Widget>[
      Text(
        t(widget.lang, 'projectsMaxHint'),
        style: TextStyle(color: Theme.of(context).hintColor),
      ),
      const SizedBox(height: 10),
    ];

    if (_projectDrafts.isEmpty) {
      widgets.add(
        Text(
          t(widget.lang, 'projectsEmptyState'),
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }

    for (int index = 0; index < _projectDrafts.length; index += 1) {
      final project = _projectDrafts[index];
      final endYearOptions = _endYearOptionsFor(project.startYear);
      final endMonthOptions = _endMonthOptionsFor(
        startYear: project.startYear,
        startMonth: project.startMonth,
        endYear: project.endYear,
      );

      widgets.add(
        Container(
          key: ValueKey('project_card_${project.id}'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${t(widget.lang, 'projectItemLabel')} ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _entryVisibilityToggle(
                    isOpen: project.showOnProfile,
                    onChanged: (value) => setState(() => project.showOnProfile = value),
                  ),
                  IconButton(
                    onPressed: () => _removeProjectDraft(project),
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: t(widget.lang, 'delete'),
                  ),
                ],
              ),
              TextField(
                controller: project.titleCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t(widget.lang, 'projectTitleLabel'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: project.descriptionCtrl,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t(widget.lang, 'projectDescriptionLabel'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: project.githubUrlCtrl,
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t(widget.lang, 'projectGithubLabel'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownMenu<int>(
                      key: ValueKey('project_start_month_${project.id}'),
                      initialSelection: project.startMonth,
                      width: double.infinity,
                      menuHeight: 280,
                      label: Text(t(widget.lang, 'startMonth')),
                      inputDecorationTheme: const InputDecorationTheme(
                        border: OutlineInputBorder(),
                      ),
                      dropdownMenuEntries: monthOptions
                          .map((month) => DropdownMenuEntry(value: month, label: _monthOptionLabel(month)))
                          .toList(growable: false),
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          project.startMonth = value;
                          if (_isEndDateBeforeStart(
                            startMonth: project.startMonth,
                            startYear: project.startYear,
                            endMonth: project.endMonth,
                            endYear: project.endYear,
                          )) {
                            project.endYear = project.startYear;
                            project.endMonth = project.startMonth;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownMenu<int>(
                      key: ValueKey('project_start_year_${project.id}'),
                      initialSelection: project.startYear,
                      width: double.infinity,
                      menuHeight: 280,
                      label: Text(t(widget.lang, 'startYear')),
                      inputDecorationTheme: const InputDecorationTheme(
                        border: OutlineInputBorder(),
                      ),
                      dropdownMenuEntries: yearOptions
                          .map((year) => DropdownMenuEntry(value: year, label: year.toString()))
                          .toList(growable: false),
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          project.startYear = value;
                          if (_isEndDateBeforeStart(
                            startMonth: project.startMonth,
                            startYear: project.startYear,
                            endMonth: project.endMonth,
                            endYear: project.endYear,
                          )) {
                            project.endYear = project.startYear;
                            project.endMonth = project.startMonth;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: project.isCurrent,
                title: Text(t(widget.lang, 'projectCurrentLabel')),
                onChanged: (value) {
                  setState(() {
                    project.isCurrent = value;
                    if (value) {
                      project.endMonth = null;
                      project.endYear = null;
                    } else {
                      project.endMonth ??= project.startMonth;
                      project.endYear ??= project.startYear;
                    }
                  });
                },
              ),
              if (!project.isCurrent)
                Row(
                  children: [
                    Expanded(
                      child: DropdownMenu<int>(
                        key: ValueKey('project_end_month_${project.id}'),
                        initialSelection: project.endMonth,
                        width: double.infinity,
                        menuHeight: 280,
                        label: Text(t(widget.lang, 'endMonth')),
                        inputDecorationTheme: const InputDecorationTheme(
                          border: OutlineInputBorder(),
                        ),
                        dropdownMenuEntries: endMonthOptions
                            .map((month) => DropdownMenuEntry(value: month, label: _monthOptionLabel(month)))
                            .toList(growable: false),
                        onSelected: (value) {
                          if (value == null) return;
                          setState(() => project.endMonth = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownMenu<int>(
                        key: ValueKey('project_end_year_${project.id}'),
                        initialSelection: project.endYear,
                        width: double.infinity,
                        menuHeight: 280,
                        label: Text(t(widget.lang, 'endYear')),
                        inputDecorationTheme: const InputDecorationTheme(
                          border: OutlineInputBorder(),
                        ),
                        dropdownMenuEntries: endYearOptions
                            .map((year) => DropdownMenuEntry(value: year, label: year.toString()))
                            .toList(growable: false),
                        onSelected: (value) {
                          if (value == null) return;
                          setState(() {
                            project.endYear = value;
                            final validMonths = _endMonthOptionsFor(
                              startYear: project.startYear,
                              startMonth: project.startMonth,
                              endYear: project.endYear,
                            );
                            if (!validMonths.contains(project.endMonth)) {
                              project.endMonth = validMonths.first;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    widgets.add(
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _projectDrafts.length >= _SettingsPageState._maxProjectDrafts ? null : _addProjectDraft,
          icon: const Icon(Icons.add_rounded),
          label: Text(t(widget.lang, 'addProjectItem')),
        ),
      ),
    );

    return widgets;
  }

  List<Widget> _buildSkillCategoryEditor({
    required _SkillCategory category,
    required String title,
    required String addLabel,
  }) {
    final skills = _skillsByCategory(category);
    final widgets = <Widget>[
      Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      const SizedBox(height: 8),
    ];

    if (skills.isEmpty) {
      widgets.add(
        Text(
          t(widget.lang, 'skillsEmptyState'),
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }

    final searchPool = _skillsSearchPool(category);
    for (int index = 0; index < skills.length; index += 1) {
      final skill = skills[index];
      widgets.add(
        Container(
          key: ValueKey('skill_card_${skill.id}'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_skillNameLabel(category)} ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _entryVisibilityToggle(
                    isOpen: skill.isVisible,
                    onChanged: (value) => setState(() => skill.isVisible = value),
                  ),
                  IconButton(
                    onPressed: () => _removeSkillDraft(skill),
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: t(widget.lang, 'delete'),
                  ),
                ],
              ),
              _buildSkillAutocompleteField(skill, searchPool),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Spacer(),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      key: ValueKey('skill_score_${skill.id}'),
                      initialValue: _formatScoreInput(skill.score),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*[\.,]?[0-9]{0,2}$')),
                      ],
                      onChanged: (value) {
                        final parsed = _parseScoreInput(value);
                        if (parsed == null) return;
                        setState(() {
                          skill.score = parsed;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: t(widget.lang, 'skillScoreLabel'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    widgets.add(
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: skills.length >= _SettingsPageState._maxSkillsPerCategory ? null : () => _addSkillDraft(category),
          icon: const Icon(Icons.add_rounded),
          label: Text(addLabel),
        ),
      ),
    );

    return widgets;
  }

  Widget _buildSkillAutocompleteField(_SkillDraft skill, List<String> options) {
    final hint = options.isNotEmpty ? '${_skillPlaceholder(skill.category)} (${options.first})' : _skillPlaceholder(skill.category);
    return TextField(
      key: ValueKey('skill_name_${skill.id}'),
      controller: skill.nameCtrl,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: _skillNameLabel(skill.category),
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  double? _parseScoreInput(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    final parsed = double.tryParse(normalized);
    if (parsed == null) return null;
    if (parsed < 1 || parsed > 10) return null;
    return parsed;
  }

  String _formatScoreInput(dynamic value) {
    final safeValue = _safeScore(value);
    if (safeValue == safeValue.roundToDouble()) {
      return safeValue.toInt().toString();
    }
    return safeValue.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  String _skillNameLabel(_SkillCategory category) {
    switch (category) {
      case _SkillCategory.language:
        return t(widget.lang, 'languageSkillNameLabel');
      case _SkillCategory.soft:
        return t(widget.lang, 'softSkillNameLabel');
      case _SkillCategory.hard:
        return t(widget.lang, 'hardSkillNameLabel');
    }
  }

  String _skillPlaceholder(_SkillCategory category) {
    switch (category) {
      case _SkillCategory.language:
        return t(widget.lang, 'languageSkillPlaceholder');
      case _SkillCategory.soft:
        return t(widget.lang, 'softSkillPlaceholder');
      case _SkillCategory.hard:
        return t(widget.lang, 'hardSkillPlaceholder');
    }
  }

  List<String> _skillsSearchPool(_SkillCategory category) {
    return SkillsCatalog.forCategory(
      lang: widget.lang,
      category: _skillCategoryValue(category),
    );
  }
}
