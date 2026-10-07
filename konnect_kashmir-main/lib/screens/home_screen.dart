import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/category_meta.dart';
import 'customer_screen.dart';

/// Home tab: greeting, search and a grid of 8 services loaded from the API.
class HomeScreen extends StatefulWidget {
  /// Called when the avatar in the top bar is tapped (opens Profile tab).
  final VoidCallback? onOpenProfile;
  const HomeScreen({super.key, this.onOpenProfile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const int _gridCount = 8;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;
  bool _failed = false;
  int? _credits;

  // Search overlay state
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  late final AnimationController _searchAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final Animation<double> _searchFade =
      CurvedAnimation(parent: _searchAnim, curve: Curves.easeOutCubic);

  ApiService get _api {
    final auth = context.read<AuthProvider>();
    return ApiService(token: auth.accessToken, userId: auth.userId);
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchFocus.addListener(_onFocusChange);
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onFocusChange);
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _searchAnim.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_searchFocus.hasFocus && !_isSearching) {
      setState(() => _isSearching = true);
      _searchAnim.forward();
    }
  }

  void _onSearchChanged() {
    if (!_isSearching) return;
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    _runLocalSearch(query);
  }

  void _runLocalSearch(String query) {
    // Filter the static services list client-side for instant results.
    // The full server-side search is triggered on submit (existing _openBrowse logic).
    final q = query.toLowerCase();
    final results = _services.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final slug = (s['slug'] ?? '').toString().toLowerCase();
      return name.contains(q) || slug.contains(q);
    }).toList();
    setState(() {
      _searchResults = results;
    });
  }

  void _exitSearch() {
    _searchFocus.unfocus();
    _searchCtrl.clear();
    setState(() {
      _isSearching = false;
      _searchResults = [];
    });
    _searchAnim.reverse();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadServices(), _loadCredits()]);
  }

  Future<void> _loadServices() async {
    if (mounted) setState(() => _loading = true);
    
    // As requested, always show exactly these 8 items on the Home Screen.
    final staticServices = [
      {'slug': 'electrician', 'name': 'Electrician'},
      {'slug': 'painter', 'name': 'Painter'},
      {'slug': 'carpenter', 'name': 'Carpenter'},
      {'slug': 'home_services', 'name': 'Home Services'},
      {'slug': 'tailor', 'name': 'Tailor'},
      {'slug': 'plumber', 'name': 'Plumber'},
      {'slug': 'mason', 'name': 'Mason (Dasil)'},
      {'slug': 'labour', 'name': 'Labour / Helper'},
    ];

    if (!mounted) return;
    setState(() {
      _services = staticServices;
      _failed = false;
      _loading = false;
    });
  }

  Future<void> _loadCredits() async {
    int? c;
    try {
      c = await _api.getUserCredits();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _credits = c);
  }

  Future<void> _openBrowse({String? category, String? search}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CustomerScreen(initialCategory: category, initialSearch: search),
      ),
    );
    if (mounted) _loadCredits(); // credits may have changed (unlock / ads)
  }

  void _submitSearch() {
    final q = _searchCtrl.text.trim();
    FocusScope.of(context).unfocus();
    _openBrowse(search: q.isEmpty ? null : q);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;
    final hPad = size.width > 600 ? size.width * 0.12 : 20.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(children: [
      // Background chinar watermark
      Positioned(
        top: -30,
        right: -50,
        child: IgnorePointer(
          child: Opacity(
            opacity: isDark ? 0.10 : 0.08,
            child: Image.asset('assets/images/chinar.png', width: 280),
          ),
        ),
      ),
      SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _buildHomeContent(hPad, auth),
          ),
        ),
      ),
    ]);
  }

  // ── Home content (the search pill slides up when search is active) ────────
  Widget _buildHomeContent(double hPad, AuthProvider auth) {
    final hideOnSearch = ReverseAnimation(_searchFade);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24),
        children: [
          // Top bar + headline collapse upwards so the search pill moves to the top.
          SizeTransition(
            sizeFactor: hideOnSearch,
            axisAlignment: -1,
            child: FadeTransition(
              opacity: hideOnSearch,
              child: Column(children: [
                _topBar(auth),
                const SizedBox(height: 24),
                FadeSlideIn(child: _headline(auth)),
                const SizedBox(height: 18),
              ]),
            ),
          ),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: Row(children: [
              Expanded(child: _searchPill()),
              SizeTransition(
                axis: Axis.horizontal,
                sizeFactor: _searchFade,
                axisAlignment: -1,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: TextButton(
                    onPressed: _exitSearch,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
              ),
            ]),
          ),
          AnimatedBuilder(
            animation: _searchFade,
            builder: (_, __) =>
                SizedBox(height: 28 - 16 * _searchFade.value),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isSearching
                ? _buildSearchResults()
                : FadeSlideIn(
                    key: const ValueKey('services'),
                    delay: const Duration(milliseconds: 160),
                    child: _servicesSection()),
          ),
        ],
      ),
    );
  }

  // ── Search results (blank until the user types) ───────────────────────────
  Widget _buildSearchResults() {
    final cs = Theme.of(context).colorScheme;
    final query = _searchCtrl.text.trim();

    if (query.isEmpty) return const SizedBox.shrink(key: ValueKey('results'));

    if (_searchResults.isEmpty) {
      return Padding(
        key: const ValueKey('results'),
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48, color: cs.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(
              'No results for "$query"',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5), fontSize: 15),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _submitSearch,
              icon: const Icon(Icons.search, size: 18),
              label: Text('Search all vendors for "$query"'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      );
    }

    return Column(
      key: const ValueKey('results'),
      children: [
        for (final svc in _searchResults) ...[
          _searchResultTile(svc, cs),
          Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.07)),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextButton.icon(
            onPressed: _submitSearch,
            icon: const Icon(Icons.search, size: 18),
            label: Text('See all results for "$query"'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _searchResultTile(Map<String, dynamic> svc, ColorScheme cs) {
    final slug = svc['slug']?.toString();
    final name = svc['name']?.toString() ?? 'Service';
    final meta = CategoryMeta.of(slug);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: meta.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(meta.icon, color: meta.color, size: 22),
      ),
      title: Text(name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      trailing: Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: cs.onSurface.withValues(alpha: 0.3)),
      onTap: () {
        _exitSearch();
        _openBrowse(category: slug);
      },
    );
  }


  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _topBar(AuthProvider auth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = auth.user?.name ?? '';

    Widget logo = Image.asset('assets/images/konnectkashmir.png', height: 42);
    if (isDark) {
      logo = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: logo,
      );
    }

    return Row(children: [
      logo,
      const Spacer(),
      if (_credits != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.stars_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text('$_credits',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ]),
        ),
      const SizedBox(width: 8),
      InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: widget.onOpenProfile,
        child: CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.primary,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ),
    ]);
  }

  Widget _headline(AuthProvider auth) {
    final cs = Theme.of(context).colorScheme;
    final isSmall = MediaQuery.of(context).size.width < 360;
    final first = (auth.user?.name ?? '').trim().split(' ').first;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(first.isNotEmpty ? 'Salam, $first' : 'Salam',
          style: TextStyle(
              fontSize: 14, color: cs.onSurface.withValues(alpha: 0.6))),
      const SizedBox(height: 6),
      Text.rich(
        const TextSpan(children: [
          TextSpan(text: 'Trusted local pros,\n'),
          TextSpan(
              text: 'one tap away.',
              style: TextStyle(color: AppColors.primary)),
        ]),
        style: TextStyle(
          fontSize: isSmall ? 28 : 34,
          fontWeight: FontWeight.w800,
          height: 1.1,
          letterSpacing: -0.8,
          color: cs.onSurface,
        ),
      ),
    ]);
  }

  Widget _searchPill() {
    final cs = Theme.of(context).colorScheme;
    const none = InputBorder.none;

    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(18, 0, 7, 0),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
      ),
      child: Row(children: [
        Icon(Icons.search_rounded, color: cs.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submitSearch(),
            style: TextStyle(color: cs.onSurface, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'What do you need help with?',
              hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: none,
              enabledBorder: none,
              focusedBorder: none,
            ),
          ),
        ),
        InkWell(
          onTap: _isSearching ? _submitSearch : _submitSearch,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }

  // ── Services grid (8 boxes from API) ──────────────────────────────────────
  static const SliverGridDelegate _gridDelegate =
      SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 4,
    mainAxisExtent: 112,
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
  );

  Widget _servicesSection() {
    final cs = Theme.of(context).colorScheme;

    Widget body;
    if (_loading) {
      body = GridView.builder(
        gridDelegate: _gridDelegate,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _gridCount,
        itemBuilder: (_, __) =>
            const Skeleton(height: 112, radius: AppRadius.md),
      );
    } else if (_failed) {
      body = AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Icon(Icons.wifi_off_rounded,
              size: 34, color: cs.onSurface.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          const Text("Couldn't load services",
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: _loadServices,
            style: OutlinedButton.styleFrom(minimumSize: const Size(140, 44)),
            child: const Text('Retry'),
          ),
        ]),
      );
    } else {
      body = GridView.builder(
        gridDelegate: _gridDelegate,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _services.length,
        itemBuilder: (_, i) => _serviceTile(_services[i]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(
        title: 'Our services',
        actionLabel: 'See all',
        onAction: () => _openBrowse(),
      ),
      const SizedBox(height: 8),
      body,
    ]);
  }

  Widget _serviceTile(Map<String, dynamic> c) {
    final cs = Theme.of(context).colorScheme;
    final slug = c['slug']?.toString();
    final name = c['name']?.toString() ?? 'Service';
    final meta = CategoryMeta.of(slug);

    return Material(
      color: meta.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openBrowse(category: slug),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Column(children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(meta.icon, color: meta.color, size: 26),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: cs.onSurface.withValues(alpha: 0.88)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
