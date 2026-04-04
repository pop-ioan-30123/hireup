part of 'package:careersuitup/pages/services/services_page.dart';

class _ServicesCategoriesPage extends StatefulWidget {
  final String lang;
  final bool isDark;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final Future<void> Function() onLogout;
  final String selectedCounty;
  final String selectedCity;
  final String initialCategoryKey;

  const _ServicesCategoriesPage({
    required this.lang,
    required this.isDark,
    required this.onLangChange,
    required this.onThemeChange,
    required this.onLogout,
    required this.selectedCounty,
    required this.selectedCity,
    required this.initialCategoryKey,
  });

  @override
  State<_ServicesCategoriesPage> createState() =>
      _ServicesCategoriesPageState();
}

class _ServicesCategoriesPageState extends State<_ServicesCategoriesPage> {
  late String _currentLang;
  late bool _currentIsDark;
  late String _selectedCategoryKey;

  @override
  void initState() {
    super.initState();
    _currentLang = widget.lang;
    _currentIsDark = widget.isDark;
    _selectedCategoryKey = widget.initialCategoryKey;
  }

  @override
  void didUpdateWidget(covariant _ServicesCategoriesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lang != widget.lang && _currentLang != widget.lang) {
      _currentLang = widget.lang;
    }
    if (oldWidget.isDark != widget.isDark && _currentIsDark != widget.isDark) {
      _currentIsDark = widget.isDark;
    }
  }

  String _tr(String key) => t(_currentLang, key);

  void _selectCategory(String categoryKey) {
    setState(() => _selectedCategoryKey = categoryKey);
    Navigator.pop(
      context,
      <String, String>{
        'county': widget.selectedCounty,
        'city': widget.selectedCity,
        'categoryKey': categoryKey,
      },
    );
  }

  Widget _categoryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200
            ? 4
            : width >= 840
            ? 3
            : width >= 560
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _serviceCategories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.65,
          ),
          itemBuilder: (context, index) {
            final category = _serviceCategories[index];
            final selected = category.key == _selectedCategoryKey;
            final scheme = Theme.of(context).colorScheme;

            return InkWell(
              onTap: () => _selectCategory(category.key),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      category.tint.withValues(alpha: selected ? 0.35 : 0.16),
                      scheme.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: selected
                        ? scheme.primary
                        : scheme.outline.withValues(alpha: 0.22),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: category.tint.withValues(alpha: 0.28),
                      child: Icon(category.icon, color: scheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        category.label,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: true,
      child: AuthenticatedPageShell(
        lang: _currentLang,
        isDark: _currentIsDark,
        onLangChange: (lang) {
          setState(() => _currentLang = lang);
          widget.onLangChange(lang);
        },
        onThemeChange: (isDark) {
          setState(() => _currentIsDark = isDark);
          widget.onThemeChange(isDark);
        },
        onLogout: widget.onLogout,
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(maxWidth: 1000),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: _tr('back'),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Categorii servicii',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Alege categoria pentru ${widget.selectedCity}, ${widget.selectedCounty}.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    _categoryGrid(),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () => _selectCategory(_selectedCategoryKey),
                        icon: const Icon(Icons.storefront_rounded),
                        label: Text(
                          _selectedCategoryKey == _allCategoriesKey
                              ? 'Vezi toate categoriile'
                              : 'Vezi ${_serviceCategoryLabel(_selectedCategoryKey)}',
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
    );
  }
}