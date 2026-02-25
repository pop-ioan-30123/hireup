import 'package:flutter/material.dart';
import 'dart:async';
import 'core/texts.dart';
import 'core/mode.dart';
import 'core/responsive.dart';
import 'services/api_service.dart';
import 'services/secure_storage.dart';
import 'services/validator.dart';
import 'pages/home_page.dart';
import 'widgets/top_bar.dart';
import 'widgets/auth_buttons.dart';
import 'widgets/desktop_hero_panel.dart';
import 'widgets/auth_form_carousel.dart';
import 'widgets/lamp_transition_overlay.dart';
import 'widgets/forgot_password_dialog.dart' as forgot_dialog;

void main() {
  runApp(const CareerSuitUpApp());
}

class CareerSuitUpApp extends StatefulWidget {
  const CareerSuitUpApp({super.key});

  @override
  State<CareerSuitUpApp> createState() => _CareerSuitUpAppState();
}

class _CareerSuitUpAppState extends State<CareerSuitUpApp> {
  ThemeMode themeMode = ThemeMode.light;
  String lang = "RO";

  @override
  void initState() {
    super.initState();
    setActiveLanguage(lang);
  }

  void toggleTheme(bool dark) {
    setState(() {
      themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void changeLang(String l) {
    setState(() => lang = l);
    setActiveLanguage(l);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: StartPage(
        lang: lang,
        onLangChange: changeLang,
        onThemeChange: toggleTheme,
        isDark: themeMode == ThemeMode.dark,
      ),
    );
  }
}

/// ================= PAGE =================

class StartPage extends StatefulWidget {
  final String lang;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final bool isDark;

  const StartPage({
    super.key,
    required this.lang,
    required this.onLangChange,
    required this.onThemeChange,
    required this.isDark,
  });

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> with TickerProviderStateMixin {
  Mode mode = Mode.login;
  bool remember = false;
  bool isUser = true;

  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final firstCtrl = TextEditingController();
  final lastCtrl = TextEditingController();
  final hrFirstCtrl = TextEditingController();
  final hrLastCtrl = TextEditingController();
  final hrEmailCtrl = TextEditingController();

  bool emailValid = false;
  bool emailTouched = false;

  bool hasLower = false;
  bool hasUpper = false;
  bool hasNumber = false;
  bool hasSpecial = false;
  bool match = true;
  bool showPassRules = false;
  bool passwordTouched = false;
  bool confirmTouched = false;
  bool isLoginLoading = false;
  int loginCooldownSeconds = 0;
  String? loginErrorMessage;
  Timer? _loginCooldownTimer;

  // Carousel scroll controller for form switching
  late final ScrollController _formScrollController;

  // Lamp / light-off animation
  late final AnimationController _lampController;
  late final AnimationController _glowController;
  late final Animation<double> _overlayOpacity;
  late final Animation<double> _lampFade;
  late final Animation<double> _ropeOffset;
  late final Animation<double> _glowRadius;
  bool _lampVisible = false;
  bool _isTurningToDark = false;
  String? _savedEmail;
  String? _savedPassword;

  /// ================= VALIDATIONS =================

  void checkEmail(String v) {
    final ok = EmailValidator.validate(v);

    setState(() {
      emailTouched = true;
      emailValid = ok;
    });
  }

  OutlineInputBorder emailBorder() {
    return EmailValidator.getBorder(emailTouched, emailValid);
  }

  void checkPassword(String v) {
    setState(() {
      hasLower = v.contains(RegExp(r'[a-z]'));
      hasUpper = v.contains(RegExp(r'[A-Z]'));
      hasNumber = v.contains(RegExp(r'[0-9]'));
      hasSpecial = v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      match = confirmCtrl.text == v;
    });
  }

  bool get passValid => hasLower && hasUpper && hasNumber && hasSpecial;

  /// ================= AUTO CAPITALIZE =================

  String capitalizeWords(String text) {
    return text
        .split(" ")
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(" ");
  }

  @override
  Widget build(BuildContext context) {
    final dropColor = widget.isDark ? Colors.white : Colors.black;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isMobileView = width < ResponsiveBreakpoints.tablet;
          final isTabletView =
              width >= ResponsiveBreakpoints.tablet &&
              width < ResponsiveBreakpoints.desktop;

          return Stack(
            children: [
              // Main content - adjust layout based on screen size
              if (isMobileView)
                _buildMobileLayout(dropColor)
              else if (isTabletView)
                _buildTabletLayout(dropColor)
              else
                _buildDesktopLayout(dropColor),
              LampTransitionOverlay(
                lampVisible: _lampVisible,
                lampController: _lampController,
                glowController: _glowController,
                overlayOpacity: _overlayOpacity,
                lampFade: _lampFade,
                ropeOffset: _ropeOffset,
                glowRadius: _glowRadius,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Mobile layout - stacked vertically
  Widget _buildMobileLayout(Color dropColor) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple, Colors.deepPurple],
        ),
      ),
      child: Column(
        children: [
          TopBarWidget(
            lang: widget.lang,
            isDark: widget.isDark,
            onLangChange: widget.onLangChange,
            onThemeChange: _startLampTransition,
          ),
          AuthButtonsWidget(
            mode: mode,
            onModeChange: (newMode) => setState(() => mode = newMode),
            lang: widget.lang,
          ),
          Expanded(child: _buildAuthFormCarousel()),
        ],
      ),
    );
  }

  /// Tablet layout - slightly more spacious
  Widget _buildTabletLayout(Color dropColor) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple, Colors.deepPurple],
        ),
      ),
      child: Column(
        children: [
          TopBarWidget(
            lang: widget.lang,
            isDark: widget.isDark,
            onLangChange: widget.onLangChange,
            onThemeChange: _startLampTransition,
          ),
          AuthButtonsWidget(
            mode: mode,
            onModeChange: (newMode) => setState(() => mode = newMode),
            lang: widget.lang,
          ),
          Expanded(
            child: Center(
              child: SizedBox(width: 600, child: _buildAuthFormCarousel()),
            ),
          ),
        ],
      ),
    );
  }

  /// Desktop layout - side by side with decorative elements
  Widget _buildDesktopLayout(Color dropColor) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple, Colors.deepPurple],
        ),
      ),
      child: Column(
        children: [
          TopBarWidget(
            lang: widget.lang,
            isDark: widget.isDark,
            onLangChange: widget.onLangChange,
            onThemeChange: _startLampTransition,
          ),
          Expanded(
            child: Row(
              children: [
                // Left side - decorative: place combined text+image block at a responsive vertical position
                Expanded(
                  flex: 1,
                  child: DesktopHeroPanel(lang: widget.lang, mode: mode),
                ),
                // Right side - form
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: AuthButtonsWidget(
                          mode: mode,
                          onModeChange: (newMode) =>
                              setState(() => mode = newMode),
                          lang: widget.lang,
                        ),
                      ),
                      Expanded(child: _buildAuthFormCarousel()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthFormCarousel() {
    return AuthFormCarousel(
      mode: mode,
      isDark: widget.isDark,
      lang: widget.lang,
      formScrollController: _formScrollController,
      emailCtrl: emailCtrl,
      passCtrl: passCtrl,
      confirmCtrl: confirmCtrl,
      firstCtrl: firstCtrl,
      lastCtrl: lastCtrl,
      hrFirstCtrl: hrFirstCtrl,
      hrLastCtrl: hrLastCtrl,
      hrEmailCtrl: hrEmailCtrl,
      remember: remember,
      isUser: isUser,
      emailValid: emailValid,
      emailTouched: emailTouched,
      passwordTouched: passwordTouched,
      confirmTouched: confirmTouched,
      showPassRules: showPassRules,
      hasLower: hasLower,
      hasUpper: hasUpper,
      hasNumber: hasNumber,
      hasSpecial: hasSpecial,
      passValid: passValid,
      match: match,
      checkEmail: checkEmail,
      onRememberChange: (value) => setState(() => remember = value),
      onEmailFieldTap: _applyRememberedCredentials,
      checkPassword: checkPassword,
      onUserTypeChange: (newVal) => setState(() => isUser = newVal),
      onPasswordFocus: (f) => setState(() {
        showPassRules = f;
        if (f) passwordTouched = true;
      }),
      onConfirmChange: (matched) => setState(() {
        confirmTouched = true;
        match = matched;
      }),
      emailBorder: emailBorder,
      showForgotPasswordDialog: showForgotPasswordDialog,
      onLoginPress: _handleLoginPress,
      isLoginLoading: isLoginLoading,
      loginCooldownSeconds: loginCooldownSeconds,
      loginErrorMessage: loginErrorMessage,
      onRegisterPress: _handleRegisterCompleted,
      capitalizeWords: capitalizeWords,
    );
  }

  Future<void> _handleLoginPress() async {
    if (isLoginLoading || loginCooldownSeconds > 0) return;

    setState(() {
      isLoginLoading = true;
      loginErrorMessage = null;
    });

    try {
      final result = await ApiService.login(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
      );
      await _completeLogin(result);
    } on ApiException catch (error) {
      if (!mounted) return;

      if (error.code == 'EMAIL_NOT_FOUND') {
        setState(() {
          loginErrorMessage = t(widget.lang, 'loginEmailNotFound');
        });
      } else if (error.code == 'WRONG_PASSWORD') {
        setState(() {
          loginErrorMessage = t(widget.lang, 'loginWrongPassword');
        });
        _startLoginCooldown(error.retryAfterSeconds ?? 10);
      } else if (error.code == 'TWO_FACTOR_REQUIRED') {
        final secondFactorResult = await _requestTwoFactorAndLogin();
        if (!mounted) return;

        if (secondFactorResult != null) {
          await _completeLogin(secondFactorResult);
          return;
        }

        setState(() {
          loginErrorMessage = t(widget.lang, 'loginTwoFactorRequired');
        });
      } else {
        setState(() {
          loginErrorMessage = error.message;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loginErrorMessage = t(widget.lang, 'loginGenericError');
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoginLoading = false;
        });
      }
    }
  }

  Future<LoginResult?> _requestTwoFactorAndLogin() async {
    return showDialog<LoginResult>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _TwoFactorLoginDialog(
          lang: widget.lang,
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
        );
      },
    );
  }

  Future<void> _completeLogin(LoginResult result) async {
    await SecureStorage.write('access_token', result.accessToken);
    await SecureStorage.write('refresh_token', result.refreshToken);

    if (remember) {
      await SecureStorage.write('remember_credentials', 'true');
      await SecureStorage.write('remember_email', emailCtrl.text.trim());
      await SecureStorage.write('remember_password', passCtrl.text);
    } else {
      await SecureStorage.delete('remember_credentials');
      await SecureStorage.delete('remember_email');
      await SecureStorage.delete('remember_password');
    }

    try {
      final profile = await ApiService.getProfile(accessToken: result.accessToken);
      final user = profile['user'] as Map<String, dynamic>? ?? {};
      final defaultTheme = user['defaultTheme']?.toString() ?? 'light';
      widget.onThemeChange(defaultTheme == 'dark');
    } catch (_) {}

    if (!mounted) return;

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: '/home'),
        transitionDuration: const Duration(milliseconds: 480),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => HomePage(
          lang: widget.lang,
          isDark: widget.isDark,
          onLangChange: widget.onLangChange,
          onThemeChange: widget.onThemeChange,
          onLogout: _handleLogout,
        ),
        transitionsBuilder: (_, animation, _, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );
          final slide =
              Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );

          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }

  void _startLoginCooldown(int seconds) {
    _loginCooldownTimer?.cancel();

    setState(() {
      loginCooldownSeconds = seconds;
    });

    _loginCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (loginCooldownSeconds <= 1) {
        timer.cancel();
        setState(() {
          loginCooldownSeconds = 0;
        });
        return;
      }

      setState(() {
        loginCooldownSeconds -= 1;
      });
    });
  }

  void _handleRegisterCompleted() {
    setState(() {
      firstCtrl.clear();
      lastCtrl.clear();
      emailCtrl.clear();
      passCtrl.clear();
      confirmCtrl.clear();
      hrFirstCtrl.clear();
      hrLastCtrl.clear();
      hrEmailCtrl.clear();

      emailValid = false;
      emailTouched = false;
      hasLower = false;
      hasUpper = false;
      hasNumber = false;
      hasSpecial = false;
      match = true;
      showPassRules = false;
      passwordTouched = false;
      confirmTouched = false;
    });
  }

  Future<void> _handleLogout() async {
    await SecureStorage.delete('access_token');
    await SecureStorage.delete('refresh_token');

    if (!mounted) return;
    setState(() {
      mode = Mode.login;
      passCtrl.clear();
      loginErrorMessage = null;
      isLoginLoading = false;
      loginCooldownSeconds = 0;
    });
  }

  void _applyRememberedCredentials() {
    if (!remember || _savedEmail == null || _savedPassword == null) return;

    final current = emailCtrl.text.trim();
    if (current.isEmpty || current == _savedEmail) {
      setState(() {
        emailCtrl.text = _savedEmail!;
        passCtrl.text = _savedPassword!;
        emailTouched = true;
        emailValid = EmailValidator.validate(_savedEmail!);
      });
    }
  }

  Future<void> _loadRememberedCredentials() async {
    final rememberFlag = await SecureStorage.read('remember_credentials');
    final savedEmail = await SecureStorage.read('remember_email');
    final savedPassword = await SecureStorage.read('remember_password');

    if (!mounted) return;

    final shouldRemember =
        rememberFlag == 'true' &&
        savedEmail != null &&
        savedEmail.isNotEmpty &&
        savedPassword != null &&
        savedPassword.isNotEmpty;

    setState(() {
      remember = shouldRemember;
      _savedEmail = shouldRemember ? savedEmail : null;
      _savedPassword = shouldRemember ? savedPassword : null;

      if (shouldRemember) {
        emailCtrl.text = savedEmail;
        emailTouched = true;
        emailValid = EmailValidator.validate(savedEmail);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _formScrollController = ScrollController();
    _lampController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _overlayOpacity = Tween<double>(
      begin: 0.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _lampController, curve: Curves.easeIn));

    _lampFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _lampController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _ropeOffset = Tween<double>(begin: 0.0, end: 24.0).animate(
      CurvedAnimation(
        parent: _lampController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _glowRadius = Tween<double>(begin: 0.0, end: 18.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _lampController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // darkening finished -> apply dark theme and hide lamp shortly after
        widget.onThemeChange(true);
        Future.delayed(const Duration(milliseconds: 220), () {
          setState(() => _lampVisible = false);
        });
      } else if (status == AnimationStatus.dismissed) {
        // overlay fully removed -> ensure light theme and hide lamp
        widget.onThemeChange(false);
        setState(() => _lampVisible = false);
      }
    });

    _glowController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // glow finished while turning to light -> switch theme then reverse overlay
        if (!_isTurningToDark) {
          widget.onThemeChange(false);
          // reverse overlay animation to reveal light
          _lampController.reverse(from: 1.0);
          // hide lamp after reverse completes
          Future.delayed(const Duration(milliseconds: 400), () {
            setState(() => _lampVisible = false);
          });
        }
      }
    });

    _loadRememberedCredentials();
  }

  @override
  void dispose() {
    _loginCooldownTimer?.cancel();
    _formScrollController.dispose();
    _lampController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _startLampTransition(bool toDark) {
    if (toDark == widget.isDark) return;

    _isTurningToDark = toDark;
    setState(() => _lampVisible = true);

    if (toDark) {
      // animate to dark: pull rope, darken overlay, then switch theme at completion
      _lampController.forward(from: 0.0);
      // ensure any glow is reset
      _glowController.value = 0.0;
    } else {
      // animate glow first (lamp lights up), then switch theme to light and reverse overlay
      // ensure overlay is at dark state before glow
      _lampController.value = 1.0;
      _glowController.forward(from: 0.0);
    }
  }

  /// ================= FORGOT POPUP =================

  void showForgotPasswordDialog() {
    forgot_dialog.showForgotPasswordDialog(
      context: context,
      isDark: widget.isDark,
      lang: widget.lang,
      emailCtrl: emailCtrl,
      onEmailChanged: checkEmail,
      emailBorder: emailBorder,
    );
  }
}

class _TwoFactorLoginDialog extends StatefulWidget {
  final String lang;
  final String email;
  final String password;

  const _TwoFactorLoginDialog({
    required this.lang,
    required this.email,
    required this.password,
  });

  @override
  State<_TwoFactorLoginDialog> createState() => _TwoFactorLoginDialogState();
}

class _TwoFactorLoginDialogState extends State<_TwoFactorLoginDialog> {
  final TextEditingController codeController = TextEditingController();
  bool isSubmitting = false;
  String? errorText;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (isSubmitting) return;

    final code = codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        errorText = t(widget.lang, 'loginTwoFactorInvalid');
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      errorText = null;
    });

    try {
      final result = await ApiService.login(
        email: widget.email,
        password: widget.password,
        twoFactorCode: code,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        errorText = error.code == 'TWO_FACTOR_INVALID'
            ? t(widget.lang, 'loginTwoFactorInvalid')
            : error.message;
        isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorText = t(widget.lang, 'loginGenericError');
        isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t(widget.lang, 'loginTwoFactorDialogTitle')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(widget.lang, 'loginTwoFactorDialogDescription')),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(_submit()),
              decoration: InputDecoration(
                labelText: t(widget.lang, 'twoFactorCode'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                errorText!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(t(widget.lang, 'cancel')),
        ),
        ElevatedButton(
          onPressed: isSubmitting ? null : () => unawaited(_submit()),
          child: Text(t(widget.lang, 'send')),
        ),
      ],
    );
  }
}
