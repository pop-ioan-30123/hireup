import 'package:flutter/material.dart';
import '../core/mode.dart';
import '../core/responsive.dart';
import '../forms/login_form.dart';
import '../forms/register_form.dart';

class AuthFormCarousel extends StatelessWidget {
  final Mode mode;
  final bool isDark;
  final String lang;
  final ScrollController formScrollController;

  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final TextEditingController firstCtrl;
  final TextEditingController lastCtrl;
  final TextEditingController hrFirstCtrl;
  final TextEditingController hrLastCtrl;
  final TextEditingController hrEmailCtrl;

  final bool remember;
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

  final void Function(String) checkEmail;
  final void Function(bool) onRememberChange;
  final VoidCallback onEmailFieldTap;
  final void Function(String) checkPassword;
  final void Function(bool) onUserTypeChange;
  final void Function(bool) onPasswordFocus;
  final void Function(bool) onConfirmChange;
  final OutlineInputBorder Function() emailBorder;
  final VoidCallback showForgotPasswordDialog;
  final Future<void> Function() onLoginPress;
  final bool isLoginLoading;
  final int loginCooldownSeconds;
  final String? loginErrorMessage;
  final VoidCallback onRegisterPress;
  final String Function(String) capitalizeWords;

  const AuthFormCarousel({
    super.key,
    required this.mode,
    required this.isDark,
    required this.lang,
    required this.formScrollController,
    required this.emailCtrl,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.firstCtrl,
    required this.lastCtrl,
    required this.hrFirstCtrl,
    required this.hrLastCtrl,
    required this.hrEmailCtrl,
    required this.remember,
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
    required this.onRememberChange,
    required this.onEmailFieldTap,
    required this.checkPassword,
    required this.onUserTypeChange,
    required this.onPasswordFocus,
    required this.onConfirmChange,
    required this.emailBorder,
    required this.showForgotPasswordDialog,
    required this.onLoginPress,
    required this.isLoginLoading,
    required this.loginCooldownSeconds,
    required this.loginErrorMessage,
    required this.onRegisterPress,
    required this.capitalizeWords,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == Mode.none) return const SizedBox();

    final padding = Responsive.responsivePadding(context);
    final maxContentWidth = Responsive.getContentMaxWidth(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final contentWidth = maxContentWidth.isFinite ? maxContentWidth : viewportWidth;

        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SizedBox(
            width: contentWidth,
            child: IndexedStack(
              index: mode == Mode.login ? 0 : 1,
              children: [
                ExcludeFocus(
                  excluding: mode != Mode.login,
                  child: SingleChildScrollView(
                    child: LoginFormWidget(
                      emailCtrl: emailCtrl,
                      passCtrl: passCtrl,
                      lang: lang,
                      isDark: isDark,
                      emailValid: emailValid,
                      emailTouched: emailTouched,
                      remember: remember,
                      checkEmail: checkEmail,
                        onRememberChange: onRememberChange,
                        onEmailFieldTap: onEmailFieldTap,
                      showForgotPasswordDialog: showForgotPasswordDialog,
                      emailBorder: emailBorder,
                      onLoginPress: onLoginPress,
                      isLoginLoading: isLoginLoading,
                      loginCooldownSeconds: loginCooldownSeconds,
                      loginErrorMessage: loginErrorMessage,
                    ),
                  ),
                ),
                ExcludeFocus(
                  excluding: mode != Mode.register,
                  child: SingleChildScrollView(
                    child: RegisterFormWidget(
                      firstCtrl: firstCtrl,
                      lastCtrl: lastCtrl,
                      emailCtrl: emailCtrl,
                      passCtrl: passCtrl,
                      confirmCtrl: confirmCtrl,
                      hrFirstCtrl: hrFirstCtrl,
                      hrLastCtrl: hrLastCtrl,
                      hrEmailCtrl: hrEmailCtrl,
                      lang: lang,
                      isDark: isDark,
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
                      checkPassword: checkPassword,
                      onUserTypeChange: onUserTypeChange,
                      onPasswordFocus: onPasswordFocus,
                      onConfirmChange: onConfirmChange,
                      emailBorder: emailBorder,
                      onRegisterPress: onRegisterPress,
                      capitalizeWords: capitalizeWords,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
