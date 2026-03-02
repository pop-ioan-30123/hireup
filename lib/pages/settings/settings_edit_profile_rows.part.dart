part of '../settings_page.dart';

extension _SettingsEditProfileRows on _SettingsPageState {
  void setState(VoidCallback fn) => _setSettingsState(fn);

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

  Widget _groupedSection({
    required String id,
    required String title,
    required List<Widget> children,
  }) {
    final isExpanded = _editProfileSectionExpanded[id] ?? false;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: ExpansionTile(
        key: PageStorageKey<String>('edit_profile_section_$id'),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (value) {
          setState(() {
            _editProfileSectionExpanded[id] = value;
          });
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          t(widget.lang, 'settingsSubcategoryVisibilityHint'),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).hintColor,
          ),
        ),
        children: children,
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
              onChanged: (_) => setState(() {}),
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

  Widget _readOnlyVisibilityRow({
    required String label,
    required String value,
    required String visibilityKey,
    bool disabled = false,
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
          Expanded(
            flex: 5,
            child: TextFormField(
              initialValue: value,
              enabled: !disabled,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
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
    int maxLines = 1,
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
              onChanged: (_) => setState(() {}),
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              maxLines: maxLines,
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

  Widget _entryVisibilityToggle({
    required bool isOpen,
    required ValueChanged<bool> onChanged,
  }) {
    return ToggleButtons(
      isSelected: [isOpen, !isOpen],
      onPressed: (index) => onChanged(index == 0),
      constraints: const BoxConstraints(minHeight: 34, minWidth: 34),
      children: const [Icon(Icons.lock_open), Icon(Icons.lock)],
    );
  }
}
