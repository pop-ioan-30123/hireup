import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/texts.dart';
import '../core/responsive.dart';

class LoginFormWidget extends StatefulWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final String lang;
  final bool isDark;
  final bool emailValid;
  final bool emailTouched;
  final bool remember;
  final Function(String) checkEmail;
  final Function(bool) onRememberChange;
  final VoidCallback onEmailFieldTap;
  final Function() showForgotPasswordDialog;
  final OutlineInputBorder Function() emailBorder;
  final Future<void> Function()? onLoginPress;
  final bool isLoginLoading;
  final int loginCooldownSeconds;
  final String? loginErrorMessage;

  const LoginFormWidget({
    super.key,
    required this.emailCtrl,
    required this.passCtrl,
    required this.lang,
    required this.isDark,
    required this.emailValid,
    required this.emailTouched,
    required this.remember,
    required this.checkEmail,
    required this.onRememberChange,
    required this.onEmailFieldTap,
    required this.showForgotPasswordDialog,
    required this.emailBorder,
    required this.onLoginPress,
    required this.isLoginLoading,
    required this.loginCooldownSeconds,
    required this.loginErrorMessage,
  });

  @override
  State<LoginFormWidget> createState() => _LoginFormWidgetState();
}

class _LoginFormWidgetState extends State<LoginFormWidget> {
  bool showPasswordWhilePressed = false;

  @override
  Widget build(BuildContext context) {
    final spacing = Responsive.spacing(
      context: context,
      mobile: 12,
      tablet: 16,
      desktop: 20,
    );
    
    final isMobile = Responsive.isMobile(context);
    final emailCtrl = widget.emailCtrl;
    final passCtrl = widget.passCtrl;

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
      children: [
        FocusTraversalOrder(
          order: const NumericFocusOrder(1),
          child: TextField(
            controller: emailCtrl,
            onChanged: widget.checkEmail,
            onTap: widget.onEmailFieldTap,
            textInputAction: TextInputAction.next,
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
        ),
        SizedBox(height: spacing),
        FocusTraversalOrder(
          order: const NumericFocusOrder(2),
          child: TextField(
            controller: passCtrl,
            obscureText: !showPasswordWhilePressed,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              final canPressLogin =
                  emailCtrl.text.trim().isNotEmpty &&
                  passCtrl.text.trim().isNotEmpty &&
                  !widget.isLoginLoading &&
                  widget.loginCooldownSeconds == 0;

              if (canPressLogin) {
                widget.onLoginPress?.call();
              }
            },
            decoration: InputDecoration(
              labelText: t(widget.lang, "password"),
              suffixIcon: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => setState(() => showPasswordWhilePressed = true),
                onTapUp: (_) => setState(() => showPasswordWhilePressed = false),
                onTapCancel: () => setState(() => showPasswordWhilePressed = false),
                child: Tooltip(
                  message: t(widget.lang, 'showPassword'),
                  child: Icon(
                    showPasswordWhilePressed ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              border: const OutlineInputBorder(),
              enabledBorder: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(width: 2)),
              isDense: isMobile,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: isMobile ? 8 : 12,
              ),
            ),
          ),
        ),
        SizedBox(height: spacing),
        FocusTraversalOrder(
          order: const NumericFocusOrder(3),
          child: CheckboxListTile(
            value: widget.remember,
            onChanged: (value) {
              widget.onRememberChange(value ?? false);
            },
            title: Text(
              t(widget.lang, "remember"),
              style: TextStyle(fontSize: isMobile ? 12 : 14),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        FocusTraversalOrder(
          order: const NumericFocusOrder(4),
          child: TextButton(
            onPressed: widget.showForgotPasswordDialog,
            child: Text(
              t(widget.lang, "forgot"),
              style: TextStyle(fontSize: isMobile ? 12 : 14),
            ),
          ),
        ),
        SizedBox(height: spacing),
        if (widget.loginErrorMessage != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.loginErrorMessage!,
              style: TextStyle(
                color: Colors.red,
                fontSize: isMobile ? 12 : 13,
              ),
            ),
          ),
          SizedBox(height: spacing / 2),
        ],
        FocusTraversalOrder(
          order: const NumericFocusOrder(5),
          child: AnimatedBuilder(
            animation: Listenable.merge([emailCtrl, passCtrl]),
            builder: (context, _) {
              final canPressLogin =
                  emailCtrl.text.trim().isNotEmpty &&
                  passCtrl.text.trim().isNotEmpty &&
                  !widget.isLoginLoading &&
                  widget.loginCooldownSeconds == 0;

              return SizedBox(
                width: double.infinity,
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: ElevatedButton(
                    onPressed: canPressLogin
                        ? () {
                            widget.onLoginPress?.call();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                    ),
                    child: Text(
                      widget.isLoginLoading ? '${t(widget.lang, "login")}...' : t(widget.lang, "login"),
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.loginCooldownSeconds > 0) ...[
          SizedBox(height: spacing / 2),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${t(widget.lang, "loginRetryIn")} ${widget.loginCooldownSeconds}',
              style: TextStyle(
                color: Colors.orange,
                fontSize: isMobile ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    ));
  }
}
