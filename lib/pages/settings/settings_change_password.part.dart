part of '../settings_page.dart';

extension _SettingsChangePassword on _SettingsPageState {
  void setState(VoidCallback fn) => _setSettingsState(fn);

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
}
