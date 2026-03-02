part of '../settings_page.dart';

extension _SettingsTwoFactorPanel on _SettingsPageState {
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
}
