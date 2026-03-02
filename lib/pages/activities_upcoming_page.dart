part of 'activities_page.dart';

class _UpcomingEventsPage extends StatefulWidget {
  final String lang;
  final bool isDark;
  final Function(String) onLangChange;
  final Function(bool) onThemeChange;
  final Future<void> Function() onLogout;
  final String Function(String key) tr;
  final List<_ActivityItem> Function() itemsProvider;

  const _UpcomingEventsPage({
    required this.lang,
    required this.isDark,
    required this.onLangChange,
    required this.onThemeChange,
    required this.onLogout,
    required this.tr,
    required this.itemsProvider,
  });

  @override
  State<_UpcomingEventsPage> createState() => _UpcomingEventsPageState();
}

class _UpcomingEventsPageState extends State<_UpcomingEventsPage> {
  late String _lang;
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _lang = widget.lang;
    _isDark = widget.isDark;
  }

  String _tr(String key) => t(_lang, key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = widget.itemsProvider();

    return AuthenticatedPageShell(
      lang: _lang,
      isDark: _isDark,
      onLangChange: (lang) {
        setState(() => _lang = lang);
        widget.onLangChange(lang);
      },
      onThemeChange: (isDark) {
        setState(() => _isDark = isDark);
        widget.onThemeChange(isDark);
      },
      onLogout: widget.onLogout,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: _tr('back'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _tr('upcomingEvents'),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(_tr('noUpcomingActivities'))
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ActivityAnnouncementTile(
                  item: item,
                  lang: _lang,
                  isDark: _isDark,
                  tr: _tr,
                  onTap: () {},
                  trailingAction: null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
