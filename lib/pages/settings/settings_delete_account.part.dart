part of '../settings_page.dart';

extension _SettingsDeleteAccount on _SettingsPageState {
  void setState(VoidCallback fn) => _setSettingsState(fn);

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
        await ApiService.login(
          email: enteredEmail,
          password: pass1,
          locale: widget.lang,
        );

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
}
