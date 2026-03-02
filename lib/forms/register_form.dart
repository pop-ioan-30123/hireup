import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../core/texts.dart';
import '../core/responsive.dart';
import '../core/romania_locations.dart';
import '../services/api_service.dart';
import '../services/validator.dart';
import '../forms/password_rules.dart';
import '../widgets/gdpr_dialog.dart';

class RegisterFormWidget extends StatefulWidget {
  final TextEditingController firstCtrl;
  final TextEditingController lastCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final TextEditingController hrFirstCtrl;
  final TextEditingController hrLastCtrl;
  final TextEditingController hrEmailCtrl;
  final String lang;
  final bool isDark;
  final bool isUser;
  final bool emailValid;
  final bool emailTouched;
  final bool passwordTouched;
  final bool confirmTouched;
  final bool showPassRules;
  final bool hasLower;
  final bool hasUpper;
  final bool hasNumber;
  final bool hasSpecial;
  final bool passValid;
  final bool match;
  final Function(String) checkEmail;
  final Function(String) checkPassword;
  final Function(bool) onUserTypeChange;
  final Function(bool) onPasswordFocus;
  final Function(bool) onConfirmChange;
  final OutlineInputBorder Function() emailBorder;
  final VoidCallback? onRegisterPress;
  final String Function(String) capitalizeWords;

  const RegisterFormWidget({
    super.key,
    required this.firstCtrl,
    required this.lastCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.hrFirstCtrl,
    required this.hrLastCtrl,
    required this.hrEmailCtrl,
    required this.lang,
    required this.isDark,
    required this.isUser,
    required this.emailValid,
    required this.emailTouched,
    required this.passwordTouched,
    required this.confirmTouched,
    required this.showPassRules,
    required this.hasLower,
    required this.hasUpper,
    required this.hasNumber,
    required this.hasSpecial,
    required this.passValid,
    required this.match,
    required this.checkEmail,
    required this.checkPassword,
    required this.onUserTypeChange,
    required this.onPasswordFocus,
    required this.onConfirmChange,
    required this.emailBorder,
    required this.onRegisterPress,
    required this.capitalizeWords,
  });

  @override
  State<RegisterFormWidget> createState() => _RegisterFormWidgetState();
}

class _RegisterFormWidgetState extends State<RegisterFormWidget> {
  int registrationStep = 1;
  String? accountGender;
  bool hrEmailTouched = false;
  bool hrEmailValid = false;
  final userPhoneCtrl = TextEditingController();
  final userTitleCtrl = TextEditingController();
  bool userPhoneTouched = false;
  bool userPhoneValid = false;
  bool showUserStep2Errors = false;
  bool showUserStep3Errors = false;
  bool isSubmitting = false;
  String? submitError;
  String? userCvAttachmentName;
  Uint8List? userCvAttachmentBytes;
  String userCountry = 'Romania';
  String? userCounty;
  String? userCity;
  bool showRegisterPasswordWhilePressed = false;
  bool showConfirmPasswordWhilePressed = false;
  bool isCheckingStepOneEmail = false;

  bool get _isAccountTypeLocked => registrationStep > 1;

  void _resetLocalStateAfterRegistration() {
    setState(() {
      registrationStep = 1;
      hrEmailTouched = false;
      hrEmailValid = false;

      userPhoneCtrl.clear();
      userTitleCtrl.clear();
      accountGender = null;
      userPhoneTouched = false;
      userPhoneValid = false;
      userCvAttachmentName = null;
      userCvAttachmentBytes = null;
      userCountry = 'Romania';
      userCounty = null;
      userCity = null;
    });
  }

  @override
  void dispose() {
    userPhoneCtrl.dispose();
    userTitleCtrl.dispose();
    super.dispose();
  }

  bool _isPhoneValid(String value) {
    final trimmed = value.trim();
    return RegExp(r'^\d{9}$').hasMatch(trimmed);
  }

  bool get _hasHrRequiredData {
    final hrFirst = widget.hrFirstCtrl.text.trim();
    final hrLast = widget.hrLastCtrl.text.trim();
    final hrEmail = widget.hrEmailCtrl.text.trim();

    return hrFirst.isNotEmpty &&
        hrLast.isNotEmpty &&
        hrEmail.isNotEmpty &&
        EmailValidator.validate(hrEmail);
  }

  bool get _hasUserRequiredData {
    return userPhoneCtrl.text.trim().isNotEmpty &&
        userPhoneValid &&
        userCountry.trim().isNotEmpty &&
        (userCounty?.trim().isNotEmpty ?? false) &&
        (userCity?.trim().isNotEmpty ?? false) &&
        userTitleCtrl.text.trim().isNotEmpty &&
        userCvAttachmentName != null &&
        userCvAttachmentBytes != null;
  }

  Future<void> _pickUserCvAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
      allowMultiple: false,
      withData: true,
    );

    if (!mounted) return;

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        userCvAttachmentName = result.files.first.name;
        userCvAttachmentBytes = result.files.first.bytes;
      });
    }
  }

  OutlineInputBorder _hrEmailBorder() {
    return EmailValidator.getBorder(hrEmailTouched, hrEmailValid);
  }

  OutlineInputBorder _userPhoneBorder() {
    if (!userPhoneTouched) return const OutlineInputBorder();
    return OutlineInputBorder(
      borderSide: BorderSide(
        color: userPhoneValid ? Colors.green : Colors.red,
        width: 2,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant RegisterFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isUser != widget.isUser && registrationStep != 1) {
      setState(() {
        registrationStep = 1;
      });
    }
  }

  bool _isStepOneLocallyValid() {
    final email = widget.emailCtrl.text.trim();
    final baseValid =
        email.isNotEmpty &&
        EmailValidator.validate(email) &&
        widget.passValid &&
        widget.match;

    if (!baseValid) return false;

    final hasAccountBasics = accountGender != null;

    if (widget.isUser) {
      return widget.firstCtrl.text.trim().isNotEmpty &&
          widget.lastCtrl.text.trim().isNotEmpty &&
          hasAccountBasics;
    }

    return widget.firstCtrl.text.trim().isNotEmpty && hasAccountBasics;
  }

  Future<bool> _isStepOneEmailAvailable() async {
    final email = widget.emailCtrl.text.trim();

    setState(() {
      isCheckingStepOneEmail = true;
      submitError = null;
    });

    try {
      final isAvailable = await ApiService.isEmailAvailable(
        email: email,
        locale: widget.lang,
      );
      if (!mounted) return false;

      if (!isAvailable) {
        setState(() {
          submitError = t(widget.lang, 'registerEmailAlreadyExists');
        });
      }

      return isAvailable;
    } on ApiException catch (error) {
      if (!mounted) return false;
      setState(() {
        if (error.code == 'EMAIL_ALREADY_EXISTS') {
          submitError = t(widget.lang, 'registerEmailAlreadyExists');
        } else {
          submitError = error.message;
        }
      });
      return false;
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        submitError = t(widget.lang, 'loginGenericError');
      });
      return false;
    } finally {
      if (mounted) {
        setState(() {
          isCheckingStepOneEmail = false;
        });
      }
    }
  }

  Future<void> _handleRegisterPress() async {
    if (isSubmitting || isCheckingStepOneEmail) return;

    if (registrationStep == 1) {
      if (!_isStepOneLocallyValid()) {
        setState(() {
          submitError = t(widget.lang, 'completeAllFields');
        });
        return;
      }

      final isAvailable = await _isStepOneEmailAvailable();
      if (!mounted || !isAvailable) return;

      setState(() => registrationStep = 2);
    } else if (widget.isUser && registrationStep == 2) {
      if (_isUserStep2Valid()) {
        setState(() {
          showUserStep2Errors = false;
          registrationStep = 3;
        });
      } else {
        setState(() => showUserStep2Errors = true);
      }
    } else if (widget.isUser && registrationStep == 3) {
      if (!_hasUserRequiredData) {
        setState(() => showUserStep3Errors = true);
        return;
      }

      final accepted = await showGdprDialog(
        context: context,
        lang: widget.lang,
        isDark: widget.isDark,
      );

      if (accepted) {
        setState(() {
          isSubmitting = true;
          submitError = null;
        });

        try {
          await ApiService.registerUser(
            email: widget.emailCtrl.text.trim(),
            password: widget.passCtrl.text,
            firstName: widget.firstCtrl.text.trim(),
            lastName: widget.lastCtrl.text.trim(),
            gender: accountGender ?? 'male',
            phone: '+40${userPhoneCtrl.text.trim()}',
            country: userCountry,
            county: userCounty ?? '',
            city: userCity ?? '',
            jobTitle: userTitleCtrl.text.trim(),
            yearsExperience: 0,
            educationLevel: '',
            educationInstitution: '',
            specialization: '',
            gdprVersion: 'v1',
            locale: widget.lang,
          );

          final loginResult = await ApiService.login(
            email: widget.emailCtrl.text.trim(),
            password: widget.passCtrl.text,
            locale: widget.lang,
          );

          await _uploadUserCvAttachment(loginResult.accessToken);

          if (!mounted) return;
          await _showRegisterSuccessDialog();
          if (!mounted) return;
          _resetLocalStateAfterRegistration();
          widget.onRegisterPress?.call();
        } on ApiException catch (error) {
          if (!mounted) return;
          setState(() {
            if (error.code == 'EMAIL_ALREADY_EXISTS') {
              submitError = t(widget.lang, 'registerEmailAlreadyExists');
            } else {
              submitError = error.message;
            }
          });
        } catch (_) {
          if (!mounted) return;
          setState(() {
            submitError = t(widget.lang, 'loginGenericError');
          });
        } finally {
          if (mounted) {
            setState(() {
              isSubmitting = false;
            });
          }
        }
      }
    } else if (!widget.isUser && registrationStep == 2) {
      if (!_hasHrRequiredData) return;

      final accepted = await showGdprDialog(
        context: context,
        lang: widget.lang,
        isDark: widget.isDark,
      );

      if (accepted) {
        setState(() {
          isSubmitting = true;
          submitError = null;
        });

        try {
          await ApiService.registerCompany(
            email: widget.emailCtrl.text.trim(),
            password: widget.passCtrl.text,
            companyName: widget.firstCtrl.text.trim(),
            hrFirstName: widget.hrFirstCtrl.text.trim(),
            hrLastName: widget.hrLastCtrl.text.trim(),
            hrEmail: widget.hrEmailCtrl.text.trim(),
            gender: accountGender ?? 'male',
            gdprVersion: 'v1',
            locale: widget.lang,
          );

          if (!mounted) return;

          await ApiService.login(
            email: widget.emailCtrl.text.trim(),
            password: widget.passCtrl.text,
            locale: widget.lang,
          );

          if (!mounted) return;
          await _showRegisterSuccessDialog();
          if (!mounted) return;
          _resetLocalStateAfterRegistration();
          widget.onRegisterPress?.call();
        } on ApiException catch (error) {
          if (!mounted) return;
          setState(() {
            if (error.code == 'EMAIL_ALREADY_EXISTS') {
              submitError = t(widget.lang, 'registerEmailAlreadyExists');
            } else {
              submitError = error.message;
            }
          });
        } catch (_) {
          if (!mounted) return;
          setState(() {
            submitError = t(widget.lang, 'loginGenericError');
          });
        } finally {
          if (mounted) {
            setState(() {
              isSubmitting = false;
            });
          }
        }
      }
    } else {
      widget.onRegisterPress?.call();
    }
  }

  bool _isUserStep2Valid() {
    return userPhoneCtrl.text.trim().isNotEmpty &&
        userPhoneValid &&
        userCountry.isNotEmpty &&
        (userCounty?.isNotEmpty ?? false) &&
        (userCity?.isNotEmpty ?? false);
  }

  void _goBack() {
    if (registrationStep <= 1) return;
    setState(() => registrationStep = registrationStep - 1);
  }

  Future<void> _showRegisterSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 60,
              ),
              const SizedBox(height: 12),
              Text(
                t(widget.lang, 'registerSuccessTitle'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                t(widget.lang, 'registerSuccessMessage'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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

  Future<void> _uploadUserCvAttachment(String token) async {
    if (userCvAttachmentBytes == null) return;

    await ApiService.uploadAttachment(
      accessToken: token,
      attachmentType: 'cv',
      targetType: 'user',
      bytes: userCvAttachmentBytes!,
      fileName: userCvAttachmentName ?? 'cv',
      mimeType: _guessMimeType(userCvAttachmentName ?? ''),
    );
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  List<DropdownMenuEntry<String>> _entriesFrom(List<String> values) {
    return values
        .map((value) => DropdownMenuEntry(value: value, label: value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Responsive.spacing(
      context: context,
      mobile: 12,
      tablet: 16,
      desktop: 20,
    );

    final isMobile = Responsive.isMobile(context);
    final fontSize = isMobile ? 14.0 : 16.0;

    return Column(
      children: [
        // User/Company toggle - disabled in step 2
        Center(
          child: Opacity(
            opacity: _isAccountTypeLocked ? 0.5 : 1.0,
            child: IgnorePointer(
              ignoring: _isAccountTypeLocked,
              child: SizedBox(
                height: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _AnimatedChoiceButton(
                          label: t(widget.lang, "user"),
                          selected: widget.isUser,
                          onTap: () => widget.onUserTypeChange(true),
                          gradient: const [
                            Colors.purpleAccent,
                            Colors.deepPurple,
                          ],
                          textStyle: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _AnimatedChoiceButton(
                          label: t(widget.lang, "company"),
                          selected: !widget.isUser,
                          onTap: () => widget.onUserTypeChange(false),
                          gradient: const [Colors.blueAccent, Colors.purple],
                          textStyle: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: spacing),

        // STEP 1: User/Company details
        if (registrationStep == 1) ...[
          if (widget.isUser) ...[
            // User: First + Last name
            TextField(
              controller: widget.firstCtrl,
              onChanged: (v) {
                final cap = widget.capitalizeWords(v);
                widget.firstCtrl.value = widget.firstCtrl.value.copyWith(
                  text: cap,
                );
              },
              decoration: InputDecoration(
                labelText: t(widget.lang, "first"),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(width: 2),
                ),
                isDense: isMobile,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: isMobile ? 8 : 12,
                ),
              ),
            ),
            SizedBox(height: spacing),
            TextField(
              controller: widget.lastCtrl,
              onChanged: (v) {
                final cap = widget.capitalizeWords(v);
                widget.lastCtrl.value = widget.lastCtrl.value.copyWith(
                  text: cap,
                );
              },
              decoration: InputDecoration(
                labelText: t(widget.lang, "last"),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(width: 2),
                ),
                isDense: isMobile,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: isMobile ? 8 : 12,
                ),
              ),
            ),
            SizedBox(height: spacing),
          ] else ...[
            // Company: Company name only
            TextField(
              controller: widget.firstCtrl,
              onChanged: (v) {
                final cap = widget.capitalizeWords(v);
                widget.firstCtrl.value = widget.firstCtrl.value.copyWith(
                  text: cap,
                );
              },
              decoration: InputDecoration(
                labelText: t(widget.lang, "companyName"),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(width: 2),
                ),
                isDense: isMobile,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: isMobile ? 8 : 12,
                ),
              ),
            ),
            SizedBox(height: spacing),
          ],

          DropdownMenu<String>(
            key: ValueKey('register_gender_${accountGender ?? 'none'}'),
            initialSelection: accountGender,
            width: double.infinity,
            menuHeight: 280,
            label: Text(t(widget.lang, 'gender')),
            dropdownMenuEntries: [
              DropdownMenuEntry(
                value: 'male',
                label: t(widget.lang, 'genderMale'),
              ),
              DropdownMenuEntry(
                value: 'female',
                label: t(widget.lang, 'genderFemale'),
              ),
            ],
            onSelected: (value) {
              setState(() => accountGender = value);
            },
          ),
          SizedBox(height: spacing),

          // Email (all users)
          TextField(
            controller: widget.emailCtrl,
            onChanged: widget.checkEmail,
            decoration: InputDecoration(
              labelText: t(widget.lang, "email"),
              border: OutlineInputBorder(),
              enabledBorder: widget.emailBorder(),
              focusedBorder: widget.emailBorder(),
              isDense: isMobile,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: isMobile ? 8 : 12,
              ),
            ),
          ),
          SizedBox(height: spacing),

          // Password
          Focus(
            onFocusChange: (f) => widget.onPasswordFocus(f),
            child: TextField(
              controller: widget.passCtrl,
              obscureText: !showRegisterPasswordWhilePressed,
              onChanged: widget.checkPassword,
              decoration: InputDecoration(
                labelText: t(widget.lang, "password"),
                suffixIcon: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) =>
                      setState(() => showRegisterPasswordWhilePressed = true),
                  onTapUp: (_) =>
                      setState(() => showRegisterPasswordWhilePressed = false),
                  onTapCancel: () =>
                      setState(() => showRegisterPasswordWhilePressed = false),
                  child: Tooltip(
                    message: t(widget.lang, 'showPassword'),
                    child: Icon(
                      showRegisterPasswordWhilePressed
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
                border: const OutlineInputBorder(),
                enabledBorder: widget.passwordTouched
                    ? OutlineInputBorder(
                        borderSide: BorderSide(
                          color: widget.passValid ? Colors.green : Colors.red,
                        ),
                      )
                    : const OutlineInputBorder(),
                focusedBorder: widget.passwordTouched
                    ? OutlineInputBorder(
                        borderSide: BorderSide(
                          color: widget.passValid ? Colors.green : Colors.red,
                          width: 2,
                        ),
                      )
                    : OutlineInputBorder(borderSide: BorderSide(width: 2)),
                isDense: isMobile,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: isMobile ? 8 : 12,
                ),
              ),
            ),
          ),
          if (widget.showPassRules) ...[
            SizedBox(height: spacing),
            PasswordRulesWidget(
              isDark: widget.isDark,
              hasLower: widget.hasLower,
              hasUpper: widget.hasUpper,
              hasNumber: widget.hasNumber,
              hasSpecial: widget.hasSpecial,
              lang: widget.lang,
            ),
          ],
          SizedBox(height: spacing),

          // Confirm Password
          TextField(
            controller: widget.confirmCtrl,
            obscureText: !showConfirmPasswordWhilePressed,
            onChanged: (_) => widget.onConfirmChange(
              widget.confirmCtrl.text == widget.passCtrl.text,
            ),
            decoration: InputDecoration(
              labelText: t(widget.lang, "confirm"),
              suffixIcon: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) =>
                    setState(() => showConfirmPasswordWhilePressed = true),
                onTapUp: (_) =>
                    setState(() => showConfirmPasswordWhilePressed = false),
                onTapCancel: () =>
                    setState(() => showConfirmPasswordWhilePressed = false),
                child: Tooltip(
                  message: t(widget.lang, 'showPassword'),
                  child: Icon(
                    showConfirmPasswordWhilePressed
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
              ),
              border: const OutlineInputBorder(),
              enabledBorder: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(width: 2),
              ),
              isDense: isMobile,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: isMobile ? 8 : 12,
              ),
            ),
          ),
          if (widget.confirmTouched && !widget.match) ...[
            SizedBox(height: spacing / 2),
            Text(
              t(widget.lang, "passMismatch"),
              style: TextStyle(color: Colors.red, fontSize: isMobile ? 12 : 14),
            ),
          ],
        ] else if (widget.isUser && registrationStep == 2) ...[
          Text(
            t(widget.lang, "userLocationSection"),
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: spacing),
          TextField(
            controller: userPhoneCtrl,
            onChanged: (value) {
              setState(() {
                userPhoneTouched = true;
                userPhoneValid = _isPhoneValid(value);
              });
            },
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            maxLength: 9,
            decoration: InputDecoration(
              labelText: t(widget.lang, "phone"),
              prefixText: '+40 ',
              border: const OutlineInputBorder(),
              enabledBorder: _userPhoneBorder(),
              focusedBorder: _userPhoneBorder(),
              isDense: isMobile,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: isMobile ? 8 : 12,
              ),
            ),
          ),
          SizedBox(height: spacing),
          DropdownMenu<String>(
            key: const ValueKey('country_fixed_ro'),
            initialSelection: userCountry,
            enabled: false,
            width: double.infinity,
            menuHeight: 280,
            label: Text(t(widget.lang, "country")),
            dropdownMenuEntries: _entriesFrom(RomaniaLocations.countries),
            onSelected: null,
          ),
          SizedBox(height: spacing),
          DropdownMenu<String>(
            key: ValueKey('county_${userCounty ?? 'none'}'),
            initialSelection: userCounty,
            width: double.infinity,
            menuHeight: 280,
            enableSearch: true,
            enableFilter: true,
            requestFocusOnTap: true,
            label: Text(t(widget.lang, "county")),
            dropdownMenuEntries: _entriesFrom(RomaniaLocations.counties),
            onSelected: (value) {
              if (value == null) return;
              setState(() {
                userCounty = value;
                userCity = null;
              });
            },
          ),
          if (showUserStep2Errors && userCounty == null) ...[
            SizedBox(height: spacing / 2),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t(widget.lang, "selectedValueMissing"),
                style: TextStyle(
                  color: Colors.red,
                  fontSize: isMobile ? 12 : 13,
                ),
              ),
            ),
          ],
          SizedBox(height: spacing),
          DropdownMenu<String>(
            key: ValueKey('city_${userCounty ?? 'none'}'),
            initialSelection: userCity,
            width: double.infinity,
            menuHeight: 280,
            enableSearch: true,
            enableFilter: true,
            requestFocusOnTap: true,
            label: Text(t(widget.lang, "city")),
            dropdownMenuEntries: _entriesFrom(
              RomaniaLocations.localitiesForCounty(userCounty),
            ),
            onSelected: (value) {
              if (value == null) return;
              setState(() {
                userCity = value;
              });
            },
          ),
          if (showUserStep2Errors && userCity == null) ...[
            SizedBox(height: spacing / 2),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t(widget.lang, "selectedValueMissing"),
                style: TextStyle(
                  color: Colors.red,
                  fontSize: isMobile ? 12 : 13,
                ),
              ),
            ),
          ],
        ] else ...[
          if (widget.isUser && registrationStep == 3) ...[
            TextField(
              controller: userTitleCtrl,
              onChanged: (v) {
                final cap = widget.capitalizeWords(v);
                userTitleCtrl.value = userTitleCtrl.value.copyWith(text: cap);
                setState(() {});
              },
              decoration: InputDecoration(
                labelText: t(widget.lang, "professionalTitle"),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(width: 2),
                ),
                isDense: isMobile,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: isMobile ? 8 : 12,
                ),
              ),
            ),
            SizedBox(height: spacing),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t(widget.lang, "cvAttachmentSection"),
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: spacing / 2),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickUserCvAttachment,
                    icon: const Icon(Icons.upload_file),
                    label: Text(t(widget.lang, "uploadCv")),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing / 2),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                userCvAttachmentName == null
                    ? t(widget.lang, "cvAttachmentMissing")
                    : "${t(widget.lang, "cvAttachmentSelected")}: $userCvAttachmentName",
                style: TextStyle(
                  color: userCvAttachmentName == null
                      ? Colors.red
                      : Colors.green,
                  fontSize: isMobile ? 12 : 13,
                ),
              ),
            ),
            if (showUserStep3Errors && !_hasUserRequiredData)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t(widget.lang, "completeAllFields"),
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ),
          ] else ...[
            Text(
              t(widget.lang, "hrContactSection"),
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: spacing),

            TextField(
              controller: widget.firstCtrl,
              enabled: false,
              decoration: InputDecoration(
                labelText: t(widget.lang, "companyName"),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                ),
                isDense: isMobile,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: isMobile ? 8 : 12,
                ),
                filled: true,
                fillColor: Colors.grey.withValues(alpha: 0.1),
              ),
            ),
            SizedBox(height: spacing),

            TextField(
              controller: widget.emailCtrl,
              enabled: false,
              decoration: InputDecoration(
                labelText: t(widget.lang, "email"),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                ),
                isDense: isMobile,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: isMobile ? 8 : 12,
                ),
                filled: true,
                fillColor: Colors.grey.withValues(alpha: 0.1),
              ),
            ),
            SizedBox(height: spacing),

            TextField(
              controller: widget.hrFirstCtrl,
              onChanged: (v) {
                final cap = widget.capitalizeWords(v);
                widget.hrFirstCtrl.value = widget.hrFirstCtrl.value.copyWith(
                  text: cap,
                );
                setState(() {});
              },
              decoration: InputDecoration(
                labelText: t(widget.lang, "hrFirstName"),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(width: 2),
                ),
                isDense: isMobile,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: isMobile ? 8 : 12,
                ),
              ),
            ),
            SizedBox(height: spacing),

            TextField(
              controller: widget.hrLastCtrl,
              onChanged: (v) {
                final cap = widget.capitalizeWords(v);
                widget.hrLastCtrl.value = widget.hrLastCtrl.value.copyWith(
                  text: cap,
                );
                setState(() {});
              },
              decoration: InputDecoration(
                labelText: t(widget.lang, "hrLastName"),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(width: 2),
                ),
                isDense: isMobile,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: isMobile ? 8 : 12,
                ),
              ),
            ),
            SizedBox(height: spacing),

            TextField(
              controller: widget.hrEmailCtrl,
              onChanged: (value) {
                setState(() {
                  hrEmailTouched = true;
                  hrEmailValid = EmailValidator.validate(value);
                });
              },
              decoration: InputDecoration(
                labelText: t(widget.lang, "hrEmail"),
                border: const OutlineInputBorder(),
                enabledBorder: _hrEmailBorder(),
                focusedBorder: _hrEmailBorder(),
                isDense: isMobile,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: isMobile ? 8 : 12,
                ),
              ),
            ),
          ],
        ],

        SizedBox(height: spacing),

        if (submitError != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              submitError!,
              style: TextStyle(color: Colors.red, fontSize: isMobile ? 12 : 13),
            ),
          ),
          SizedBox(height: spacing / 2),
        ],

        // Buttons
        if ((widget.isUser &&
                (registrationStep == 2 || registrationStep == 3)) ||
            (!widget.isUser && registrationStep == 2))
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _goBack,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                  ),
                  child: Text(
                    t(widget.lang, "back"),
                    style: TextStyle(fontSize: fontSize),
                  ),
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.tab) {
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: ElevatedButton(
                    onPressed:
                        !isSubmitting &&
                            !isCheckingStepOneEmail &&
                            widget.passValid &&
                            widget.match &&
                            (widget.isUser
                                ? (registrationStep == 2
                                      ? _isUserStep2Valid()
                                      : _hasUserRequiredData)
                                : _hasHrRequiredData)
                        ? _handleRegisterPress
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 12 : 16,
                      ),
                    ),
                    child: Text(
                      isSubmitting
                          ? '${t(widget.lang, "register")}...'
                          : widget.isUser && registrationStep == 2
                          ? t(widget.lang, "next")
                          : t(widget.lang, "register"),
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          SizedBox(
            width: double.infinity,
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.tab) {
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: ElevatedButton(
                onPressed:
                    (!isSubmitting && widget.passValid && widget.match) &&
                        !isCheckingStepOneEmail
                    ? _handleRegisterPress
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                ),
                child: Text(
                  isSubmitting
                      ? '${t(widget.lang, "register")}...'
                      : isCheckingStepOneEmail
                      ? '${t(widget.lang, "next")}...'
                      : widget.isUser
                      ? t(widget.lang, "next")
                      : t(widget.lang, "register"),
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimatedChoiceButton extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final List<Color> gradient;
  final TextStyle textStyle;

  const _AnimatedChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.gradient,
    required this.textStyle,
  });

  @override
  State<_AnimatedChoiceButton> createState() => _AnimatedChoiceButtonState();
}

class _AnimatedChoiceButtonState extends State<_AnimatedChoiceButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final scale = _isPressed ? 0.98 : (_isHovering ? 1.02 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() {
        _isHovering = false;
        _isPressed = false;
      }),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: scale),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        builder: (context, animatedScale, child) {
          return Transform.scale(scale: animatedScale, child: child);
        },
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapCancel: () => setState(() => _isPressed = false),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: widget.selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.gradient,
                    )
                  : null,
              color: widget.selected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: widget.gradient.last.withValues(alpha: 0.40),
                        blurRadius: _isHovering ? 14 : 9,
                        spreadRadius: _isHovering ? 1.0 : 0,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                style: widget.textStyle.copyWith(
                  color: widget.selected ? Colors.white : onSurface,
                ),
                child: Text(widget.label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
