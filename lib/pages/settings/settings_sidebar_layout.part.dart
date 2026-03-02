part of '../settings_page.dart';

extension _SettingsSidebarLayout on _SettingsPageState {
  Widget _buildSettingsLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 960;
        final shouldShowFooter = selectedTab == SettingsTab.editProfile;

        Widget layoutContent;

        if (isCompact) {
          layoutContent = Column(
            children: [
              _buildCompactTabs(),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(child: _buildRightPanelContent()),
              ),
            ],
          );
        } else {
          final sidebarWidth = isSidebarCollapsed ? 92.0 : 290.0;

          layoutContent = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: sidebarWidth,
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _buildSidebar(),
                        ),
                      ),
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
              ),
              const SizedBox(width: 24),
              Expanded(
                child: SingleChildScrollView(child: _buildRightPanelContent()),
              ),
            ],
          );
        }

        if (!shouldShowFooter) {
          return layoutContent;
        }

        return Column(
          children: [
            Expanded(child: layoutContent),
            const SizedBox(height: 12),
            _buildEditProfileFooter(),
          ],
        );
      },
    );
  }

  Widget _buildSidebar() {
    final accountType = profileData?['accountType'] as String? ?? 'user';
    final editProfileSubcategories = _editProfileSectionsForAccountType(
      accountType,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: SingleChildScrollView(
        primary: false,
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
              onTap: () {
                unawaited(_openEditProfileTab(sectionId: null));
              },
            ),
            if (!isSidebarCollapsed) ...[
              ...editProfileSubcategories
                  .map(
                    (subcategory) => _buildSidebarSubItem(
                      icon: subcategory.icon,
                      label: subcategory.label,
                      sectionId: subcategory.id,
                      isNested: subcategory.id.startsWith('skills_'),
                    ),
                  ),
            ],
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
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required SettingsTab tab,
    bool isDanger = false,
    VoidCallback? onTap,
  }) {
    final selected = selectedTab == tab;
    final dangerColor = Colors.red.shade600;

    final content = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (onTap != null) {
          onTap();
        } else {
          unawaited(_handleTabChange(tab));
        }
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

  Widget _buildSidebarSubItem({
    required IconData icon,
    required String label,
    required String sectionId,
    bool isNested = false,
  }) {
    final selected =
        selectedTab == SettingsTab.editProfile &&
        _selectedEditProfileSubcategory == sectionId;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        unawaited(_openEditProfileTab(sectionId: sectionId));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: EdgeInsets.fromLTRB(isNested ? 42 : 26, 8, 10, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? Theme.of(context).colorScheme.primary : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarToggle() {
    return Material(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _toggleSidebarCollapsed,
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
              if (tab == SettingsTab.editProfile) {
                unawaited(_openEditProfileTab(sectionId: null));
              } else {
                unawaited(_handleTabChange(tab));
              }
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
}
