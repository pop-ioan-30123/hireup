import 'dart:convert';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/romania_locations.dart';
import '../core/texts.dart';
import '../pages/profile_page.dart';
import '../services/api_service.dart';
import '../services/secure_storage.dart';
import '../widgets/authenticated_page_shell.dart';

enum SettingsTab {
  twoFactor,
  changePassword,
  editProfile,
  themePreference,
  deleteAccount,
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

  bool isLoading = true;
  String? errorMessage;
  String? accessToken;
  Map<String, dynamic>? profileData;
  Uint8List? avatarBytes;
  late String currentLang;
  late bool currentIsDark;

  SettingsTab selectedTab = SettingsTab.editProfile;
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
  final educationInstitutionCtrl = TextEditingController();

  final companyNameCtrl = TextEditingController();
  final companyCountyCtrl = TextEditingController();
  final companyCityCtrl = TextEditingController();

  String userCountry = 'Romania';
  String? userCounty;
  String? userCity;
  String? userEducationLevel;
  String? accountGender;
  DateTime? accountBirthDate;

  Map<String, bool> visibility = {};

  List<String> get _educationLevels => [
    t(widget.lang, 'educationHighSchool'),
    t(widget.lang, 'educationPostSecondary'),
    t(widget.lang, 'educationBachelor'),
    t(widget.lang, 'educationMaster'),
    t(widget.lang, 'educationDoctorate'),
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
    educationInstitutionCtrl.dispose();

    companyNameCtrl.dispose();
    companyCountyCtrl.dispose();
    companyCityCtrl.dispose();
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
    userEducationLevel = _nullableTrimmed(
      userProfile['educationLevel']?.toString(),
    );
    educationInstitutionCtrl.text =
        userProfile['educationInstitution']?.toString() ?? '';

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
  }

  String _formatBirthDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
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
      educationLevel: userEducationLevel,
      educationInstitution: educationInstitutionCtrl.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t(widget.lang, 'saveChanges'))));
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

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t(widget.lang, 'saveChanges'))));
  }

  Future<void> _saveAll() async {
    final accountType = profileData?['accountType'] as String? ?? 'user';
    if (accountType == 'user') {
      await _saveUserProfile();
    } else {
      await _saveCompanyProfile();
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
    setState(() => selectedTab = tab);
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

  Future<void> _updateVisibility(String field, bool value) async {
    if (accessToken == null) return;

    setState(() {
      visibility[field] = value;
    });

    try {
      await ApiService.updateProfileVisibility(
        accessToken: accessToken!,
        showGender: field == 'showGender' ? value : null,
        showBirthDate: field == 'showBirthDate' ? value : null,
        showJobTitle: field == 'showJobTitle' ? value : null,
        showPhone: field == 'showPhone' ? value : null,
        showCountry: field == 'showCountry' ? value : null,
        showCounty: field == 'showCounty' ? value : null,
        showCity: field == 'showCity' ? value : null,
        showYearsExperience: field == 'showYearsExperience' ? value : null,
        showEducationLevel: field == 'showEducationLevel' ? value : null,
        showEducationInstitution: field == 'showEducationInstitution'
            ? value
            : null,
        showCompanyName: field == 'showCompanyName' ? value : null,
        showCompanyCounty: field == 'showCompanyCounty' ? value : null,
        showCompanyCity: field == 'showCompanyCity' ? value : null,
        showHrFirstName: field == 'showHrFirstName' ? value : null,
        showHrLastName: field == 'showHrLastName' ? value : null,
        showHrEmail: field == 'showHrEmail' ? value : null,
        showCv: field == 'showCv' ? value : null,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        visibility[field] = !value;
      });
    }
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

  Widget _buildSettingsLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 960;

        if (isCompact) {
          return Column(
            children: [
              _buildCompactTabs(),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(child: _buildRightPanelContent()),
              ),
            ],
          );
        }

        final sidebarWidth = isSidebarCollapsed ? 92.0 : 290.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: sidebarWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildSidebar(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Transform.translate(
                      offset: const Offset(16, 0),
                      child: _buildSidebarToggle(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: SingleChildScrollView(child: _buildRightPanelContent()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSidebar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSidebarItem(
            icon: Icons.phonelink_lock,
            label: t(widget.lang, 'settingsTabSecurityVerification'),
            tab: SettingsTab.twoFactor,
          ),
          _buildSidebarItem(
            icon: Icons.lock_reset,
            label: t(widget.lang, 'settingsTabChangePassword'),
            tab: SettingsTab.changePassword,
          ),
          _buildSidebarItem(
            icon: Icons.manage_accounts,
            label: t(widget.lang, 'settingsTabEditProfile'),
            tab: SettingsTab.editProfile,
          ),
          _buildSidebarItem(
            icon: Icons.brightness_6,
            label: t(widget.lang, 'settingsTabThemeDefault'),
            tab: SettingsTab.themePreference,
          ),
          _buildSidebarItem(
            icon: Icons.delete_forever,
            label: t(widget.lang, 'settingsTabDeleteAccount'),
            tab: SettingsTab.deleteAccount,
            isDanger: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required SettingsTab tab,
    bool isDanger = false,
  }) {
    final selected = selectedTab == tab;
    final dangerColor = Colors.red.shade600;

    final content = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        unawaited(_handleTabChange(tab));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? (isDanger
                    ? Colors.red.withValues(alpha: 0.2)
                    : Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.18))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDanger ? dangerColor : null),
            if (!isSidebarCollapsed) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: isDanger ? dangerColor : null),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (!isSidebarCollapsed) return content;

    return Tooltip(message: label, child: content);
  }

  Widget _buildSidebarToggle() {
    return Material(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => isSidebarCollapsed = !isSidebarCollapsed),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            isSidebarCollapsed
                ? Icons.arrow_forward_ios
                : Icons.arrow_back_ios_new,
            size: 14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTabs() {
    final tabs = [
      (
        SettingsTab.twoFactor,
        Icons.phonelink_lock,
        t(widget.lang, 'settingsChipSecurity'),
      ),
      (
        SettingsTab.changePassword,
        Icons.lock_reset,
        t(widget.lang, 'settingsChipPassword'),
      ),
      (
        SettingsTab.editProfile,
        Icons.manage_accounts,
        t(widget.lang, 'settingsTabEditProfile'),
      ),
      (
        SettingsTab.themePreference,
        Icons.brightness_6,
        t(widget.lang, 'settingsChipTheme'),
      ),
      (
        SettingsTab.deleteAccount,
        Icons.delete_forever,
        t(widget.lang, 'settingsChipDelete'),
      ),
    ];

    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final item = tabs[index];
          final tab = item.$1;
          final selected = selectedTab == tab;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) {
              unawaited(_handleTabChange(tab));
            },
            avatar: Icon(item.$2, size: 18),
            label: Text(item.$3),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: tabs.length,
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

  Widget _buildTwoFactorPanel() {
    final qrDataUrl = twoFactorQrDataUrl;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(currentLang, 'settingsTabSecurityVerification'),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final twoFactorSection = Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(currentLang, 'twoFactorTitle'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t(currentLang, 'twoFactorDescription'),
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: _isTwoFactorFlowActive,
                      onChanged: isTwoFactorBusy
                          ? null
                          : _onTwoFactorToggleChanged,
                      title: Text(t(currentLang, 'enable2fa')),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _twoFactorEnabled
                          ? t(currentLang, 'twoFactorStatusEnabled')
                          : t(currentLang, 'twoFactorStatusDisabled'),
                      style: TextStyle(
                        color: _twoFactorEnabled
                            ? Colors.green
                            : Theme.of(context).hintColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isTwoFactorFlowActive && !_twoFactorEnabled) ...[
                      if (qrDataUrl == null)
                        ElevatedButton(
                          onPressed: isTwoFactorBusy
                              ? null
                              : _startTwoFactorSetup,
                          child: Text(t(currentLang, 'twoFactorGenerateQr')),
                        )
                      else ...[
                        Text(t(currentLang, 'twoFactorScanHint')),
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.white,
                            child: Image.network(
                              qrDataUrl,
                              width: 180,
                              height: 180,
                              errorBuilder: (_, _, _) => Text(
                                t(currentLang, 'loginGenericError'),
                                style: TextStyle(
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (twoFactorManualEntryKey != null &&
                            twoFactorManualEntryKey!.isNotEmpty) ...[
                          Text(
                            '${t(currentLang, 'twoFactorManualKey')}: ${twoFactorManualEntryKey!}',
                          ),
                          const SizedBox(height: 10),
                        ],
                        TextField(
                          controller: twoFactorCodeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: t(currentLang, 'twoFactorCode'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: isTwoFactorBusy ? null : _enableTwoFactor,
                          child: Text(t(currentLang, 'twoFactorEnableButton')),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: isTwoFactorBusy
                              ? null
                              : _cancelTwoFactorSetup,
                          child: Text(t(currentLang, 'cancel')),
                        ),
                      ],
                    ] else if (_isTwoFactorFlowActive && _twoFactorEnabled) ...[
                      TextField(
                        controller: twoFactorCodeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: t(currentLang, 'twoFactorCode'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: isTwoFactorBusy
                            ? null
                            : _regenerateBackupCodes,
                        child: Text(
                          t(currentLang, 'twoFactorGenerateBackupCodes'),
                        ),
                      ),
                      if (generatedBackupCodes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          t(currentLang, 'twoFactorBackupCodesGeneratedHint'),
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                      ],
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: isTwoFactorBusy ? null : _disableTwoFactor,
                        child: Text(t(currentLang, 'twoFactorDisableButton')),
                      ),
                    ],
                  ],
                ),
              );

              final verificationSection = Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(currentLang, 'emailVerificationTitle'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t(currentLang, 'emailVerificationDescription'),
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t(currentLang, 'emailVerificationResendAfterThreeDays'),
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isEmailVerified
                          ? t(currentLang, 'emailVerificationStatusVerified')
                          : t(currentLang, 'emailVerificationStatusUnverified'),
                      style: TextStyle(
                        color: _isEmailVerified
                            ? Colors.green
                            : Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: (_isEmailVerified || isEmailVerificationBusy)
                          ? null
                          : _resendVerificationEmail,
                      icon: const Icon(Icons.mark_email_unread_outlined),
                      label: Text(
                        t(currentLang, 'emailVerificationResendButton'),
                      ),
                    ),
                  ],
                ),
              );

              return Column(
                children: [
                  SizedBox(width: double.infinity, child: twoFactorSection),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: verificationSection),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChangePasswordPanel() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(widget.lang, 'changePasswordTitle'),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: currentPasswordCtrl,
            obscureText: !showCurrentPasswordWhilePressed,
            decoration: InputDecoration(
              labelText: t(widget.lang, 'currentPassword'),
              border: const OutlineInputBorder(),
              suffixIcon: _passwordHoldIcon(
                isVisible: showCurrentPasswordWhilePressed,
                onChanged: (visible) =>
                    setState(() => showCurrentPasswordWhilePressed = visible),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: newPasswordCtrl,
            obscureText: !showNewPasswordWhilePressed,
            decoration: InputDecoration(
              labelText: t(widget.lang, 'newPassword'),
              border: const OutlineInputBorder(),
              suffixIcon: _passwordHoldIcon(
                isVisible: showNewPasswordWhilePressed,
                onChanged: (visible) =>
                    setState(() => showNewPasswordWhilePressed = visible),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: confirmPasswordCtrl,
            obscureText: !showConfirmPasswordWhilePressed,
            decoration: InputDecoration(
              labelText: t(widget.lang, 'confirmNewPassword'),
              border: const OutlineInputBorder(),
              suffixIcon: _passwordHoldIcon(
                isVisible: showConfirmPasswordWhilePressed,
                onChanged: (visible) =>
                    setState(() => showConfirmPasswordWhilePressed = visible),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t(widget.lang, 'passwordChangeSoon'))),
              );
            },
            child: Text(t(widget.lang, 'saveChanges')),
          ),
        ],
      ),
    );
  }

  Widget _buildEditProfilePanel() {
    final accountType = profileData?['accountType'] as String? ?? 'user';
    final user = profileData?['user'] as Map<String, dynamic>? ?? {};
    final companyProfile =
        profileData?['companyProfile'] as Map<String, dynamic>? ?? {};

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
              ElevatedButton(
                onPressed: _saveAll,
                child: Text(t(widget.lang, 'saveAll')),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: const RouteSettings(name: '/profile'),
                      builder: (_) => ProfilePage(
                        lang: widget.lang,
                        isDark: widget.isDark,
                        onLangChange: widget.onLangChange,
                        onThemeChange: widget.onThemeChange,
                        onLogout: widget.onLogout,
                      ),
                    ),
                  );
                },
                child: Text(t(widget.lang, 'previewProfile')),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _groupedSection(
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
            ],
          ),

          if (accountType == 'user') ...[
            const SizedBox(height: 16),
            _groupedSection(
              title: t(widget.lang, 'locationDetails'),
              children: [
                _phoneRow(),
                _dropdownRow(
                  label: t(widget.lang, 'country'),
                  visibilityKey: 'showCountry',
                  child: DropdownMenu<String>(
                    initialSelection: userCountry,
                    width: double.infinity,
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
            const SizedBox(height: 16),
            _groupedSection(
              title: t(widget.lang, 'profileDetails'),
              children: [
                _editableRow(
                  label: t(widget.lang, 'professionalTitle'),
                  controller: professionalTitleCtrl,
                  visibilityKey: 'showJobTitle',
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
                _dropdownRow(
                  label: t(widget.lang, 'educationLevel'),
                  visibilityKey: 'showEducationLevel',
                  child: DropdownMenu<String>(
                    key: ValueKey('settings_edu_${userEducationLevel ?? 'none'}'),
                    initialSelection: userEducationLevel,
                    width: double.infinity,
                    enableSearch: true,
                    enableFilter: true,
                    requestFocusOnTap: true,
                    dropdownMenuEntries: _educationLevels
                        .map(
                          (value) =>
                              DropdownMenuEntry(value: value, label: value),
                        )
                        .toList(),
                    onSelected: (value) =>
                        setState(() => userEducationLevel = value),
                  ),
                ),
                _editableRow(
                  label: t(widget.lang, 'lastEducationInstitution'),
                  controller: educationInstitutionCtrl,
                  visibilityKey: 'showEducationInstitution',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _groupedSection(
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
            const SizedBox(height: 16),
            _groupedSection(
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
            const SizedBox(height: 16),
            _groupedSection(
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

  Widget _buildDeleteAccountPanel() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(widget.lang, 'deleteAccountTitle'),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            t(widget.lang, 'deleteAccountDescription'),
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openDeleteAccountDialog,
            icon: const Icon(Icons.warning_amber_rounded),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            label: Text(t(widget.lang, 'deleteAccountButton')),
          ),
        ],
      ),
    );
  }

  Widget _passwordHoldIcon({
    required bool isVisible,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onChanged(true),
      onTapUp: (_) => onChanged(false),
      onTapCancel: () => onChanged(false),
      child: Tooltip(
        message: t(widget.lang, 'showPassword'),
        child: Icon(isVisible ? Icons.visibility : Icons.visibility_off),
      ),
    );
  }

  Future<void> _openDeleteAccountDialog() async {
    final user = profileData?['user'] as Map<String, dynamic>? ?? {};
    final accountEmail = user['email']?.toString().trim().toLowerCase() ?? '';
    bool areDeleteCredentialsValid = false;
    bool isDeleteCredentialsValidating = false;
    int deleteValidationVersion = 0;
    Timer? deleteValidationDebounce;

    Future<void> validateDeleteCredentials(StateSetter setDialogState) async {
      final enteredEmail = deleteAccountEmailCtrl.text.trim().toLowerCase();
      final pass1 = deleteAccountPasswordCtrl.text;
      final pass2 = deleteAccountPasswordConfirmCtrl.text;

      final hasAllValues =
          enteredEmail.isNotEmpty && pass1.isNotEmpty && pass2.isNotEmpty;
      final passesBasicChecks =
          hasAllValues && enteredEmail == accountEmail && pass1 == pass2;

      if (!passesBasicChecks) {
        setDialogState(() {
          areDeleteCredentialsValid = false;
          isDeleteCredentialsValidating = false;
        });
        return;
      }

      final currentVersion = ++deleteValidationVersion;
      setDialogState(() {
        isDeleteCredentialsValidating = true;
        areDeleteCredentialsValid = false;
      });

      try {
        await ApiService.login(email: enteredEmail, password: pass1);

        if (!mounted || currentVersion != deleteValidationVersion) return;

        setDialogState(() {
          isDeleteCredentialsValidating = false;
          areDeleteCredentialsValid = true;
        });
      } catch (_) {
        if (!mounted || currentVersion != deleteValidationVersion) return;

        setDialogState(() {
          isDeleteCredentialsValidating = false;
          areDeleteCredentialsValid = false;
        });
      }
    }

    void queueDeleteCredentialsValidation(StateSetter setDialogState) {
      deleteValidationDebounce?.cancel();
      deleteValidationDebounce = Timer(
        const Duration(milliseconds: 450),
        () => validateDeleteCredentials(setDialogState),
      );
    }

    deleteAccountEmailCtrl.clear();
    deleteAccountPasswordCtrl.clear();
    deleteAccountPasswordConfirmCtrl.clear();
    setState(() {
      showDeletePasswordWhilePressed = false;
      showDeletePasswordConfirmWhilePressed = false;
    });

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(t(widget.lang, 'deleteAccountDialogTitle')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t(widget.lang, 'deleteAccountDialogDescription'),
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deleteAccountEmailCtrl,
                      onChanged: (_) =>
                          queueDeleteCredentialsValidation(setDialogState),
                      decoration: InputDecoration(
                        labelText: t(widget.lang, 'confirmEmail'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: deleteAccountPasswordCtrl,
                      onChanged: (_) =>
                          queueDeleteCredentialsValidation(setDialogState),
                      obscureText: !showDeletePasswordWhilePressed,
                      decoration: InputDecoration(
                        labelText: t(widget.lang, 'password'),
                        border: const OutlineInputBorder(),
                        suffixIcon: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) => setDialogState(
                            () => showDeletePasswordWhilePressed = true,
                          ),
                          onTapUp: (_) => setDialogState(
                            () => showDeletePasswordWhilePressed = false,
                          ),
                          onTapCancel: () => setDialogState(
                            () => showDeletePasswordWhilePressed = false,
                          ),
                          child: Tooltip(
                            message: t(widget.lang, 'showPassword'),
                            child: Icon(
                              showDeletePasswordWhilePressed
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: deleteAccountPasswordConfirmCtrl,
                      onChanged: (_) =>
                          queueDeleteCredentialsValidation(setDialogState),
                      obscureText: !showDeletePasswordConfirmWhilePressed,
                      decoration: InputDecoration(
                        labelText: t(widget.lang, 'confirmPasswordAgain'),
                        border: const OutlineInputBorder(),
                        suffixIcon: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) => setDialogState(
                            () => showDeletePasswordConfirmWhilePressed = true,
                          ),
                          onTapUp: (_) => setDialogState(
                            () => showDeletePasswordConfirmWhilePressed = false,
                          ),
                          onTapCancel: () => setDialogState(
                            () => showDeletePasswordConfirmWhilePressed = false,
                          ),
                          child: Tooltip(
                            message: t(widget.lang, 'showPassword'),
                            child: Icon(
                              showDeletePasswordConfirmWhilePressed
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isDeleteCredentialsValidating) ...[
                      const SizedBox(height: 10),
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(t(widget.lang, 'cancel')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: areDeleteCredentialsValid
                      ? () {
                          final enteredEmail = deleteAccountEmailCtrl.text
                              .trim()
                              .toLowerCase();
                          final pass1 = deleteAccountPasswordCtrl.text;
                          final pass2 = deleteAccountPasswordConfirmCtrl.text;

                          if (enteredEmail != accountEmail) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  t(widget.lang, 'deleteAccountEmailMismatch'),
                                ),
                              ),
                            );
                            return;
                          }

                          if (pass1 != pass2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  t(
                                    widget.lang,
                                    'deleteAccountPasswordMismatch',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                t(widget.lang, 'deleteAccountFlowSoon'),
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Text(t(widget.lang, 'deleteAccountButton')),
                ),
              ],
            );
          },
        );
      },
    );

    deleteValidationDebounce?.cancel();
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: child,
    );
  }

  Widget _subTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _groupedSection({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subTitle(title),
          ...children,
        ],
      ),
    );
  }

  Widget _phoneRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              t(widget.lang, 'phone'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 5,
            child: TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixText: '+40 ',
              ),
            ),
          ),
          const SizedBox(width: 10),
          _visibilityToggle(visibilityKey: 'showPhone'),
        ],
      ),
    );
  }

  Widget _dropdownRow({
    required String label,
    required Widget child,
    required String visibilityKey,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 5, child: child),
          const SizedBox(width: 10),
          _visibilityToggle(visibilityKey: visibilityKey),
        ],
      ),
    );
  }

  Widget _readOnlyRow(
    String label,
    String value, {
    bool alwaysOpen = false,
    bool alwaysLocked = false,
    bool obscure = false,
  }) {
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
          Expanded(
            flex: 5,
            child: TextFormField(
              initialValue: value,
              enabled: false,
              obscureText: obscure,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 10),
          _visibilityToggle(
            visibilityKey: 'disabled',
            isLocked: alwaysLocked,
            isAlwaysOpen: alwaysOpen,
            enabled: false,
          ),
        ],
      ),
    );
  }

  Widget _editableRow({
    required String label,
    required TextEditingController controller,
    required String visibilityKey,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
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
          Expanded(
            flex: 5,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 10),
          _visibilityToggle(visibilityKey: visibilityKey),
        ],
      ),
    );
  }

  Widget _visibilityToggle({
    required String visibilityKey,
    bool isLocked = false,
    bool isAlwaysOpen = false,
    bool enabled = true,
  }) {
    final isOpen = isAlwaysOpen ? true : (visibility[visibilityKey] ?? false);
    final isDisabled = !enabled || isLocked || isAlwaysOpen;

    return ToggleButtons(
      isSelected: [isOpen, !isOpen],
      onPressed: isDisabled
          ? null
          : (index) {
              final next = index == 0;
              _updateVisibility(visibilityKey, next);
            },
      children: const [Icon(Icons.lock_open), Icon(Icons.lock)],
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
