import 'dart:convert';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/romania_locations.dart';
import '../core/skills_catalog.dart';
import '../core/texts.dart';
import '../pages/profile_page.dart';
import '../services/api_service.dart';
import '../services/secure_storage.dart';
import '../widgets/authenticated_page_shell.dart';

part 'settings/settings_sidebar_layout.part.dart';
part 'settings/settings_edit_profile_preview.part.dart';
part 'settings/settings_edit_profile_panel.part.dart';
part 'settings/settings_edit_profile_rows.part.dart';
part 'settings/settings_delete_account.part.dart';
part 'settings/settings_change_password.part.dart';
part 'settings/settings_two_factor_panel.part.dart';

enum SettingsTab {
  twoFactor,
  changePassword,
  editProfile,
  themePreference,
  deleteAccount,
}

class _ExperienceDraft {
  final String id;
  final TextEditingController companyCtrl;
  final TextEditingController positionCtrl;
  final TextEditingController descriptionCtrl;
  int startMonth;
  int startYear;
  bool isCurrent;
  int? endMonth;
  int? endYear;
  bool showOnProfile;

  _ExperienceDraft({
    required this.id,
    required String companyName,
    required String jobTitle,
    required String description,
    required this.startMonth,
    required this.startYear,
    required this.isCurrent,
    this.endMonth,
    this.endYear,
    this.showOnProfile = true,
  }) : companyCtrl = TextEditingController(text: companyName),
       positionCtrl = TextEditingController(text: jobTitle),
       descriptionCtrl = TextEditingController(text: description);

  Map<String, dynamic> toJson() {
    return {
      'companyName': companyCtrl.text.trim(),
      'jobTitle': positionCtrl.text.trim(),
      'description': descriptionCtrl.text.trim(),
      'startMonth': startMonth,
      'startYear': startYear,
      'isCurrent': isCurrent,
      'endMonth': isCurrent ? null : endMonth,
      'endYear': isCurrent ? null : endYear,
      'showOnProfile': showOnProfile,
    };
  }

  void dispose() {
    companyCtrl.dispose();
    positionCtrl.dispose();
    descriptionCtrl.dispose();
  }
}

class _EducationDraft {
  final String id;
  String? educationLevel;
  final TextEditingController universityCtrl;
  final TextEditingController specializationCtrl;
  int startMonth;
  int startYear;
  bool isCurrent;
  int? endMonth;
  int? endYear;
  bool showOnProfile;

  _EducationDraft({
    required this.id,
    this.educationLevel,
    required String university,
    required String specialization,
    required this.startMonth,
    required this.startYear,
    required this.isCurrent,
    this.endMonth,
    this.endYear,
    this.showOnProfile = true,
  }) : universityCtrl = TextEditingController(text: university),
       specializationCtrl = TextEditingController(text: specialization);

  Map<String, dynamic> toJson() {
    return {
      'educationLevel': educationLevel,
      'university': universityCtrl.text.trim(),
      'specialization': specializationCtrl.text.trim(),
      'startMonth': startMonth,
      'startYear': startYear,
      'isCurrent': isCurrent,
      'endMonth': isCurrent ? null : endMonth,
      'endYear': isCurrent ? null : endYear,
      'showOnProfile': showOnProfile,
    };
  }

  void dispose() {
    universityCtrl.dispose();
    specializationCtrl.dispose();
  }
}

enum _SkillCategory { language, soft, hard }

class _SkillDraft {
  final String id;
  final _SkillCategory category;
  final TextEditingController nameCtrl;
  double score;
  bool isVisible;

  _SkillDraft({
    required this.id,
    required this.category,
    required String name,
    required this.score,
    required this.isVisible,
  }) : nameCtrl = TextEditingController(text: name);

  Map<String, dynamic> toJson() {
    final categoryValue = switch (category) {
      _SkillCategory.language => 'language',
      _SkillCategory.soft => 'soft',
      _SkillCategory.hard => 'hard',
    };
    final normalizedScore = score < 1
        ? 1
        : (score > 10 ? 10 : score);

    return {
      'category': categoryValue,
      'name': nameCtrl.text.trim(),
      'score': normalizedScore,
      'isVisible': isVisible,
    };
  }

  void dispose() {
    nameCtrl.dispose();
  }
}

class _ProjectDraft {
  final String id;
  final TextEditingController titleCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController githubUrlCtrl;
  int startMonth;
  int startYear;
  bool isCurrent;
  int? endMonth;
  int? endYear;
  bool showOnProfile;

  _ProjectDraft({
    required this.id,
    required String title,
    required String description,
    required String githubUrl,
    required this.startMonth,
    required this.startYear,
    required this.isCurrent,
    this.endMonth,
    this.endYear,
    this.showOnProfile = true,
  }) : titleCtrl = TextEditingController(text: title),
       descriptionCtrl = TextEditingController(text: description),
       githubUrlCtrl = TextEditingController(text: githubUrl);

  Map<String, dynamic> toJson() {
    final githubUrl = githubUrlCtrl.text.trim();
    return {
      'title': titleCtrl.text.trim(),
      'description': descriptionCtrl.text.trim(),
      'githubUrl': githubUrl.isEmpty ? null : githubUrl,
      'startMonth': startMonth,
      'startYear': startYear,
      'isCurrent': isCurrent,
      'endMonth': isCurrent ? null : endMonth,
      'endYear': isCurrent ? null : endYear,
      'showOnProfile': showOnProfile,
    };
  }

  void dispose() {
    titleCtrl.dispose();
    descriptionCtrl.dispose();
    githubUrlCtrl.dispose();
  }
}

class SettingsPage extends StatefulWidget {
  final String lang;
  final bool isDark;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final Future<void> Function() onLogout;

  const SettingsPage({
    super.key,
    required this.lang,
    required this.isDark,
    required this.onLangChange,
    required this.onThemeChange,
    required this.onLogout,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _avatarCacheKey = 'profile_avatar_base64_cache';
  static const int _maxExperienceDrafts = 5;
  static const int _maxEducationDrafts = 5;
  static const int _maxSkillsPerCategory = 20;
  static const int _maxProjectDrafts = 10;
  int _draftIdSeed = 0;

  bool isLoading = true;
  String? errorMessage;
  String? accessToken;
  Map<String, dynamic>? profileData;
  Uint8List? avatarBytes;
  late String currentLang;
  late bool currentIsDark;

  SettingsTab selectedTab = SettingsTab.editProfile;
  String? _selectedEditProfileSubcategory;
  bool isSidebarCollapsed = false;

  final currentPasswordCtrl = TextEditingController();
  final newPasswordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();
  final deleteAccountEmailCtrl = TextEditingController();
  final deleteAccountPasswordCtrl = TextEditingController();
  final deleteAccountPasswordConfirmCtrl = TextEditingController();
  final twoFactorCodeCtrl = TextEditingController();

  bool isTwoFactorBusy = false;
  bool isEmailVerificationBusy = false;
  bool isDefaultThemeDark = false;
  String? twoFactorQrDataUrl;
  String? twoFactorManualEntryKey;
  List<String> generatedBackupCodes = const [];

  bool showCurrentPasswordWhilePressed = false;
  bool showNewPasswordWhilePressed = false;
  bool showConfirmPasswordWhilePressed = false;
  bool showDeletePasswordWhilePressed = false;
  bool showDeletePasswordConfirmWhilePressed = false;

  final phoneCtrl = TextEditingController();
  final professionalTitleCtrl = TextEditingController();
  final yearsExperienceCtrl = TextEditingController();
  final profileSummaryCtrl = TextEditingController();
  final linkedInCtrl = TextEditingController();
  final githubCtrl = TextEditingController();
  final youtubeCtrl = TextEditingController();
  final instagramCtrl = TextEditingController();
  final tiktokCtrl = TextEditingController();

  final companyNameCtrl = TextEditingController();
  final companyCountyCtrl = TextEditingController();
  final companyCityCtrl = TextEditingController();

  String userCountry = 'Romania';
  String? userCounty;
  String? userCity;
  String? userProfessionalStatus;
  String? accountGender;
  DateTime? accountBirthDate;
  DateTime? accountCreatedAt;
  final List<_ExperienceDraft> _experienceDrafts = [];
  final List<_EducationDraft> _educationDrafts = [];
  final List<_SkillDraft> _skillDrafts = [];
  final List<_ProjectDraft> _projectDrafts = [];
  final Map<String, bool> _editProfileSectionExpanded = {};

  Map<String, bool> visibility = {};
  bool isSavingProfileDraft = false;
  String _initialProfileDraftSignature = '';
  String _initialVisibilityDraftSignature = '';

  static const List<String> _trackedVisibilityKeys = [
    'showGender',
    'showBirthDate',
    'showAccountCreatedDate',
    'showAccountCreatedTime',
    'showJobTitle',
    'showPhone',
    'showCountry',
    'showCounty',
    'showCity',
    'showYearsExperience',
    'showEducationLevel',
    'showEducationInstitution',
    'showSpecialization',
    'showCompanyName',
    'showCompanyCounty',
    'showCompanyCity',
    'showHrFirstName',
    'showHrLastName',
    'showHrEmail',
    'showCv',
    'showProfileSummary',
    'showProfessionalStatus',
    'showLinkedIn',
    'showGithub',
    'showYoutube',
    'showInstagram',
    'showTiktok',
  ];

  List<String> get _educationLevels => [
    t(widget.lang, 'educationHighSchool'),
    t(widget.lang, 'educationPostSecondary'),
    t(widget.lang, 'educationBachelor'),
    t(widget.lang, 'educationMaster'),
    t(widget.lang, 'educationDoctorate'),
  ];

  List<DropdownMenuEntry<String>> get _professionalStatusEntries => [
    DropdownMenuEntry(
      value: 'open_to_work',
      label: t(widget.lang, 'professionalStatusOpenToWork'),
    ),
    DropdownMenuEntry(
      value: 'hired',
      label: t(widget.lang, 'professionalStatusHired'),
    ),
    DropdownMenuEntry(
      value: 'not_available',
      label: t(widget.lang, 'professionalStatusNotAvailable'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    currentLang = widget.lang;
    currentIsDark = widget.isDark;
    _loadAvatarFromCache();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.lang != widget.lang && currentLang != widget.lang) {
      currentLang = widget.lang;
    }

    if (oldWidget.isDark != widget.isDark && currentIsDark != widget.isDark) {
      currentIsDark = widget.isDark;
    }
  }

  @override
  void dispose() {
    if (!_twoFactorEnabled && _isTwoFactorFlowActive) {
      unawaited(_cancelTwoFactorSetupOnDispose());
    }

    currentPasswordCtrl.dispose();
    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    deleteAccountEmailCtrl.dispose();
    deleteAccountPasswordCtrl.dispose();
    deleteAccountPasswordConfirmCtrl.dispose();
    twoFactorCodeCtrl.dispose();

    phoneCtrl.dispose();
    professionalTitleCtrl.dispose();
    yearsExperienceCtrl.dispose();
    profileSummaryCtrl.dispose();
    linkedInCtrl.dispose();
    githubCtrl.dispose();
    youtubeCtrl.dispose();
    instagramCtrl.dispose();
    tiktokCtrl.dispose();

    companyNameCtrl.dispose();
    companyCountyCtrl.dispose();
    companyCityCtrl.dispose();
    for (final experience in _experienceDrafts) {
      experience.dispose();
    }
    for (final education in _educationDrafts) {
      education.dispose();
    }
    for (final skill in _skillDrafts) {
      skill.dispose();
    }
    for (final project in _projectDrafts) {
      project.dispose();
    }
    super.dispose();
  }

  Future<void> _cancelTwoFactorSetupOnDispose() async {
    final token = accessToken;
    if (token == null || token.isEmpty) return;

    try {
      await ApiService.cancelTwoFactorSetup(accessToken: token);
    } catch (_) {}
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
        profileData = data;
        visibility = Map<String, bool>.from(data['visibility'] ?? {});
        _applyProfileData(data);
        final user = data['user'] as Map<String, dynamic>? ?? {};
        isDefaultThemeDark =
            (user['defaultTheme']?.toString() ?? 'light') == 'dark';
        isLoading = false;
        _captureEditProfileBaseline();
      });

      if ((data['user'] as Map<String, dynamic>?)?['twoFactorPending'] ==
          true) {
        await _cancelTwoFactorSetup(silent: true);
      }

      final avatar = await ApiService.fetchAvatar(accessToken: token);
      if (!mounted) return;
      if (avatar != null) {
        setState(() {
          avatarBytes = avatar;
        });
        await SecureStorage.write(_avatarCacheKey, base64Encode(avatar));
      }
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

  Future<void> _saveDefaultThemePreference(bool isDarkTheme) async {
    final token = accessToken;
    if (token == null || token.isEmpty) return;

    await ApiService.updateThemePreference(
      accessToken: token,
      isDark: isDarkTheme,
    );

    if (!mounted) return;

    final user = Map<String, dynamic>.from(profileData?['user'] ?? {});
    user['defaultTheme'] = isDarkTheme ? 'dark' : 'light';

    setState(() {
      isDefaultThemeDark = isDarkTheme;
      currentIsDark = isDarkTheme;
      profileData = {...(profileData ?? <String, dynamic>{}), 'user': user};
    });
    widget.onThemeChange(isDarkTheme);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(currentLang, 'defaultThemeSaved'))),
    );
  }

  Future<void> _forceLogout() async {
    await widget.onLogout();
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route.isFirst);
  }

  void _applyProfileData(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>? ?? {};
    final userProfile = data['userProfile'] as Map<String, dynamic>? ?? {};
    final companyProfile =
        data['companyProfile'] as Map<String, dynamic>? ?? {};

    phoneCtrl.text = _normalizePhoneForInput(user['phone']?.toString() ?? '');
    userCountry = userProfile['country']?.toString().trim().isNotEmpty == true
        ? userProfile['country'].toString()
        : 'Romania';
    userCounty = _nullableTrimmed(userProfile['county']?.toString());
    userCity = _nullableTrimmed(userProfile['city']?.toString());
    yearsExperienceCtrl.text = userProfile['yearsExperience']?.toString() ?? '';
    professionalTitleCtrl.text = userProfile['jobTitle']?.toString() ?? '';
    profileSummaryCtrl.text = userProfile['profileSummary']?.toString() ?? '';
    linkedInCtrl.text = userProfile['linkedInUrl']?.toString() ?? '';
    githubCtrl.text = userProfile['githubUrl']?.toString() ?? '';
    youtubeCtrl.text = userProfile['youtubeUrl']?.toString() ?? '';
    instagramCtrl.text = userProfile['instagramUrl']?.toString() ?? '';
    tiktokCtrl.text = userProfile['tiktokUrl']?.toString() ?? '';

    final professionalStatusRaw = userProfile['professionalStatus']?.toString();
    userProfessionalStatus =
      professionalStatusRaw == 'open_to_work' ||
        professionalStatusRaw == 'hired' ||
        professionalStatusRaw == 'not_available'
      ? professionalStatusRaw
      : null;

    companyNameCtrl.text = companyProfile['companyName']?.toString() ?? '';
    companyCountyCtrl.text = companyProfile['county']?.toString() ?? '';
    companyCityCtrl.text = companyProfile['city']?.toString() ?? '';

    final genderRaw = user['gender']?.toString();
    accountGender = (genderRaw == 'male' || genderRaw == 'female')
        ? genderRaw
        : null;

    final birthDateRaw = user['birthDate']?.toString();
    accountBirthDate = birthDateRaw == null || birthDateRaw.trim().isEmpty
        ? null
        : DateTime.tryParse(birthDateRaw);

    final createdAtRaw = user['createdAt']?.toString();
    accountCreatedAt = createdAtRaw == null || createdAtRaw.trim().isEmpty
      ? null
      : DateTime.tryParse(createdAtRaw)?.toLocal();

    _replaceExperienceDraftsFromProfile(data);
    _replaceEducationDraftsFromProfile(data);
    _replaceSkillDraftsFromProfile(data);
    _replaceProjectDraftsFromProfile(data);
  }

  String _formatBirthDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatDateDisplay(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString().padLeft(4, '0');
    return '$day.$month.$year';
  }

  String _formatTimeDisplay(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  bool _isHighSchoolEducationLevel(String? level) {
    return level == t(widget.lang, 'educationHighSchool');
  }

  bool _isUniversityEducationLevel(String? level) {
    if (level == null) return false;
    return level == t(widget.lang, 'educationBachelor') ||
        level == t(widget.lang, 'educationMaster') ||
        level == t(widget.lang, 'educationDoctorate');
  }

  String _educationInstitutionLabelForLevel(String? level) {
    if (_isHighSchoolEducationLevel(level)) {
      return t(widget.lang, 'educationHighSchoolCompleted');
    }
    if (level == t(widget.lang, 'educationPostSecondary')) {
      return t(widget.lang, 'educationPostSecondaryLabel');
    }
    if (_isUniversityEducationLevel(level)) {
      return t(widget.lang, 'educationUniversityLabel');
    }
    return t(widget.lang, 'lastEducationInstitution');
  }

  Future<void> _pickAccountBirthDate() async {
    final now = DateTime.now();
    final initial = accountBirthDate ?? DateTime(now.year - 24, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940, 1, 1),
      lastDate: DateTime(now.year - 14, now.month, now.day),
    );

    if (picked == null || !mounted) return;
    setState(() => accountBirthDate = picked);
  }

  String _normalizePhoneForInput(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('40') && digits.length >= 11) {
      return digits.substring(2, 11);
    }
    if (digits.startsWith('0') && digits.length >= 10) {
      return digits.substring(1, 10);
    }
    return digits.length > 9 ? digits.substring(digits.length - 9) : digits;
  }

  String? _nullableTrimmed(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String _trimmed(String value) => value.trim();

  int _safeMonth(int value) {
    if (value < 1 || value > 12) {
      return 1;
    }
    return value;
  }

  int? _safeNullableMonth(int? value) {
    if (value == null) return null;
    return _safeMonth(value);
  }

  int _safeYear(int value) {
    final currentYear = DateTime.now().year;
    final minYear = currentYear - 80;
    if (value < minYear || value > currentYear) {
      return currentYear;
    }
    return value;
  }

  int? _safeNullableYear(int? value) {
    if (value == null) return null;
    return _safeYear(value);
  }

  String _nextDraftId(String prefix) {
    _draftIdSeed += 1;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_${timestamp}_$_draftIdSeed';
  }

  List<int> get _experienceYearOptions {
    final currentYear = DateTime.now().year;
    return List<int>.generate(81, (index) => currentYear - index);
  }

  String _monthName(int month) => t(widget.lang, 'monthName${month.toString().padLeft(2, '0')}');

  String _monthOptionLabel(int month) {
    final number = month.toString().padLeft(2, '0');
    return '$number - ${_monthName(month)}';
  }

  bool _isEndDateBeforeStart({
    required int startMonth,
    required int startYear,
    required int? endMonth,
    required int? endYear,
  }) {
    if (endMonth == null || endYear == null) {
      return false;
    }
    final startValue = startYear * 12 + startMonth;
    final endValue = endYear * 12 + endMonth;
    return endValue < startValue;
  }

  List<int> _endYearOptionsFor(int startYear) {
    return _experienceYearOptions.where((year) => year >= startYear).toList(growable: false);
  }

  List<int> _endMonthOptionsFor({required int startYear, required int startMonth, required int? endYear}) {
    if (endYear == null || endYear > startYear) {
      return List<int>.generate(12, (index) => index + 1);
    }
    return List<int>.generate(12 - startMonth + 1, (index) => startMonth + index);
  }

  String _skillCategoryValue(_SkillCategory category) {
    return switch (category) {
      _SkillCategory.language => 'language',
      _SkillCategory.soft => 'soft',
      _SkillCategory.hard => 'hard',
    };
  }

  _SkillCategory? _skillCategoryFromValue(String? value) {
    switch (value) {
      case 'language':
        return _SkillCategory.language;
      case 'soft':
        return _SkillCategory.soft;
      case 'hard':
        return _SkillCategory.hard;
      default:
        return null;
    }
  }

  List<_SkillDraft> _skillsByCategory(_SkillCategory category) {
    return _skillDrafts.where((skill) => skill.category == category).toList(growable: false);
  }

  List<Map<String, dynamic>> _buildSkillDraftsPayload({bool includeIncomplete = true}) {
    final items = _skillDrafts.map((skill) => skill.toJson()).toList(growable: false);
    if (includeIncomplete) {
      return items;
    }
    return items.where((entry) => (entry['name']?.toString().trim().isNotEmpty ?? false)).toList(growable: false);
  }

  String? _validateSkillDraftsForSave() {
    for (final entry in _buildSkillDraftsPayload()) {
      final name = entry['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        continue;
      }
      final score = (entry['score'] as num?)?.toDouble() ?? 0;
      if (score < 1 || score > 10) {
        return t(widget.lang, 'completeAllFields');
      }
    }
    return null;
  }

  void _replaceSkillDraftsFromProfile(Map<String, dynamic> data) {
    for (final skill in _skillDrafts) {
      skill.dispose();
    }
    _skillDrafts.clear();

    final raw = data['userSkills'];
    if (raw is! List) {
      return;
    }

    final seenIds = <String>{};
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;

      final category = _skillCategoryFromValue(entry['category']?.toString());
      if (category == null) continue;

      final candidateId = entry['id']?.toString().trim() ?? '';
      final uniqueId = candidateId.isEmpty || seenIds.contains(candidateId)
          ? _nextDraftId('skill')
          : candidateId;
      seenIds.add(uniqueId);

      final score = _safeScore(entry['score']);

      _skillDrafts.add(
        _SkillDraft(
          id: uniqueId,
          category: category,
          name: entry['name']?.toString() ?? '',
          score: score < 1 ? 1 : (score > 10 ? 10 : score),
          isVisible: entry['isVisible'] != false,
        ),
      );
    }
  }

  void _addSkillDraft(_SkillCategory category) {
    if (_skillsByCategory(category).length >= _maxSkillsPerCategory) return;
    setState(() {
      _skillDrafts.add(
        _SkillDraft(
          id: _nextDraftId('skill'),
          category: category,
          name: '',
          score: 5,
          isVisible: true,
        ),
      );
    });
  }

  void _removeSkillDraft(_SkillDraft draft) {
    setState(() {
      _skillDrafts.remove(draft);
      draft.dispose();
    });
  }

  double _safeScore(dynamic rawScore) {
    if (rawScore is num) {
      final parsed = rawScore.toDouble();
      return parsed < 1 ? 1 : (parsed > 10 ? 10 : parsed);
    }
    if (rawScore is bool) {
      return 5;
    }
    final parsed = double.tryParse(rawScore?.toString().replaceAll(',', '.') ?? '');
    if (parsed == null) {
      return 5;
    }
    return parsed < 1 ? 1 : (parsed > 10 ? 10 : parsed);
  }

  List<Map<String, dynamic>> _buildProjectDraftsPayload({bool includeIncomplete = true}) {
    final items = _projectDrafts.map((project) => project.toJson()).toList(growable: false);
    if (includeIncomplete) {
      return items;
    }
    return items
        .where((entry) => (entry['title']?.toString().trim().isNotEmpty ?? false))
        .toList(growable: false);
  }

  String? _validateProjectDraftsForSave() {
    for (final entry in _buildProjectDraftsPayload()) {
      final title = entry['title']?.toString().trim() ?? '';
      final hasAnyContent =
          title.isNotEmpty ||
          (entry['description']?.toString().trim().isNotEmpty ?? false) ||
          (entry['githubUrl']?.toString().trim().isNotEmpty ?? false);

      if (!hasAnyContent) {
        continue;
      }
      if (title.isEmpty) {
        return t(widget.lang, 'completeAllFields');
      }

      final startMonth = (entry['startMonth'] as num?)?.toInt();
      final startYear = (entry['startYear'] as num?)?.toInt();
      final isCurrent = entry['isCurrent'] == true;
      final endMonth = (entry['endMonth'] as num?)?.toInt();
      final endYear = (entry['endYear'] as num?)?.toInt();

      if (startMonth == null || startYear == null) {
        return t(widget.lang, 'completeAllFields');
      }

      if (!isCurrent && _isEndDateBeforeStart(
        startMonth: startMonth,
        startYear: startYear,
        endMonth: endMonth,
        endYear: endYear,
      )) {
        return t(widget.lang, 'invalidEndDate');
      }
    }
    return null;
  }

  void _replaceProjectDraftsFromProfile(Map<String, dynamic> data) {
    for (final project in _projectDrafts) {
      project.dispose();
    }
    _projectDrafts.clear();

    final raw = data['userProjects'];
    if (raw is! List) {
      return;
    }

    final seenIds = <String>{};
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;

      final candidateId = entry['id']?.toString().trim() ?? '';
      final uniqueId = candidateId.isEmpty || seenIds.contains(candidateId)
          ? _nextDraftId('project')
          : candidateId;
      seenIds.add(uniqueId);

      final startMonth = _safeMonth((entry['startMonth'] as num?)?.toInt() ?? 1);
      final startYear = _safeYear((entry['startYear'] as num?)?.toInt() ?? DateTime.now().year);
      final isCurrent = entry['isCurrent'] == true;
      final safeEndYear = _safeNullableYear((entry['endYear'] as num?)?.toInt());
      final safeEndMonth = _safeNullableMonth((entry['endMonth'] as num?)?.toInt());

      _projectDrafts.add(
        _ProjectDraft(
          id: uniqueId,
          title: entry['title']?.toString() ?? '',
          description: entry['description']?.toString() ?? '',
          githubUrl: entry['githubUrl']?.toString() ?? '',
          startMonth: startMonth,
          startYear: startYear,
          isCurrent: isCurrent,
          endMonth: isCurrent ? null : safeEndMonth,
          endYear: isCurrent ? null : safeEndYear,
          showOnProfile: entry['showOnProfile'] != false,
        ),
      );
    }
  }

  void _addProjectDraft() {
    if (_projectDrafts.length >= _maxProjectDrafts) return;
    final currentYear = DateTime.now().year;
    setState(() {
      _projectDrafts.add(
        _ProjectDraft(
          id: _nextDraftId('project'),
          title: '',
          description: '',
          githubUrl: '',
          startMonth: 1,
          startYear: currentYear,
          isCurrent: true,
          showOnProfile: true,
        ),
      );
    });
  }

  void _removeProjectDraft(_ProjectDraft draft) {
    setState(() {
      _projectDrafts.remove(draft);
      draft.dispose();
    });
  }

  List<Map<String, dynamic>> _buildExperienceDraftsPayload({
    bool includeIncomplete = true,
  }) {
    final items = _experienceDrafts
        .map((experience) => experience.toJson())
        .toList(growable: false);

    if (includeIncomplete) {
      return items;
    }

    return items.where((entry) {
      final company = entry['companyName']?.toString() ?? '';
      final role = entry['jobTitle']?.toString() ?? '';
      return company.isNotEmpty && role.isNotEmpty;
    }).toList(growable: false);
  }

  List<Map<String, dynamic>> _buildEducationDraftsPayload({
    bool includeIncomplete = true,
  }) {
    final items = _educationDrafts
        .map((education) => education.toJson())
        .toList(growable: false);

    if (includeIncomplete) {
      return items;
    }

    return items.where((entry) {
      final educationLevel = entry['educationLevel']?.toString() ?? '';
      final university = entry['university']?.toString() ?? '';
      return educationLevel.isNotEmpty && university.isNotEmpty;
    }).toList(growable: false);
  }

  String? _validateExperienceDraftsForSave() {
    for (final entry in _buildExperienceDraftsPayload()) {
      final company = entry['companyName']?.toString() ?? '';
      final role = entry['jobTitle']?.toString() ?? '';
      final hasAnyContent =
          company.isNotEmpty ||
          role.isNotEmpty ||
          (entry['description']?.toString().isNotEmpty ?? false);

      if (!hasAnyContent) {
        continue;
      }

      if (company.isEmpty || role.isEmpty) {
        return t(widget.lang, 'completeAllFields');
      }

      final isCurrent = entry['isCurrent'] == true;
      if (!isCurrent && (entry['endMonth'] == null || entry['endYear'] == null)) {
        return t(widget.lang, 'completeAllFields');
      }
      if (!isCurrent &&
          _isEndDateBeforeStart(
            startMonth: (entry['startMonth'] as num?)?.toInt() ?? 1,
            startYear: (entry['startYear'] as num?)?.toInt() ?? DateTime.now().year,
            endMonth: (entry['endMonth'] as num?)?.toInt(),
            endYear: (entry['endYear'] as num?)?.toInt(),
          )) {
        return t(widget.lang, 'invalidEndDate');
      }
    }

    return null;
  }

  String? _validateEducationDraftsForSave() {
    for (final entry in _buildEducationDraftsPayload()) {
      final educationLevel = entry['educationLevel']?.toString() ?? '';
      final university = entry['university']?.toString() ?? '';
      final specialization = entry['specialization']?.toString() ?? '';
      final hasAnyContent =
          educationLevel.isNotEmpty || university.isNotEmpty || specialization.isNotEmpty;

      if (!hasAnyContent) {
        continue;
      }

      if (educationLevel.isEmpty || university.isEmpty) {
        return t(widget.lang, 'completeAllFields');
      }

      final isCurrent = entry['isCurrent'] == true;
      if (!isCurrent && (entry['endMonth'] == null || entry['endYear'] == null)) {
        return t(widget.lang, 'completeAllFields');
      }
      if (!isCurrent &&
          _isEndDateBeforeStart(
            startMonth: (entry['startMonth'] as num?)?.toInt() ?? 1,
            startYear: (entry['startYear'] as num?)?.toInt() ?? DateTime.now().year,
            endMonth: (entry['endMonth'] as num?)?.toInt(),
            endYear: (entry['endYear'] as num?)?.toInt(),
          )) {
        return t(widget.lang, 'invalidEndDate');
      }
    }

    return null;
  }

  void _replaceExperienceDraftsFromProfile(Map<String, dynamic> data) {
    for (final experience in _experienceDrafts) {
      experience.dispose();
    }
    _experienceDrafts.clear();

    final raw = data['userExperiences'];
    if (raw is! List) {
      return;
    }

    final seenIds = <String>{};
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;

      final candidateId = entry['id']?.toString().trim() ?? '';
      final uniqueId =
          candidateId.isEmpty || seenIds.contains(candidateId)
          ? _nextDraftId('experience')
          : candidateId;
      seenIds.add(uniqueId);

      _experienceDrafts.add(
        _ExperienceDraft(
          id: uniqueId,
          companyName: entry['companyName']?.toString() ?? '',
          jobTitle: entry['jobTitle']?.toString() ?? '',
          description: entry['description']?.toString() ?? '',
          startMonth: _safeMonth((entry['startMonth'] as num?)?.toInt() ?? 1),
          startYear: _safeYear(
            (entry['startYear'] as num?)?.toInt() ?? DateTime.now().year,
          ),
          isCurrent: entry['isCurrent'] == true,
          endMonth: _safeNullableMonth((entry['endMonth'] as num?)?.toInt()),
          endYear: _safeNullableYear((entry['endYear'] as num?)?.toInt()),
          showOnProfile: entry['showOnProfile'] != false,
        ),
      );
    }
  }

  void _replaceEducationDraftsFromProfile(Map<String, dynamic> data) {
    for (final education in _educationDrafts) {
      education.dispose();
    }
    _educationDrafts.clear();

    final raw = data['userEducations'];
    if (raw is! List) {
      return;
    }

    final seenIds = <String>{};
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;

      final candidateId = entry['id']?.toString().trim() ?? '';
      final uniqueId =
          candidateId.isEmpty || seenIds.contains(candidateId)
          ? _nextDraftId('education')
          : candidateId;
      seenIds.add(uniqueId);

      _educationDrafts.add(
        _EducationDraft(
          id: uniqueId,
          educationLevel: _nullableTrimmed(entry['educationLevel']?.toString()),
          university: entry['university']?.toString() ?? '',
          specialization: entry['specialization']?.toString() ?? '',
          startMonth: _safeMonth((entry['startMonth'] as num?)?.toInt() ?? 1),
          startYear: _safeYear(
            (entry['startYear'] as num?)?.toInt() ?? DateTime.now().year,
          ),
          isCurrent: entry['isCurrent'] == true,
          endMonth: _safeNullableMonth((entry['endMonth'] as num?)?.toInt()),
          endYear: _safeNullableYear((entry['endYear'] as num?)?.toInt()),
          showOnProfile: entry['showOnProfile'] != false,
        ),
      );
    }
  }

  void _addExperienceDraft() {
    if (_experienceDrafts.length >= _maxExperienceDrafts) return;
    final currentYear = DateTime.now().year;
    setState(() {
      _experienceDrafts.add(
        _ExperienceDraft(
          id: _nextDraftId('experience'),
          companyName: '',
          jobTitle: '',
          description: '',
          startMonth: 1,
          startYear: currentYear,
          isCurrent: true,
          showOnProfile: true,
        ),
      );
    });
  }

  void _removeExperienceDraft(_ExperienceDraft draft) {
    setState(() {
      _experienceDrafts.remove(draft);
      draft.dispose();
    });
  }

  void _addEducationDraft() {
    if (_educationDrafts.length >= _maxEducationDrafts) return;
    final currentYear = DateTime.now().year;
    setState(() {
      _educationDrafts.add(
        _EducationDraft(
          id: _nextDraftId('education'),
          educationLevel: null,
          university: '',
          specialization: '',
          startMonth: 1,
          startYear: currentYear,
          isCurrent: true,
          showOnProfile: true,
        ),
      );
    });
  }

  void _removeEducationDraft(_EducationDraft draft) {
    setState(() {
      _educationDrafts.remove(draft);
      draft.dispose();
    });
  }

  String _boolSignature(bool value) => value ? '1' : '0';

  Map<String, dynamic> _buildProfileDraftMap() {
    final accountType = profileData?['accountType'] as String? ?? 'user';

    final base = <String, dynamic>{
      'accountType': accountType,
      'gender': accountGender,
      'birthDate': accountBirthDate == null
          ? null
          : _formatBirthDate(accountBirthDate!),
    };

    if (accountType == 'user') {
      base.addAll({
        'phone': _trimmed(phoneCtrl.text),
        'country': userCountry,
        'county': userCounty,
        'city': userCity,
        'jobTitle': _trimmed(professionalTitleCtrl.text),
        'professionalStatus': userProfessionalStatus,
        'yearsExperience': _trimmed(yearsExperienceCtrl.text),
        'profileSummary': _trimmed(profileSummaryCtrl.text),
        'linkedInUrl': _trimmed(linkedInCtrl.text),
        'githubUrl': _trimmed(githubCtrl.text),
        'youtubeUrl': _trimmed(youtubeCtrl.text),
        'instagramUrl': _trimmed(instagramCtrl.text),
        'tiktokUrl': _trimmed(tiktokCtrl.text),
        'experiences': _buildExperienceDraftsPayload(),
        'educations': _buildEducationDraftsPayload(),
        'skills': _buildSkillDraftsPayload(),
        'projects': _buildProjectDraftsPayload(),
      });
    } else {
      base.addAll({
        'companyName': _trimmed(companyNameCtrl.text),
        'companyCounty': _trimmed(companyCountyCtrl.text),
        'companyCity': _trimmed(companyCityCtrl.text),
      });
    }

    return base;
  }

  String _buildProfileDraftSignature() => jsonEncode(_buildProfileDraftMap());

  String _buildVisibilityDraftSignature() {
    final signatureMap = <String, String>{};
    for (final key in _trackedVisibilityKeys) {
      signatureMap[key] = _boolSignature(visibility[key] ?? false);
    }
    return jsonEncode(signatureMap);
  }

  void _captureEditProfileBaseline() {
    _initialProfileDraftSignature = _buildProfileDraftSignature();
    _initialVisibilityDraftSignature = _buildVisibilityDraftSignature();
  }

  bool get _hasUnsavedEditProfileChanges {
    if (profileData == null || isLoading) return false;
    return _buildProfileDraftSignature() != _initialProfileDraftSignature ||
        _buildVisibilityDraftSignature() != _initialVisibilityDraftSignature;
  }

  Future<void> _saveUserProfile() async {
    if (accessToken == null) return;

    final years = int.tryParse(yearsExperienceCtrl.text.trim());
    final phoneDigits = phoneCtrl.text.trim();

    await ApiService.updateUserProfile(
      accessToken: accessToken!,
      phone: phoneDigits.isEmpty ? null : '+40$phoneDigits',
      gender: accountGender,
      birthDate: accountBirthDate == null
          ? null
          : _formatBirthDate(accountBirthDate!),
      jobTitle: professionalTitleCtrl.text.trim(),
      country: userCountry,
      county: userCounty,
      city: userCity,
      yearsExperience: years,
      profileSummary: profileSummaryCtrl.text.trim().isEmpty
          ? null
          : profileSummaryCtrl.text.trim(),
        linkedInUrl: linkedInCtrl.text.trim().isEmpty
          ? null
          : linkedInCtrl.text.trim(),
        githubUrl: githubCtrl.text.trim().isEmpty
          ? null
          : githubCtrl.text.trim(),
        youtubeUrl: youtubeCtrl.text.trim().isEmpty
          ? null
          : youtubeCtrl.text.trim(),
        instagramUrl: instagramCtrl.text.trim().isEmpty
          ? null
          : instagramCtrl.text.trim(),
        tiktokUrl: tiktokCtrl.text.trim().isEmpty
          ? null
          : tiktokCtrl.text.trim(),
      professionalStatus: userProfessionalStatus,
    );
  }

  Future<void> _saveUserExperiences() async {
    if (accessToken == null) return;

    final validationError = _validateExperienceDraftsForSave();
    if (validationError != null) {
      throw StateError(validationError);
    }

    final experiences = _buildExperienceDraftsPayload(includeIncomplete: false);
    await ApiService.setUserExperiences(
      accessToken: accessToken!,
      experiences: experiences,
    );
  }

  Future<void> _saveUserEducations() async {
    if (accessToken == null) return;

    final validationError = _validateEducationDraftsForSave();
    if (validationError != null) {
      throw StateError(validationError);
    }

    final educations = _buildEducationDraftsPayload(includeIncomplete: false);
    await ApiService.setUserEducations(
      accessToken: accessToken!,
      educations: educations,
    );
  }

  Future<void> _saveUserSkills() async {
    if (accessToken == null) return;

    final validationError = _validateSkillDraftsForSave();
    if (validationError != null) {
      throw StateError(validationError);
    }

    final skills = _buildSkillDraftsPayload(includeIncomplete: false);
    await ApiService.setUserSkills(
      accessToken: accessToken!,
      skills: skills,
    );
  }

  Future<void> _saveUserProjects() async {
    if (accessToken == null) return;

    final validationError = _validateProjectDraftsForSave();
    if (validationError != null) {
      throw StateError(validationError);
    }

    final projects = _buildProjectDraftsPayload(includeIncomplete: false);
    await ApiService.setUserProjects(
      accessToken: accessToken!,
      projects: projects,
    );
  }

  Future<void> _saveCompanyProfile() async {
    if (accessToken == null) return;

    await ApiService.updateCompanyProfile(
      accessToken: accessToken!,
      companyName: companyNameCtrl.text.trim(),
      gender: accountGender,
      birthDate: accountBirthDate == null
          ? null
          : _formatBirthDate(accountBirthDate!),
      county: companyCountyCtrl.text.trim(),
      city: companyCityCtrl.text.trim(),
    );
  }

  Future<void> _saveVisibilityDraft() async {
    if (accessToken == null) return;

    bool valueOf(String key) => visibility[key] ?? false;

    await ApiService.updateProfileVisibility(
      accessToken: accessToken!,
      showGender: valueOf('showGender'),
      showBirthDate: valueOf('showBirthDate'),
      showAccountCreatedDate: valueOf('showAccountCreatedDate'),
      showAccountCreatedTime: valueOf('showAccountCreatedTime'),
      showJobTitle: valueOf('showJobTitle'),
      showPhone: valueOf('showPhone'),
      showCountry: valueOf('showCountry'),
      showCounty: valueOf('showCounty'),
      showCity: valueOf('showCity'),
      showYearsExperience: valueOf('showYearsExperience'),
      showEducationLevel: valueOf('showEducationLevel'),
      showEducationInstitution: valueOf('showEducationInstitution'),
      showSpecialization: valueOf('showSpecialization'),
      showCompanyName: valueOf('showCompanyName'),
      showCompanyCounty: valueOf('showCompanyCounty'),
      showCompanyCity: valueOf('showCompanyCity'),
      showHrFirstName: valueOf('showHrFirstName'),
      showHrLastName: valueOf('showHrLastName'),
      showHrEmail: valueOf('showHrEmail'),
      showCv: valueOf('showCv'),
      showProfileSummary: valueOf('showProfileSummary'),
      showProfessionalStatus: valueOf('showProfessionalStatus'),
      showLinkedIn: valueOf('showLinkedIn'),
      showGithub: valueOf('showGithub'),
      showYoutube: valueOf('showYoutube'),
      showInstagram: valueOf('showInstagram'),
      showTiktok: valueOf('showTiktok'),
    );
  }

  Future<void> _saveAll() async {
    if (isSavingProfileDraft || !_hasUnsavedEditProfileChanges) return;

    final accountType = profileData?['accountType'] as String? ?? 'user';

    setState(() => isSavingProfileDraft = true);

    try {
      if (accountType == 'user') {
        await _saveUserProfile();
        await _saveUserExperiences();
        await _saveUserEducations();
        await _saveUserSkills();
        await _saveUserProjects();
      } else {
        await _saveCompanyProfile();
      }

      await _saveVisibilityDraft();

      if (!mounted) return;
      setState(() {
        _captureEditProfileBaseline();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(widget.lang, 'saveChanges'))),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLang, 'loginGenericError'))),
      );
    } finally {
      if (mounted) {
        setState(() => isSavingProfileDraft = false);
      }
    }
  }

  bool get _twoFactorEnabled {
    final user = profileData?['user'] as Map<String, dynamic>? ?? {};
    return user['twoFactorEnabled'] == true;
  }

  bool get _isEmailVerified {
    final user = profileData?['user'] as Map<String, dynamic>? ?? {};
    return user['isEmailVerified'] == true;
  }

  bool get _twoFactorPending {
    final user = profileData?['user'] as Map<String, dynamic>? ?? {};
    return user['twoFactorPending'] == true;
  }

  bool get _isTwoFactorFlowActive {
    return _twoFactorEnabled ||
        _twoFactorPending ||
        (twoFactorQrDataUrl?.isNotEmpty ?? false) ||
        (twoFactorManualEntryKey?.isNotEmpty ?? false);
  }

  Future<void> _resendVerificationEmail() async {
    final token = accessToken;
    if (token == null || token.isEmpty || isEmailVerificationBusy) return;

    setState(() => isEmailVerificationBusy = true);

    try {
      final result = await ApiService.resendEmailVerification(
        accessToken: token,
      );
      if (!mounted) return;

      final alreadyVerified = result['alreadyVerified'] == true;
      final sent = result['verificationEmailSent'] == true;

      if (alreadyVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(currentLang, 'emailVerificationAlreadyVerified')),
          ),
        );
      } else if (sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLang, 'emailVerificationSent'))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLang, 'emailVerificationNotSent'))),
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLang, 'loginGenericError'))),
      );
    } finally {
      if (mounted) {
        setState(() => isEmailVerificationBusy = false);
      }
    }
  }

  Future<void> _handleTabChange(SettingsTab tab) async {
    if (selectedTab == tab) return;

    if (selectedTab == SettingsTab.twoFactor &&
        !_twoFactorEnabled &&
        _isTwoFactorFlowActive) {
      await _cancelTwoFactorSetup(silent: true);
    }

    if (!mounted) return;
    setState(() {
      selectedTab = tab;
      if (tab != SettingsTab.editProfile) {
        _selectedEditProfileSubcategory = null;
      }
    });
  }

  Future<void> _openEditProfileTab({String? sectionId}) async {
    if (selectedTab != SettingsTab.editProfile) {
      await _handleTabChange(SettingsTab.editProfile);
    }

    if (!mounted) return;
    setState(() {
      _selectedEditProfileSubcategory = sectionId;
      if (sectionId != null) {
        _editProfileSectionExpanded[sectionId] = true;
      }
    });
  }

  void _toggleSidebarCollapsed() {
    setState(() => isSidebarCollapsed = !isSidebarCollapsed);
  }

  void _setSettingsState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  List<({String id, String label, IconData icon})> _editProfileSectionsForAccountType(
    String accountType,
  ) {
    if (accountType == 'company') {
      return [
        (
          id: 'account',
          label: t(widget.lang, 'accountDetails'),
          icon: Icons.badge_outlined,
        ),
        (
          id: 'company',
          label: t(widget.lang, 'companyDetails'),
          icon: Icons.apartment_rounded,
        ),
        (
          id: 'hr',
          label: t(widget.lang, 'hrDetails'),
          icon: Icons.groups_2_outlined,
        ),
      ];
    }

    return [
      (
        id: 'account',
        label: t(widget.lang, 'accountDetails'),
        icon: Icons.badge_outlined,
      ),
      (
        id: 'location',
        label: t(widget.lang, 'locationDetails'),
        icon: Icons.location_on_outlined,
      ),
      (
        id: 'profile',
        label: t(widget.lang, 'profileDetails'),
        icon: Icons.person_outline_rounded,
      ),
      (
        id: 'experience',
        label: t(widget.lang, 'experienceSection'),
        icon: Icons.work_outline_rounded,
      ),
      (
        id: 'skills',
        label: t(widget.lang, 'skillsSection'),
        icon: Icons.psychology_alt_outlined,
      ),
      (
        id: 'skills_languages',
        label: t(widget.lang, 'skillsLanguages'),
        icon: Icons.language_rounded,
      ),
      (
        id: 'skills_soft',
        label: t(widget.lang, 'skillsSoft'),
        icon: Icons.self_improvement_rounded,
      ),
      (
        id: 'skills_hard',
        label: t(widget.lang, 'skillsHard'),
        icon: Icons.memory_rounded,
      ),
      (
        id: 'education',
        label: t(widget.lang, 'educationSection'),
        icon: Icons.school_outlined,
      ),
      (
        id: 'projects',
        label: t(widget.lang, 'projectsSection'),
        icon: Icons.developer_board_outlined,
      ),
      (
        id: 'social',
        label: t(widget.lang, 'socialLinks'),
        icon: Icons.share_outlined,
      ),
      (
        id: 'attachments',
        label: t(widget.lang, 'attachments'),
        icon: Icons.attach_file_rounded,
      ),
    ];
  }

  Future<void> _onTwoFactorToggleChanged(bool enabled) async {
    if (isTwoFactorBusy || accessToken == null) return;

    if (enabled) {
      if (!_isTwoFactorFlowActive) {
        await _startTwoFactorSetup();
      }
      return;
    }

    if (_twoFactorEnabled) {
      await _disableTwoFactor();
      return;
    }

    await _cancelTwoFactorSetup();
  }

  Future<void> _cancelTwoFactorSetup({bool silent = false}) async {
    if (accessToken == null) return;

    setState(() => isTwoFactorBusy = true);

    try {
      await ApiService.cancelTwoFactorSetup(accessToken: accessToken!);
      if (!mounted) return;

      setState(() {
        final user = Map<String, dynamic>.from(profileData?['user'] ?? {});
        user['twoFactorEnabled'] = false;
        user['twoFactorPending'] = false;
        profileData = {...(profileData ?? <String, dynamic>{}), 'user': user};
        twoFactorQrDataUrl = null;
        twoFactorManualEntryKey = null;
        generatedBackupCodes = const [];
        twoFactorCodeCtrl.clear();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(currentLang, 'loginGenericError'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isTwoFactorBusy = false);
      }
    }
  }

  Future<void> _startTwoFactorSetup() async {
    if (accessToken == null || isTwoFactorBusy) return;

    setState(() {
      isTwoFactorBusy = true;
      twoFactorCodeCtrl.clear();
    });

    try {
      final result = await ApiService.setupTwoFactor(accessToken: accessToken!);
      if (!mounted) return;

      setState(() {
        twoFactorQrDataUrl = result['qrCodeDataUrl']?.toString();
        twoFactorManualEntryKey = result['manualEntryKey']?.toString();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLang, 'loginGenericError'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          isTwoFactorBusy = false;
        });
      }
    }
  }

  Future<void> _enableTwoFactor() async {
    if (accessToken == null || isTwoFactorBusy) return;

    final code = twoFactorCodeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLang, 'twoFactorInvalidCode'))),
      );
      return;
    }

    setState(() => isTwoFactorBusy = true);

    try {
      await ApiService.enableTwoFactor(accessToken: accessToken!, code: code);
      if (!mounted) return;

      final user = Map<String, dynamic>.from(profileData?['user'] ?? {});
      user['twoFactorEnabled'] = true;

      setState(() {
        profileData = {...(profileData ?? <String, dynamic>{}), 'user': user};
        twoFactorQrDataUrl = null;
        twoFactorManualEntryKey = null;
        generatedBackupCodes = const [];
        twoFactorCodeCtrl.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLang, 'twoFactorEnabledSuccess'))),
      );
    } on ApiException catch (error) {
      if (!mounted) return;

      if (error.code == 'TWO_FACTOR_INVALID') {
        await _cancelTwoFactorSetup(silent: true);
        if (!mounted) return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'TWO_FACTOR_INVALID'
                ? t(currentLang, 'twoFactorInvalidCode')
                : error.message,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLang, 'loginGenericError'))),
      );
    } finally {
      if (mounted) {
        setState(() => isTwoFactorBusy = false);
      }
    }
  }

  Future<void> _disableTwoFactor() async {
    if (accessToken == null || isTwoFactorBusy) return;

    final code = twoFactorCodeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLang, 'twoFactorInvalidCode'))),
      );
      return;
    }

    setState(() => isTwoFactorBusy = true);

    try {
      await ApiService.disableTwoFactor(accessToken: accessToken!, code: code);
      if (!mounted) return;

      final user = Map<String, dynamic>.from(profileData?['user'] ?? {});
      user['twoFactorEnabled'] = false;

      setState(() {
        profileData = {...(profileData ?? <String, dynamic>{}), 'user': user};
        twoFactorQrDataUrl = null;
        twoFactorManualEntryKey = null;
        generatedBackupCodes = const [];
        twoFactorCodeCtrl.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLang, 'twoFactorDisabledSuccess'))),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'TWO_FACTOR_INVALID'
                ? t(currentLang, 'twoFactorInvalidCode')
                : error.message,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLang, 'loginGenericError'))),
      );
    } finally {
      if (mounted) {
        setState(() => isTwoFactorBusy = false);
      }
    }
  }

  Future<void> _regenerateBackupCodes() async {
    if (accessToken == null || isTwoFactorBusy || !_twoFactorEnabled) return;

    final code = twoFactorCodeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLang, 'twoFactorInvalidCode'))),
      );
      return;
    }

    setState(() => isTwoFactorBusy = true);

    try {
      final backupCodes = await ApiService.regenerateTwoFactorBackupCodes(
        accessToken: accessToken!,
        code: code,
      );

      if (!mounted) return;

      setState(() {
        generatedBackupCodes = backupCodes;
        twoFactorCodeCtrl.clear();
      });

      await _showBackupCodesDialog(backupCodes);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'TWO_FACTOR_INVALID'
                ? t(currentLang, 'twoFactorInvalidCode')
                : error.message,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(currentLang, 'loginGenericError'))),
      );
    } finally {
      if (mounted) {
        setState(() => isTwoFactorBusy = false);
      }
    }
  }

  Future<void> _showBackupCodesDialog(List<String> backupCodes) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t(currentLang, 'twoFactorBackupCodesTitle')),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t(currentLang, 'twoFactorBackupCodesDescription')),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    backupCodes.join('\n'),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  t(currentLang, 'twoFactorBackupCodesWarning'),
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t(currentLang, 'ok')),
            ),
          ],
        );
      },
    );
  }

  void _updateVisibility(String field, bool value) {
    setState(() {
      visibility[field] = value;
    });
  }

  Future<void> _uploadCv() async {
    if (accessToken == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
      allowMultiple: false,
      withData: true,
    );

    if (!mounted) return;

    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null) return;

    await ApiService.uploadAttachment(
      accessToken: accessToken!,
      attachmentType: 'cv',
      targetType: 'user',
      bytes: bytes,
      fileName: file?.name ?? 'cv',
      mimeType: _guessMimeType(file?.name ?? ''),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t(widget.lang, 'saveChanges'))));
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
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(child: Text(errorMessage!))
            : _buildSettingsLayout(),
      ),
    );
  }

  Widget _buildRightPanelContent() {
    switch (selectedTab) {
      case SettingsTab.twoFactor:
        return _buildTwoFactorPanel();
      case SettingsTab.changePassword:
        return _buildChangePasswordPanel();
      case SettingsTab.editProfile:
        return _buildEditProfilePanel();
      case SettingsTab.themePreference:
        return _buildThemePreferencePanel();
      case SettingsTab.deleteAccount:
        return _buildDeleteAccountPanel();
    }
  }

  Widget _buildThemePreferencePanel() {
    final lightSelected = !isDefaultThemeDark;
    final darkSelected = isDefaultThemeDark;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(currentLang, 'defaultThemeTitle'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            t(currentLang, 'defaultThemeDescription'),
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChip(
                selected: lightSelected,
                onSelected: (selected) {
                  if (!selected) return;
                  unawaited(_saveDefaultThemePreference(false));
                },
                avatar: const Icon(Icons.light_mode, size: 18),
                label: Text(t(currentLang, 'defaultThemeLight')),
              ),
              ChoiceChip(
                selected: darkSelected,
                onSelected: (selected) {
                  if (!selected) return;
                  unawaited(_saveDefaultThemePreference(true));
                },
                avatar: const Icon(Icons.dark_mode, size: 18),
                label: Text(t(currentLang, 'defaultThemeDark')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
  }
}
