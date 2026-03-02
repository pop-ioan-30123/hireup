part of '../settings_page.dart';

extension _SettingsEditProfilePreview on _SettingsPageState {
  Widget _buildEditProfileFooter() {
    final canAct = _hasUnsavedEditProfileChanges && !isSavingProfileDraft;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.26),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                canAct
                    ? t(currentLang, 'settingsDraftPending')
                    : t(currentLang, 'settingsDraftSynced'),
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: canAct ? _openProfileDraftPreviewDialog : null,
              icon: const Icon(Icons.visibility_outlined),
              label: Text(t(widget.lang, 'previewProfile')),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: canAct ? _saveAll : null,
              icon: isSavingProfileDraft
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(t(widget.lang, 'saveAll')),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _buildDraftPreviewProfileData() {
    final base = Map<String, dynamic>.from(profileData ?? const {});
    final accountType = base['accountType'] as String? ?? 'user';

    final user = Map<String, dynamic>.from(base['user'] ?? const {});
    final userProfile = Map<String, dynamic>.from(base['userProfile'] ?? const {});
    final companyProfile = Map<String, dynamic>.from(
      base['companyProfile'] ?? const {},
    );

    user['gender'] = accountGender;
    user['birthDate'] = accountBirthDate == null
        ? null
        : _formatBirthDate(accountBirthDate!);

    final phoneDigits = _trimmed(phoneCtrl.text);
    user['phone'] = phoneDigits.isEmpty ? null : '+40$phoneDigits';

    if (accountType == 'user') {
      userProfile['country'] = userCountry;
      userProfile['county'] = userCounty;
      userProfile['city'] = userCity;
      userProfile['jobTitle'] = _trimmed(professionalTitleCtrl.text);
      userProfile['professionalStatus'] = userProfessionalStatus;

      final years = _trimmed(yearsExperienceCtrl.text);
      userProfile['yearsExperience'] = years.isEmpty ? null : years;

      final summary = _trimmed(profileSummaryCtrl.text);
      userProfile['profileSummary'] = summary.isEmpty ? null : summary;

      final linkedIn = _trimmed(linkedInCtrl.text);
      final github = _trimmed(githubCtrl.text);
      final youtube = _trimmed(youtubeCtrl.text);
      final instagram = _trimmed(instagramCtrl.text);
      final tiktok = _trimmed(tiktokCtrl.text);

      userProfile['linkedInUrl'] = linkedIn.isEmpty ? null : linkedIn;
      userProfile['githubUrl'] = github.isEmpty ? null : github;
      userProfile['youtubeUrl'] = youtube.isEmpty ? null : youtube;
      userProfile['instagramUrl'] = instagram.isEmpty ? null : instagram;
      userProfile['tiktokUrl'] = tiktok.isEmpty ? null : tiktok;
      base['userExperiences'] = _buildExperienceDraftsPayload();
      base['userEducations'] = _buildEducationDraftsPayload();
      base['userSkills'] = _buildSkillDraftsPayload();
      base['userProjects'] = _buildProjectDraftsPayload();
    } else {
      companyProfile['companyName'] = _trimmed(companyNameCtrl.text);
      companyProfile['county'] = _trimmed(companyCountyCtrl.text);
      companyProfile['city'] = _trimmed(companyCityCtrl.text);
    }

    base['user'] = user;
    base['userProfile'] = userProfile;
    base['companyProfile'] = companyProfile;
    base['visibility'] = Map<String, dynamic>.fromEntries(
      visibility.entries.map((entry) => MapEntry(entry.key, entry.value)),
    );

    return base;
  }

  Future<void> _openProfileDraftPreviewDialog() async {
    if (!_hasUnsavedEditProfileChanges) return;

    final previewData = _buildDraftPreviewProfileData();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) {
          return Scaffold(
            body: SafeArea(
              child: Stack(
                children: [
                  ProfilePage(
                    lang: currentLang,
                    isDark: currentIsDark,
                    onLangChange: widget.onLangChange,
                    onThemeChange: widget.onThemeChange,
                    onLogout: widget.onLogout,
                    initialProfileData: previewData,
                    initialAvatarBytes: avatarBytes,
                    useEmbeddedLayout: true,
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(routeContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                      label: Text(t(currentLang, 'back')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
