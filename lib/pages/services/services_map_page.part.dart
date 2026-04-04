part of 'package:careersuitup/pages/services/services_page.dart';

class _ServicesMapPage extends StatefulWidget {
  final String lang;
  final bool isDark;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final Future<void> Function() onLogout;
  final String? initialCounty;
  final String? initialCity;

  const _ServicesMapPage({
    required this.lang,
    required this.isDark,
    required this.onLangChange,
    required this.onThemeChange,
    required this.onLogout,
    this.initialCounty,
    this.initialCity,
  });

  @override
  State<_ServicesMapPage> createState() => _ServicesMapPageState();
}

class _ServicesMapPageState extends State<_ServicesMapPage> {
  late String _currentLang;
  late bool _currentIsDark;

  String? _selectedCounty;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _currentLang = widget.lang;
    _currentIsDark = widget.isDark;
    _selectedCounty = widget.initialCounty;
    _selectedCity = widget.initialCity;
  }

  @override
  void didUpdateWidget(covariant _ServicesMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lang != widget.lang && _currentLang != widget.lang) {
      _currentLang = widget.lang;
    }
    if (oldWidget.isDark != widget.isDark && _currentIsDark != widget.isDark) {
      _currentIsDark = widget.isDark;
    }
  }

  Future<void> _onCountySelectedFromMap(String county) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final allLocalities = RomaniaLocations.localitiesForCounty(county);
        var filtered = List<String>.from(allLocalities);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alege localitatea in judetul $county',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Cauta oras sau comuna',
                        ),
                        onChanged: (value) {
                          final query = value.trim().toLowerCase();
                          setModalState(() {
                            filtered = allLocalities
                                .where(
                                  (locality) =>
                                      locality.toLowerCase().contains(query),
                                )
                                .toList(growable: false);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final locality = filtered[index];
                            return ListTile(
                              leading: const Icon(Icons.place_outlined),
                              title: Text(locality),
                              onTap: () => Navigator.of(context).pop(locality),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null || !mounted) return;
    Navigator.pop(context, <String, String>{
      'county': county,
      'city': selected,
    });
  }

  Widget _countyButtonsWidget() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.1),
            scheme.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 1050
              ? 5
              : width >= 820
              ? 4
              : width >= 560
              ? 3
              : 2;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: RomaniaLocations.counties.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.5,
            ),
            itemBuilder: (context, index) {
              final county = RomaniaLocations.counties[index];
              final isSelected = county == _selectedCounty;

              return OutlinedButton.icon(
                onPressed: () => unawaited(_onCountySelectedFromMap(county)),
                icon: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.map_outlined,
                  size: 18,
                ),
                label: Text(county, overflow: TextOverflow.ellipsis),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isSelected
                      ? scheme.primary.withValues(alpha: 0.14)
                      : scheme.surface,
                  foregroundColor: isSelected
                      ? scheme.primary
                      : scheme.onSurface,
                  side: BorderSide(
                    color: isSelected
                        ? scheme.primary
                        : scheme.outline.withValues(alpha: 0.24),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _selectionBadge({required IconData icon, required String text}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
                padding: const EdgeInsets.all(14),
                constraints: const BoxConstraints(maxWidth: 1100),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Inapoi',
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Harta serviciilor',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Alege judetul din butoanele de mai jos, apoi selecteaza localitatea sau comuna.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    _countyButtonsWidget(),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _selectionBadge(
                          icon: Icons.map_outlined,
                          text: _selectedCounty == null
                              ? 'Judet nesetat'
                              : 'Judet: $_selectedCounty',
                        ),
                        _selectionBadge(
                          icon: Icons.location_city_outlined,
                          text: _selectedCity == null
                              ? 'Localitate nesetata'
                              : 'Localitate: $_selectedCity',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed:
                            _selectedCounty != null && _selectedCity != null
                            ? () {
                                Navigator.pop(context, <String, String>{
                                  'county': _selectedCounty!,
                                  'city': _selectedCity!,
                                });
                              }
                            : null,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Continua spre categorii'),
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
