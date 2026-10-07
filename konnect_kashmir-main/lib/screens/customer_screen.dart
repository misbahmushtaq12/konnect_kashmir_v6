import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:konnect_kashmir/screens/profile2.dart';
import 'package:konnect_kashmir/screens/vendor_dashboard.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:konnect_kashmir/services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:konnect_kashmir/screens/dashboard_screen.dart';
import 'package:konnect_kashmir/static/grevience_screen.dart';
import 'package:konnect_kashmir/static/privacy_screen.dart';
import 'package:konnect_kashmir/static/terms_screen.dart';
import 'package:konnect_kashmir/screens/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/category_meta.dart';
import 'ad_watch_dialog.dart';

class CustomerScreen extends StatefulWidget {
  /// Optional: open the screen with a service category already selected
  /// (used by the Home screen's category tiles).
  final String? initialCategory;

  /// Pre-fills the search box (e.g. tapping a provider on Home).
  final String? initialSearch;

  /// Opens with the "Saved providers only" filter on.
  final bool initialFavoritesOnly;

  /// Opens the "watch an ad for credits" sheet once data has loaded.
  final bool openAdsOnStart;

  const CustomerScreen({
    Key? key,
    this.initialCategory,
    this.initialSearch,
    this.initialFavoritesOnly = false,
    this.openAdsOnStart = false,
  }) : super(key: key);
  @override
  State<CustomerScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<CustomerScreen> {
  bool _showAllCategories = false;
  
  ApiService get _api => ApiService(
    token: context.read<AuthProvider>().accessToken,
    userId: context.read<AuthProvider>().userId,
  );

  Widget _adaptiveLogo({double height = 48}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child:
        Image.asset('assets/images/konnectkashmir.png', height: height),
      );
    }
    return Image.asset('assets/images/konnectkashmir.png', height: height);
  }

  final ScrollController _scrollController = ScrollController();
  bool _isAppBarVisible = true;
  double _lastScrollOffset = 0;

  int _selectedNavIndex = 0;

  int totalVendors = 382;
  int totalDistricts = 234;
  int totalServices = 58;

  List<dynamic> vendors = [];

  static const int _pageSize = 12;
  int _visibleVendorCount = _pageSize;

  List<Map<String, dynamic>> _availableAds = [];
  final Map<dynamic, int> _adWatchCounts = {};

  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _localities = [];
  List<Map<String, dynamic>> _serviceCategories = [];

  String? selectedDistrictId;
  String? selectedDistrictName;
  String? selectedLocalityId;
  String? selectedLocalityName;
  String? selectedServiceSlug;
  String? selectedServiceName;
  String? selectedBrowseCategory;
  bool verifiedOnly = false;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _sort = 'newest'; // newest | experience | price_low
  bool _favoritesOnly = false;
  Set<String> _favorites = {};
  int _vendorReq = 0; // guards against out-of-order API responses
  bool _refreshingVendors = false;

  bool isLoading = true;
  bool isLoadingLocalities = false;

  int userCredits = 5;
  Map<dynamic, bool> revealedVendors = {};
  Map<dynamic, String> _revealedPhones = {};
  Map<dynamic, bool> _isRevealingVendor = {};
  Map<dynamic, bool> showActionsMap = {};
  Map<dynamic, int> vendorRatings = {};
  Map<dynamic, TextEditingController> reviewControllers = {};
  Map<dynamic, String?> selectedReportReason = {};
  Map<dynamic, TextEditingController> reportControllers = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final current = _scrollController.offset;
      if (current > _lastScrollOffset && current > 80) {
        if (_isAppBarVisible) setState(() => _isAppBarVisible = false);
      } else {
        if (!_isAppBarVisible) setState(() => _isAppBarVisible = true);
      }
      _lastScrollOffset = current;
    });
    selectedBrowseCategory = widget.initialCategory;
    final initialSearch = (widget.initialSearch ?? '').trim();
    if (initialSearch.isNotEmpty) {
      _searchController.text = initialSearch;
      searchQuery = initialSearch;
    }
    _favoritesOnly = widget.initialFavoritesOnly;
    _loadFavorites();
    _loadData().then((_) {
      if (widget.openAdsOnStart && mounted && _hasWatchableAds) {
        _showWatchAdSheet();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    for (final c in reviewControllers.values) {
      c.dispose();
    }
    for (final c in reportControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    await Future.wait([
      _loadStats().catchError((e) => debugPrint('loadStats: $e')),
      _loadVendors().catchError((e) => debugPrint('loadVendors: $e')),
      _loadAds().catchError((e) => debugPrint('loadAds: $e')),
      _loadDistricts().catchError((e) => debugPrint('loadDistricts: $e')),
      _loadServiceCategories()
          .catchError((e) => debugPrint('loadServiceCategories: $e')),
      _loadUserCredits().catchError((e) => debugPrint('loadCredits: $e')),
      _loadAlreadyUnlocked()
          .catchError((e) => debugPrint('loadUnlocked: $e')),
      _loadAdWatchCounts().catchError((e) => debugPrint('loadAdCounts: $e')),
    ]);
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _loadAlreadyUnlocked() async {
    final ids = await _api.getAlreadyUnlockedVendorIds();
    if (!mounted) return;
    setState(() {
      for (final id in ids) {
        revealedVendors[id] = true;
      }
    });
  }

  Future<void> _loadAdWatchCounts() async {
    final counts = await _api.getUserAdViewCounts();
    if (!mounted) return;
    setState(() {
      counts.forEach((adId, count) => _adWatchCounts[adId] = count);
    });
  }

  Future<void> _loadStats() async {
    final result = await _api.getPlatformStats();
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        totalVendors = result['vendors'] ?? totalVendors;
        totalDistricts = result['districts'] ?? totalDistricts;
        totalServices = result['services'] ?? totalServices;
      });
    }
  }

  Future<void> _loadDistricts() async {
    try {
      final data = await _api.getDistricts();
      if (!mounted) return;
      setState(() => _districts = List<Map<String, dynamic>>.from(data));
    } catch (_) {
      if (!mounted) return;
      setState(() => _districts = [
        {'id': 'sr', 'name': 'Srinagar'},
        {'id': 'br', 'name': 'Baramulla'},
        {'id': 'an', 'name': 'Anantnag'},
        {'id': 'pl', 'name': 'Pulwama'},
        {'id': 'bd', 'name': 'Budgam'},
        {'id': 'bp', 'name': 'Bandipora'},
        {'id': 'kg', 'name': 'Kulgam'},
        {'id': 'kp', 'name': 'Kupwara'},
        {'id': 'gb', 'name': 'Ganderbal'},
        {'id': 'sh', 'name': 'Shopian'},
      ]);
    }
  }

  Future<void> _loadLocalities(String districtId) async {
    if (!mounted) return;
    setState(() {
      isLoadingLocalities = true;
      _localities = [];
      selectedLocalityId = null;
      selectedLocalityName = null;
    });
    try {
      final data = await _api.getLocalities(districtId);
      if (!mounted) return;
      setState(() => _localities = List<Map<String, dynamic>>.from(data));
    } catch (_) {
      if (!mounted) return;
      setState(() => _localities = []);
    } finally {
      if (mounted) setState(() => isLoadingLocalities = false);
    }
  }

  Future<void> _loadServiceCategories() async {
    try {
      final data = await _api.getServiceCategories();
      if (!mounted) return;
      setState(
              () => _serviceCategories = List<Map<String, dynamic>>.from(data));
    } catch (_) {
      if (!mounted) return;
      setState(() => _serviceCategories = [
        {'slug': 'plumber', 'name': 'Plumbing'},
        {'slug': 'electrician', 'name': 'Electrical'},
        {'slug': 'carpenter', 'name': 'Carpentry'},
        {'slug': 'cleaner', 'name': 'Cleaning'},
        {'slug': 'catering', 'name': 'Catering'},
        {'slug': 'painter', 'name': 'Painting'},
        {'slug': 'appliance_repair', 'name': 'Appliance Repair'},
        {'slug': 'pest_control', 'name': 'Pest Control'},
        {'slug': 'interior_designer', 'name': 'Interior Design'},
        {'slug': 'developer', 'name': 'Web Development'},
        {'slug': 'home_tutor', 'name': 'Tutoring'},
        {'slug': 'photography', 'name': 'Photography'},
        {'slug': 'mechanic', 'name': 'Mechanic'},
        {'slug': 'car_rental', 'name': 'Car Rental'},
        {'slug': 'tailor', 'name': 'Tailoring'},
      ]);
    }
  }

  Future<void> _loadUserCredits() async {
    final credits = await _api.getUserCredits();
    if (!mounted) return;
    setState(() => userCredits = credits ?? 5);
  }

  Future<void> _loadAds() async {
    final ads = await _api.getAvailableAds();
    if (!mounted) return;
    setState(() {
      _availableAds = ads.isNotEmpty
          ? ads
          : [
        {
          'id': '1',
          'title': 'TUM SXR',
          'description': 'Watch and earn credits',
          'url': 'https://www.youtube.com/watch?v=ERswg3P_test',
          'credits_reward': 2,
          'max_views_per_user': 1,
          'is_active': true
        },
        {
          'id': '2',
          'title': 'Konnect Kashmir',
          'description': 'Discover local services',
          'url': 'https://youtu.be/JGI42037uwQ?si=yNIwqOi5test',
          'credits_reward': 1,
          'max_views_per_user': 3,
          'is_active': true
        },
      ];
    });
  }

  Future<void> _loadVendors() async {
    if (!mounted) return;
    final reqId = ++_vendorReq;
    setState(() => _refreshingVendors = true);
    try {
      await _fetchVendors(reqId);
    } finally {
      if (mounted && reqId == _vendorReq) {
        setState(() => _refreshingVendors = false);
      }
    }
  }

  Future<void> _fetchVendors(int reqId) async {
    if (!mounted) return;
    setState(() => _visibleVendorCount = _pageSize);
    final apiVendors = await _api.getVendors(
      search: searchQuery,
      districtId: selectedDistrictId,
      localityId: selectedLocalityId,
      serviceSlug: selectedServiceSlug ?? selectedBrowseCategory,
      verifiedOnly: verifiedOnly,
      limit: 1000,
    );

    if (!mounted || reqId != _vendorReq) return;

    // Demo vendors are only used while developing (debug builds), so real
    // users never see fake providers with fake phone numbers.
    if (apiVendors.isNotEmpty || !kDebugMode) {
      setState(() => vendors = apiVendors);
      return;
    }

    final List<Map<String, dynamic>> allDummy = [
      {
        'id': '1',
        'business_name': 'Kashmir Plumbers',
        'description': 'Expert plumbing & pipe fitting',
        'service_type': 'plumber',
        'localities': {'name': 'Lal Chowk'},
        'locality': 'Lal Chowk',
        'phone': '9876543210',
        'is_verified': true,
        'is_approved': true
      },
      {
        'id': '2',
        'business_name': 'Quick Fix Plumbing',
        'description': 'Fast plumbing repairs, 24/7',
        'service_type': 'plumber',
        'localities': {'name': 'Sopore'},
        'locality': 'Sopore',
        'phone': '9812345678',
        'is_verified': false,
        'is_approved': true
      },
      {
        'id': '3',
        'business_name': 'Valley Pipe Works',
        'description': 'Pipe installation & leak repairs',
        'service_type': 'plumber',
        'localities': {'name': 'Bijbehara'},
        'locality': 'Bijbehara',
        'phone': '9856781234',
        'is_verified': true,
        'is_approved': true
      },
      {
        'id': '4',
        'business_name': 'Spark Electricians',
        'description': 'Wiring, panels & appliance fitting',
        'service_type': 'electrician',
        'localities': {'name': 'Rajbagh'},
        'locality': 'Rajbagh',
        'phone': '9988776655',
        'is_verified': false,
        'is_approved': true
      },
      {
        'id': '5',
        'business_name': 'PowerTech Kashmir',
        'description': 'Industrial & home electrical works',
        'service_type': 'electrician',
        'localities': {'name': 'Chadoora'},
        'locality': 'Chadoora',
        'phone': '9876001122',
        'is_verified': true,
        'is_approved': true
      },
      {
        'id': '6',
        'business_name': 'Fine Wood Crafts',
        'description': 'Custom furniture & woodwork',
        'service_type': 'carpenter',
        'localities': {'name': 'Pulwama Town'},
        'locality': 'Pulwama Town',
        'phone': '9123456789',
        'is_verified': true,
        'is_approved': true
      },
      {
        'id': '7',
        'business_name': 'ColourKing Painters',
        'description': 'Interior & exterior wall painting',
        'service_type': 'painter',
        'localities': {'name': 'Hyderpora'},
        'locality': 'Hyderpora',
        'phone': '9871112233',
        'is_verified': true,
        'is_approved': true
      },
      {
        'id': '8',
        'business_name': 'CleanHome Services',
        'description': 'Deep cleaning & sanitisation',
        'service_type': 'cleaner',
        'localities': {'name': 'Jawahar Nagar'},
        'locality': 'Jawahar Nagar',
        'phone': '9800112233',
        'is_verified': true,
        'is_approved': true
      },
      {
        'id': '9',
        'business_name': 'CoolCare AC Services',
        'description': 'AC installation, service & gas refill',
        'service_type': 'appliance_repair',
        'localities': {'name': 'Soura'},
        'locality': 'Soura',
        'phone': '9855667788',
        'is_verified': true,
        'is_approved': true
      },
      {
        'id': '10',
        'business_name': 'FixIt Appliance Hub',
        'description': 'Washing machines, fridges & more',
        'service_type': 'appliance_repair',
        'localities': {'name': 'Bemina'},
        'locality': 'Bemina',
        'phone': '9866778899',
        'is_verified': true,
        'is_approved': true
      },
    ];

    List<Map<String, dynamic>> filtered = List.from(allDummy);
    if (verifiedOnly) {
      filtered =
          filtered.where((v) => v['is_verified'] == true).toList();
    }
    if (selectedLocalityName != null) {
      filtered = filtered
          .where((v) =>
      (v['localities'] as Map?)?['name'] == selectedLocalityName ||
          v['locality'] == selectedLocalityName)
          .toList();
    }
    if (selectedServiceSlug != null) {
      filtered = filtered
          .where((v) => v['service_type'] == selectedServiceSlug)
          .toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      filtered = filtered
          .where((v) =>
      (v['business_name'] as String).toLowerCase().contains(q) ||
          (v['description'] as String).toLowerCase().contains(q) ||
          (v['service_type'] as String).toLowerCase().contains(q))
          .toList();
    }
    setState(() => vendors = filtered);
  }

  List<Map<String, dynamic>> get _watchableAds =>
      _availableAds.where((ad) {
        if (ad['is_active'] != true) return false;
        final adId = ad['id'];
        final maxViews = ad['max_views_per_user'] as int? ?? 1;
        return (_adWatchCounts[adId] ?? 0) < maxViews;
      }).toList();

  bool get _hasWatchableAds => _watchableAds.isNotEmpty;

  int _adCredits(Map<String, dynamic> ad) =>
      ad['credits_reward'] as int? ?? 1;
  int _adMaxViews(Map<String, dynamic> ad) =>
      ad['max_views_per_user'] as int? ?? 1;

  Future<void> _watchAdForCredits(Map<String, dynamic> ad) async {
    final adId = ad['id'];
    final int credits = _adCredits(ad);

    final bool? claimed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdWatchDialog(ad: ad),
    );
    if (claimed != true) return;

    final result = await _api.claimAdCredits(adId.toString());
    final int newBalance =
        result['newBalance'] as int? ?? (userCredits + credits);

    if (!mounted) return;
    setState(() {
      _adWatchCounts[adId] = (_adWatchCounts[adId] ?? 0) + 1;
      userCredits = newBalance;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.stars_rounded, color: Colors.orange, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(
                '+$credits credit${credits > 1 ? 's' : ''} earned! You now have $newBalance credits.')),
      ]),
      backgroundColor: const Color(0xFF0E3D2E),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _showWatchAdSheet() async {
    final watchable = _watchableAds;
    final cs = Theme.of(context).colorScheme;
    if (watchable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No ads available right now.'),
          backgroundColor: Color(0xFF0E3D2E)));
      return;
    }
    await showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.play_circle_outline,
                      color: Colors.orange, size: 26)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Watch Ads to Earn Credits',
                            style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text('Watch a short video to earn free credits',
                            style: TextStyle(
                                color: cs.onSurface.withOpacity(0.6),
                                fontSize: 13)),
                      ])),
              GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child:
                  Icon(Icons.close, color: cs.onSurface.withOpacity(0.5))),
            ]),
            const SizedBox(height: 16),
            ...watchable.map((ad) {
              final adId = ad['id'];
              final int watched = _adWatchCounts[adId] ?? 0;
              final int maxViews = _adMaxViews(ad);
              final int remaining = maxViews - watched;
              final int credits = _adCredits(ad);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.orange.withOpacity(0.25))),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.red.shade900,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.play_arrow,
                          color: Colors.white, size: 22)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ad['title'] as String? ?? '',
                                style: TextStyle(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color:
                                        Colors.orange.withOpacity(0.4))),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.toll_outlined,
                                          color: Colors.orange, size: 13),
                                      const SizedBox(width: 3),
                                      Text(
                                          '+$credits credit${credits > 1 ? 's' : ''}',
                                          style: const TextStyle(
                                              color: Colors.orange,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                    ]),
                              ),
                              const SizedBox(width: 8),
                              Text('$remaining left',
                                  style: TextStyle(
                                      color: cs.onSurface.withOpacity(0.5),
                                      fontSize: 12)),
                            ]),
                          ])),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _watchAdForCredits(ad);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10)),
                    child: const Text('Watch',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ]),
              );
            }),
          ]),
        ),
      ),
    );
  }

  // ── Navigation ──────────────────────────────────────────────
  void _handleNavTap(int index) {
    switch (index) {
      case 0:
        setState(() => _selectedNavIndex = 0);
        break;
      case 1:
        setState(() => _selectedNavIndex = 1);
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()))
            .then((_) {
          _loadUserCredits();
          if (mounted) setState(() => _selectedNavIndex = 0);
        });
        break;
      case 2:
        setState(() => _selectedNavIndex = 2);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const VendorDashboardScreen()));
        break;
      case 3:
      // ── Navigate to the new ProfileScreen ──
        setState(() => _selectedNavIndex = 3);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ).then((_) {
          _loadUserCredits();
          if (mounted) setState(() => _selectedNavIndex = 0);
        });
        break;
    }
  }

  // ── Bottom nav ──────────────────────────────────────────────
  Widget _buildBottomNavBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final double navHeight =
    MediaQuery.of(context).textScaleFactor > 1.2 ? 84 : 72;
    const Color activeColor = Color(0xFF6BC4B2);
    final Color inactiveColor = cs.onSurface.withOpacity(0.4);

    final List<_NavItem> items = [
      _NavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home'),
      _NavItem(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
          label: 'Dashboard'),
      _NavItem(
          icon: Icons.store_outlined,
          activeIcon: Icons.store_rounded,
          label: 'Register'),
      _NavItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person_rounded,
          label: 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border:
        Border(top: BorderSide(color: cs.onSurface.withOpacity(0.08))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: navHeight,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = _selectedNavIndex == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handleNavTap(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: isSelected ? 28 : 0,
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? activeColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: isSelected ? activeColor : inactiveColor,
                        size: isSelected ? 26 : 24,
                      ),
                      const SizedBox(height: 3),
                      Text(item.label,
                          style: TextStyle(
                            color:
                            isSelected ? activeColor : inactiveColor,
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          )),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Small helpers used by the redesigned UI ────────────────────────────────
  static double? _asNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Indian-style digit grouping: 123456 -> 1,23,456
  static String _fmtMoney(double v) {
    final s = v.round().toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '${parts.join(',')},$last3';
  }

  String? _priceLabel(dynamic vendor) {
    final lo = _asNum(vendor['min_price']);
    final hi = _asNum(vendor['max_price']);
    if ((lo ?? 0) <= 0 && (hi ?? 0) <= 0) return null;
    if (lo != null && hi != null && lo > 0 && hi > 0 && lo != hi) {
      return '₹${_fmtMoney(lo)} – ${_fmtMoney(hi)}';
    }
    return '₹${_fmtMoney(((lo ?? 0) > 0 ? lo : hi)!)}';
  }

  // ── Favorites (saved locally on the device) ────────────────────────────────
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() =>
        _favorites = (prefs.getStringList('favorite_vendors') ?? []).toSet());
  }

  Future<void> _toggleFavorite(dynamic id) async {
    final key = id.toString();
    setState(() {
      if (!_favorites.remove(key)) _favorites.add(key);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_vendors', _favorites.toList());
  }

  // ── Search (debounced so we don't call the API on every keystroke) ─────────
  void _onSearchChanged(String v) {
    searchQuery = v.trim();
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), _loadVendors);
  }

  // ── Filters / sort ─────────────────────────────────────────────────────────
  int get _activeFilterCount =>
      (selectedDistrictId != null ? 1 : 0) +
      (selectedLocalityId != null ? 1 : 0) +
      (verifiedOnly ? 1 : 0) +
      (_favoritesOnly ? 1 : 0);

  bool get _hasAnyFilter =>
      _activeFilterCount > 0 ||
      searchQuery.isNotEmpty ||
      selectedBrowseCategory != null ||
      selectedServiceSlug != null;

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      searchQuery = '';
      selectedDistrictId = null;
      selectedDistrictName = null;
      selectedLocalityId = null;
      selectedLocalityName = null;
      selectedServiceSlug = null;
      selectedServiceName = null;
      selectedBrowseCategory = null;
      verifiedOnly = false;
      _favoritesOnly = false;
      _localities = [];
    });
    _loadVendors();
  }

  List<dynamic> get _displayVendors {
    var list = List<dynamic>.from(vendors);
    if (_favoritesOnly) {
      list = list.where((v) => _favorites.contains(v['id'].toString())).toList();
    }
    double price(dynamic v) => _asNum(v['min_price']) ?? double.infinity;
    double exp(dynamic v) => _asNum(v['experience_years']) ?? -1;
    if (_sort == 'experience') {
      list.sort((a, b) => exp(b).compareTo(exp(a)));
    } else if (_sort == 'price_low') {
      list.sort((a, b) => price(a).compareTo(price(b)));
    }
    return list;
  }

  String _sortLabel() {
    switch (_sort) {
      case 'experience':
        return 'Most experienced';
      case 'price_low':
        return 'Price: low to high';
      default:
        return 'Newest';
    }
  }

  Future<void> _showFilterSheet() async {
    String? dId = selectedDistrictId;
    String? lId = selectedLocalityId;
    final origDistrict = selectedDistrictId;
    final origLocality = selectedLocalityId;
    final origLocalityName = selectedLocalityName;
    bool ver = verifiedOnly;
    bool fav = _favoritesOnly;
    String sort = _sort;

    if (dId != null && _localities.isEmpty) {
      _loadLocalities(dId).then((_) {
        // _loadLocalities clears the selected locality; put it back.
        if (!mounted) return;
        setState(() {
          selectedLocalityId = origLocality;
          selectedLocalityName = origLocalityName;
        });
      });
    }

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final cs = Theme.of(ctx).colorScheme;
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        final districtValue =
            _districts.any((d) => d['id']?.toString() == dId) ? dId : null;
        final localityValue =
            _localities.any((l) => l['id']?.toString() == lId) ? lId : null;

        Widget label(String t) => Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(t,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.6))),
            );

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                    child: Text('Filters',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  TextButton(
                    onPressed: () => setSheet(() {
                      dId = null;
                      lId = null;
                      ver = false;
                      fav = false;
                      sort = 'newest';
                    }),
                    child: const Text('Reset'),
                  ),
                ]),
                label('District'),
                DropdownButtonFormField<String?>(
                  key: ValueKey('district-$districtValue'),
                  initialValue: districtValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('All districts')),
                    ..._districts.map((d) => DropdownMenuItem<String?>(
                          value: d['id']?.toString(),
                          child: Text(d['name']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (val) async {
                    setSheet(() {
                      dId = val;
                      lId = null;
                    });
                    if (val != null) {
                      await _loadLocalities(val);
                    } else {
                      setState(() => _localities = []);
                    }
                    if (ctx.mounted) setSheet(() {});
                  },
                ),
                label('Locality'),
                DropdownButtonFormField<String?>(
                  key: ValueKey('locality-$dId-$localityValue-${_localities.length}'),
                  initialValue: localityValue,
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.place_outlined),
                    hintText: dId == null
                        ? 'Select a district first'
                        : (isLoadingLocalities
                            ? 'Loading…'
                            : 'All localities'),
                  ),
                  items: dId == null
                      ? <DropdownMenuItem<String?>>[]
                      : [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('All localities')),
                          ..._localities.map((l) => DropdownMenuItem<String?>(
                                value: l['id']?.toString(),
                                child: Text(l['name']?.toString() ?? '',
                                    overflow: TextOverflow.ellipsis),
                              )),
                        ],
                  onChanged: dId == null
                      ? null
                      : (val) => setSheet(() => lId = val),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: ver,
                  onChanged: (v) => setSheet(() => ver = v),
                  title: const Text('Verified providers only'),
                  secondary: const Icon(Icons.verified_outlined,
                      color: AppColors.primary),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: fav,
                  onChanged: (v) => setSheet(() => fav = v),
                  title: const Text('Saved providers only'),
                  secondary: const Icon(Icons.favorite_border_rounded,
                      color: AppColors.primary),
                ),
                label('Sort by'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final o in const [
                    ['newest', 'Newest'],
                    ['experience', 'Most experienced'],
                    ['price_low', 'Price: low to high'],
                  ])
                    ChoiceChip(
                      label: Text(o[1]),
                      selected: sort == o[0],
                      onSelected: (_) => setSheet(() => sort = o[0]),
                    ),
                ]),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Show results'),
                ),
              ],
            ),
          ),
        );
      }),
    );

    if (!mounted) return;

    if (applied != true) {
      // Dismissed without applying: restore the previous locality list/selection.
      if (origDistrict != null) {
        await _loadLocalities(origDistrict);
        if (!mounted) return;
        setState(() {
          selectedLocalityId = origLocality;
          selectedLocalityName = origLocalityName;
        });
      } else {
        setState(() => _localities = []);
      }
      return;
    }

    String? nameOf(List<Map<String, dynamic>> list, String? id) {
      if (id == null) return null;
      for (final e in list) {
        if (e['id']?.toString() == id) return e['name']?.toString();
      }
      return null;
    }

    setState(() {
      selectedDistrictId = dId;
      selectedDistrictName = nameOf(_districts, dId);
      selectedLocalityId = lId;
      selectedLocalityName = nameOf(_localities, lId);
      verifiedOnly = ver;
      _favoritesOnly = fav;
      _sort = sort;
    });
    _loadVendors();
  }

  Future<void> _openWhatsApp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final number = digits.length == 10 ? '91$digits' : digits;
    try {
      await launchUrl(Uri.parse('https://wa.me/$number'),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open WhatsApp")));
    }
  }

  Widget _searchPill() {
    final cs = Theme.of(context).colorScheme;
    const none = InputBorder.none;
    final hasText = _searchController.text.isNotEmpty;

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
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (val) {
              setState(() {});
              if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 400), () {
                _onSearchChanged(val);
              });
            },
            onSubmitted: (val) {
              FocusScope.of(context).unfocus();
              _onSearchChanged(val);
            },
            style: TextStyle(color: cs.onSurface, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search vendors...',
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
        if (hasText)
          IconButton(
            icon: Icon(Icons.close_rounded, color: cs.onSurface.withValues(alpha: 0.6), size: 22),
            onPressed: () {
              _searchController.clear();
              setState(() {});
              _onSearchChanged('');
            },
          )
        else
          InkWell(
            onTap: () {
              FocusScope.of(context).unfocus();
              _onSearchChanged(_searchController.text);
            },
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

  Widget _buildCategoriesGrid() {
    final cs = Theme.of(context).colorScheme;
    
    final List<dynamic> sourceList = _serviceCategories.isNotEmpty 
        ? _serviceCategories 
        : CategoryMeta.allCategories;

    final allCats = [
      {'slug': 'all', 'name': 'All'},
      ...sourceList.map((e) => {
        'slug': e['slug']?.toString() ?? e['id']?.toString() ?? '',
        'name': e['name']?.toString() ?? 'Service',
      })
    ];

    final displayCount = _showAllCategories ? allCats.length : 8;
    final safeCount = displayCount > allCats.length ? allCats.length : displayCount;
    final items = allCats.take(safeCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Our services',
          actionLabel: _showAllCategories ? 'Show less' : 'See all',
          onAction: () =>
              setState(() => _showAllCategories = !_showAllCategories),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisExtent: 112,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (_, i) => _serviceTile(items[i]),
        ),
      ],
    );
  }

  Widget _serviceTile(Map<String, dynamic> c) {
    final cs = Theme.of(context).colorScheme;
    final slug = c['slug']?.toString();
    final name = c['name']?.toString() ?? 'Service';
    final meta = CategoryMeta.of(slug);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAll = slug == 'all';
    final isSelected = isAll 
        ? selectedBrowseCategory == null 
        : selectedBrowseCategory == slug;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            selectedBrowseCategory = isAll ? null : slug;
            selectedServiceSlug = null;
            selectedServiceName = null;
          });
          _loadVendors();
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : null,
            border: Border.all(
              color: isSelected 
                  ? AppColors.primary 
                  : cs.onSurface.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Column(children: [
            Icon(meta.icon, color: meta.color, size: 28),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: isDark ? cs.onSurface : const Color(0xFF333333)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildHomeHero(AuthProvider auth) {
    final cs = Theme.of(context).colorScheme;
    final first = (auth.user?.name ?? '').trim().split(' ').first;
    final isSmall = MediaQuery.of(context).size.width < 360;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _adaptiveLogo(height: 48), // Increased size
            const Spacer(),
            if (auth.isAuthenticated) ...[
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _hasWatchableAds ? _showWatchAdSheet : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.stars_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('$userCredits',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    first.isNotEmpty ? first[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ]
          ]),
          const SizedBox(height: 24),
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
          const SizedBox(height: 24),
          _searchPill(),
          if (_searchController.text.isEmpty) ...[
            const SizedBox(height: 28),
            _buildCategoriesGrid(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final hPad = width > 600 ? width * 0.12 : 16.0;
    
    final isHomeTab = !Navigator.canPop(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          if (!isHomeTab) ...[
            _buildAppBar(auth),
            _buildSearchAndFilters(),
          ],
          if (_refreshingVendors && !isLoading)
            const LinearProgressIndicator(
                minHeight: 2, color: AppColors.primary),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
                children: [
                  if (isHomeTab) _buildHomeHero(auth),
                  _buildActiveFilters(),
                  const SizedBox(height: 12),
                  _buildVendorCount(),
                  const SizedBox(height: 4),
                  _buildVendorsList(),
                  const SizedBox(height: 32),
                  _buildPlatformGuidelines(),
                  const SizedBox(height: 32),
                  _buildFooter(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildAppBar(AuthProvider auth) {
    final cs = Theme.of(context).colorScheme;
    final first = (auth.user?.name ?? '').trim().split(' ').first;

    Widget trailing;
    if (!auth.isAuthenticated) {
      trailing = FilledButton.tonal(
        onPressed: () => Navigator.pushNamed(context, '/login'),
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        child: const Text('Sign In'),
      );
    } else {
      trailing = InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _hasWatchableAds ? _showWatchAdSheet : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.stars_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('$userCredits ${userCredits == 1 ? 'credit' : 'credits'}',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            if (_hasWatchableAds) ...[
              const SizedBox(width: 6),
              const Icon(Icons.play_circle_outline,
                  size: 16, color: AppColors.primary),
            ],
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(children: [
        if (Navigator.canPop(context))
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.maybePop(context),
          )
        else
          const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Find services',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              if (auth.isAuthenticated && first.isNotEmpty)
                Text('Hi, $first',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurface.withValues(alpha: 0.55))),
            ],
          ),
        ),
        trailing,
      ]),
    );
  }

  Widget _buildBrowseByService() {
    final cs = Theme.of(context).colorScheme;

    if (_serviceCategories.isEmpty) {
      if (!isLoading) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, __) =>
                const Skeleton(width: 90, height: 38, radius: 999),
          ),
        ),
      );
    }

    final chips = <Map<String, dynamic>>[
      {'slug': 'all', 'name': 'All'},
      ..._serviceCategories,
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 3),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final slug =
              chip['slug'] as String? ?? chip['id']?.toString() ?? 'default';
          final name = chip['name'] as String? ?? 'Service';
          final isAll = slug == 'all';
          final meta = isAll ? null : CategoryMeta.of(slug);
          final isSelected = isAll
              ? selectedBrowseCategory == null
              : selectedBrowseCategory == slug;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedBrowseCategory = isAll ? null : slug;
                selectedServiceSlug = null;
                selectedServiceName = null;
              });
              _loadVendors();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : cs.onSurface.withValues(alpha: 0.15),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  isAll ? Icons.grid_view_rounded : meta!.icon,
                  size: 17,
                  color: isSelected
                      ? Colors.white
                      : (isAll
                          ? cs.onSurface.withValues(alpha: 0.7)
                          : meta!.color),
                ),
                const SizedBox(width: 6),
                Text(name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : cs.onSurface.withValues(alpha: 0.8),
                    )),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final cs = Theme.of(context).colorScheme;
    final count = _activeFilterCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Search by name or service',
              hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
              prefixIcon: Icon(Icons.search,
                  color: cs.onSurface.withValues(alpha: 0.5)),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Stack(clipBehavior: Clip.none, children: [
          Material(
            color: cs.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: _showFilterSheet,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border:
                      Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
                ),
                child: const Icon(Icons.tune_rounded),
              ),
            ),
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: CircleAvatar(
                radius: 9,
                backgroundColor: AppColors.accent,
                child: Text('$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _buildActiveFilters() {
    final chips = <Widget>[
      if (selectedDistrictName != null)
        _buildFilterChip(selectedDistrictName!, Icons.location_city_outlined,
            () {
          setState(() {
            selectedDistrictId = null;
            selectedDistrictName = null;
            selectedLocalityId = null;
            selectedLocalityName = null;
            _localities = [];
          });
          _loadVendors();
        }),
      if (selectedLocalityName != null)
        _buildFilterChip(selectedLocalityName!, Icons.place_outlined, () {
          setState(() {
            selectedLocalityId = null;
            selectedLocalityName = null;
          });
          _loadVendors();
        }),
      if (verifiedOnly)
        _buildFilterChip('Verified only', Icons.verified_outlined, () {
          setState(() => verifiedOnly = false);
          _loadVendors();
        }),
      if (_favoritesOnly)
        _buildFilterChip('Saved', Icons.favorite_border_rounded, () {
          setState(() => _favoritesOnly = false);
        }),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: chips),
      ),
    );
  }

  Widget _buildFilterChip(
      String label, IconData icon, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppColors.primary, size: 15),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        InkWell(
          onTap: onRemove,
          borderRadius: BorderRadius.circular(999),
          child: const Padding(
            padding: EdgeInsets.all(3),
            child: Icon(Icons.close, color: AppColors.primary, size: 15),
          ),
        ),
      ]),
    );
  }

  Widget _buildVendorCount() {
    final n = _displayVendors.length;

    return Row(children: [
      Expanded(
        child: Text(
          isLoading ? 'Finding providers…' : '$n ${n == 1 ? 'provider' : 'providers'}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    ]);
  }

  Widget _buildVendorsList() {
    final cs = Theme.of(context).colorScheme;

    if (isLoading) {
      return Column(
        children: List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
            ),
            child: Column(children: [
              Row(children: const [
                Skeleton(width: 52, height: 52, radius: 14),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(height: 16, radius: 6),
                      SizedBox(height: 8),
                      Skeleton(width: 140, height: 12, radius: 6),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              const Skeleton(height: 12, radius: 6),
              const SizedBox(height: 16),
              const Skeleton(height: 44, radius: 12),
            ]),
          ),
        ),
      );
    }

    final list = _displayVendors;

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Column(children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          const Text('No providers found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            _favoritesOnly
                ? "You haven't saved any providers here yet."
                : 'Try a different search or change your filters.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6), height: 1.4),
          ),
          if (_hasAnyFilter) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: _clearAllFilters,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 46)),
              child: const Text('Clear all filters'),
            ),
          ],
        ]),
      );
    }

    final visible = list.take(_visibleVendorCount).toList();
    final remaining = list.length - visible.length;

    return Column(children: [
      for (final v in visible) _buildVendorCard(v),
      if (remaining > 0)
        OutlinedButton.icon(
          onPressed: () => setState(() => _visibleVendorCount += _pageSize),
          icon: const Icon(Icons.expand_more_rounded),
          label: Text('Show more ($remaining left)'),
        ),
    ]);
  }

  Widget _buildVendorCard(dynamic vendor) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.read<AuthProvider>();
    final isLoggedIn = auth.isAuthenticated;
    final vendorId = vendor['id'];
    final String name = (vendor['business_name'] ?? 'Vendor').toString();
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    final String slug = vendor['service_type']?.toString() ?? '';
    final meta = CategoryMeta.of(slug);
    final localityDisplay = vendor['localities'] is Map
        ? vendor['localities']['name']?.toString() ?? ''
        : vendor['locality']?.toString() ?? '';
    final String serviceTypeDisplay = _serviceCategories.isNotEmpty
        ? _serviceCategories
                .firstWhere(
                    (s) => (s['slug']?.toString() ?? s['id']?.toString()) == slug,
                    orElse: () => <String, dynamic>{'name': slug})['name']
                ?.toString() ??
            slug
        : slug;

    final logoUrl = vendor['logo_url']?.toString();
    final isRevealed = revealedVendors[vendorId] == true;
    final phone =
        (_revealedPhones[vendorId] ?? vendor['phone'] ?? '').toString();
    final isFav = _favorites.contains(vendorId.toString());
    final expanded = showActionsMap[vendorId] ?? false;
    final price = _priceLabel(vendor);
    final exp = _asNum(vendor['experience_years']);
    final homeService = vendor['provides_home_service'] == true;
    final onlinePay = vendor['accepts_online_payment'] == true;
    final desc = (vendor['description'] ?? '').toString().trim();

    final subtitle = [
      if (serviceTypeDisplay.isNotEmpty) serviceTypeDisplay,
      if (localityDisplay.isNotEmpty) localityDisplay,
    ].join(' · ');

    final initialsWidget = Center(
      child: Text(initials,
          style: TextStyle(
              color: meta.color, fontSize: 17, fontWeight: FontWeight.w800)),
    );

    Widget tag(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: cs.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.75))),
          ]),
        );

    final tags = <Widget>[
      if (price != null) tag(Icons.currency_rupee_rounded, price.substring(1)),
      if (exp != null && exp > 0)
        tag(Icons.work_outline_rounded, '${exp.round()} yrs'),
      if (homeService) tag(Icons.home_outlined, 'Home visit'),
      if (onlinePay) tag(Icons.account_balance_wallet_outlined, 'Online pay'),
    ];

    Widget action;
    if (_isRevealingVendor[vendorId] == true) {
      action = const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primary));
    } else if (!isLoggedIn) {
      action = _buildSignInButton();
    } else if (isRevealed) {
      action = Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          onPressed: () => _openWhatsApp(phone),
          icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 28),
          tooltip: 'WhatsApp',
          color: const Color(0xFF25D366),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _dialNumber(phone),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
          icon: const Icon(Icons.phone_rounded, size: 18),
          label: const Text('Call'),
        ),
      ]);
    } else {
      action = _buildRevealButton(vendor);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52,
            height: 52,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: (logoUrl != null && logoUrl.isNotEmpty)
                ? Image.network(logoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => initialsWidget)
                : initialsWidget,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  if (vendor['is_verified'] == true) ...[
                    const SizedBox(width: 5),
                    const Icon(Icons.verified,
                        color: Color(0xFF378ADD), size: 18),
                  ],
                ]),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.6))),
                ],
              ],
            ),
          ),
        ]),
        if (desc.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: cs.onSurface.withValues(alpha: 0.7))),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: tags),
        ],
        const SizedBox(height: 14),
        Divider(color: cs.onSurface.withValues(alpha: 0.08), height: 1),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isRevealed ? 'Unlocked' : 'Contact',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 2),
                Text(
                  isRevealed
                      ? '+91 $phone'
                      : '+91 ${_maskPhone(phone)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isRevealed ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: 0.3,
                    color: isRevealed
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ]),
        if (isRevealed) ...[
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => showActionsMap[vendorId] = !expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: cs.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text(expanded ? 'Hide' : 'Rate, review or report',
                    style: TextStyle(
                        fontSize: 13.5,
                        color: cs.onSurface.withValues(alpha: 0.6))),
              ]),
            ),
          ),
        ],
        if (expanded) ...[
          const SizedBox(height: 12),
          _buildImportantNotice(),
          const SizedBox(height: 16),
          _buildReviewSection(vendorId),
          const SizedBox(height: 12),
          Divider(color: cs.onSurface.withValues(alpha: 0.1)),
          InkWell(
            onTap: () => _showReportDialog(vendor),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(Icons.flag_outlined,
                    color: cs.onSurface.withValues(alpha: 0.5), size: 18),
                const SizedBox(width: 8),
                Text('Report',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 14)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildSignInButton() => FilledButton.tonalIcon(
        onPressed: () => Navigator.pushNamed(context, '/login'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm)),
        ),
        icon: const Icon(Icons.lock_outline, size: 17),
        label: const Text('Sign in to unlock',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );

  Widget _buildRevealButton(dynamic vendor) {
    final hasCredit = userCredits > 0;
    return ElevatedButton.icon(
      onPressed: () => _revealContact(vendor),
      style: ElevatedButton.styleFrom(
        backgroundColor: hasCredit ? AppColors.primary : AppColors.accent,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      icon: Icon(
          hasCredit ? Icons.lock_open_outlined : Icons.play_circle_outline,
          size: 18),
      label: Text(hasCredit ? 'Unlock · 1 credit' : 'Watch ad to unlock',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 5) return '$phone••••';
    return '${phone.substring(0, 2)}•••• ${phone.substring(phone.length - 4)}';
  }

  Future<void> _dialNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Calling +91 $phone…'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 2)));
  }

  Future<void> _revealContact(dynamic vendor) async {
    final vendorId = vendor['id'];
    if (_isRevealingVendor[vendorId] == true) return;
    if (revealedVendors[vendorId] == true) {
      _showContactSheet(
          vendor,
          _revealedPhones[vendorId] ??
              vendor['phone']?.toString() ??
              '');
      return;
    }
    if (userCredits > 0) {
      await _doUnlockContact(vendor);
      return;
    }
    final watchable = _watchableAds;
    if (watchable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No credits & no ads available. Check back later.'),
          backgroundColor: Color(0xFF0E3D2E)));
      return;
    }
    final ad = watchable.first;
    final adId = ad['id'];
    final int adCreditReward = _adCredits(ad);
    final bool? claimed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AdWatchDialog(ad: ad));
    if (claimed != true) return;

    final adResult = await _api.claimAdCredits(adId.toString());
    final int newAdBalance =
        adResult['newBalance'] as int? ?? (userCredits + adCreditReward);

    if (!mounted) return;
    setState(() {
      _adWatchCounts[adId] = (_adWatchCounts[adId] ?? 0) + 1;
      userCredits = newAdBalance;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.stars_rounded, color: Colors.orange, size: 20),
        const SizedBox(width: 10),
        Text(
            '+$adCreditReward credit${adCreditReward > 1 ? 's' : ''} earned!'),
      ]),
      backgroundColor: const Color(0xFF0E3D2E),
      duration: const Duration(seconds: 2),
    ));

    if (userCredits > 0) {
      await _doUnlockContact(vendor);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Not enough credits after ad. Please try again.'),
          backgroundColor: Color(0xFF0E3D2E)));
    }
  }

  Future<void> _doUnlockContact(dynamic vendor) async {
    final vendorId = vendor['id'];
    setState(() => _isRevealingVendor[vendorId] = true);
    try {
      final result =
      await _api.unlockVendorContact(vendorId.toString());
      if (!mounted) return;

      if (result['alreadyUnlocked'] == true) {
        final phone = result['phone'] as String? ??
            vendor['phone']?.toString() ??
            '';
        setState(() {
          revealedVendors[vendorId] = true;
          if (phone.isNotEmpty) _revealedPhones[vendorId] = phone;
          _isRevealingVendor[vendorId] = false;
        });
        _showContactSheet(vendor, phone);
        return;
      }
      if (result['success'] == true || result['phone'] != null) {
        final phone = result['phone'] as String? ??
            vendor['phone']?.toString() ??
            '';
        final int newBal =
            result['newBalance'] as int? ?? (userCredits - 1);
        setState(() {
          userCredits = newBal;
          revealedVendors[vendorId] = true;
          if (phone.isNotEmpty) _revealedPhones[vendorId] = phone;
          _isRevealingVendor[vendorId] = false;
        });
        _showContactSheet(vendor, phone);
      } else {
        final localPhone = vendor['phone']?.toString() ?? '';
        if (localPhone.isNotEmpty) {
          setState(() {
            revealedVendors[vendorId] = true;
            _revealedPhones[vendorId] = localPhone;
            userCredits = (userCredits - 1).clamp(0, 99999);
            _isRevealingVendor[vendorId] = false;
          });
          _showContactSheet(vendor, localPhone);
        } else {
          setState(() => _isRevealingVendor[vendorId] = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result['error']?.toString() ??
                  'Could not unlock contact. Please try again.'),
              backgroundColor: Colors.red.shade700));
        }
      }
    } catch (e) {
      final localPhone = vendor['phone']?.toString() ?? '';
      if (!mounted) return;
      if (localPhone.isNotEmpty) {
        setState(() {
          revealedVendors[vendorId] = true;
          _revealedPhones[vendorId] = localPhone;
          userCredits = (userCredits - 1).clamp(0, 99999);
          _isRevealingVendor[vendorId] = false;
        });
        _showContactSheet(vendor, localPhone);
      } else {
        setState(() => _isRevealingVendor[vendorId] = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Network error. Please try again.'),
            backgroundColor: Colors.red));
      }
    }
  }

  void _showContactSheet(dynamic vendor, String phone) {
    final cs = Theme.of(context).colorScheme;
    final name = vendor['business_name'] ?? 'Vendor';
    final double phoneFontSize =
    MediaQuery.of(context).size.width < 360 ? 20 : 28;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
        SizedBox(width: 10),
        Text('Contact Unlocked!',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14))
      ]),
      backgroundColor: const Color(0xFF0E3D2E),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(children: [
            Icon(Icons.phone_outlined,
                color: Colors.orange.shade400, size: 28),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contact Details',
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Text('Contact information for $name',
                          style: TextStyle(
                              color: cs.onSurface.withOpacity(0.6), fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ])),
            GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close,
                    color: cs.onSurface.withOpacity(0.5))),
          ]),
          const SizedBox(height: 32),
          Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  shape: BoxShape.circle),
              child: Icon(Icons.person_outline,
                  color: Colors.orange.shade400, size: 40)),
          const SizedBox(height: 16),
          Text(name,
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          phone.isNotEmpty
              ? FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('+91  $phone',
                  style: TextStyle(
                      color: const Color(0xFF6BC4B2),
                      fontSize: phoneFontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)))
              : Text('Phone not available',
              style: TextStyle(
                  color: cs.onSurface.withOpacity(0.5), fontSize: 16)),
          const SizedBox(height: 28),
          if (phone.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _dialNumber(phone);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.phone_in_talk, size: 22),
                label: const Text('Call Now',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildImportantNotice() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.onSurface.withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.warning_amber_rounded,
              color: cs.onSurface.withOpacity(0.7), size: 20),
          const SizedBox(width: 10),
          Text('Important Notice',
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        RichText(
            text: TextSpan(
                style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 13,
                    height: 1.6),
                children: [
                  const TextSpan(
                      text:
                      'By revealing vendor contact, you acknowledge that KonnectKashmir is not responsible for any transactions, disputes, or issues arising from direct communication. As per Consumer Protection Act, 2019, verify vendor identity and service terms before engaging. Report suspicious activity via our '),
                  WidgetSpan(
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const GrievanceScreen())),
                        child: const Text('Grievance Portal.',
                            style: TextStyle(
                                color: Color(0xFF6BC4B2),
                                fontSize: 13,
                                decoration: TextDecoration.underline)),
                      )),
                ])),
      ]),
    );
  }

  Widget _buildReviewSection(dynamic vendorId) {
    final cs = Theme.of(context).colorScheme;
    reviewControllers.putIfAbsent(
        vendorId, () => TextEditingController());
    final rating = vendorRatings[vendorId] ?? 0;
    final controller = reviewControllers[vendorId]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Leave a Review',
          style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Row(children: [
        Text('Rate: ',
            style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
        ...List.generate(
            5,
                (i) => GestureDetector(
                onTap: () =>
                    setState(() => vendorRatings[vendorId] = i + 1),
                child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        color: i < rating
                            ? Colors.amber
                            : cs.onSurface.withOpacity(0.4),
                        size: 28))))
      ]),
      const SizedBox(height: 12),
      TextField(
        controller: controller,
        maxLines: 3,
        style: TextStyle(color: cs.onSurface),
        decoration: InputDecoration(
          hintText: 'Write your review (optional)...',
          hintStyle:
          TextStyle(color: cs.onSurface.withOpacity(0.4)),
          filled: true,
          fillColor: cs.onSurface.withOpacity(0.04),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: cs.onSurface.withOpacity(0.15))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: cs.onSurface.withOpacity(0.15))),
          focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: Color(0xFF6BC4B2))),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () =>
                _submitReview(vendorId, rating, controller.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E3D2E),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Submit Review',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          )),
    ]);
  }

  Future<void> _submitReview(
      dynamic vendorId, int rating, String text) async {
    if (rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a star rating first.'),
          backgroundColor: Colors.orange));
      return;
    }
    final result =
    await _api.submitReview(vendorId.toString(), rating, text);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        vendorRatings.remove(vendorId);
        reviewControllers[vendorId]?.clear();
        showActionsMap[vendorId] = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Review submitted! It will be visible after admin approval.'),
          backgroundColor: Color(0xFF0E3D2E),
          duration: Duration(seconds: 3)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['error']?.toString() ??
              'Failed to submit review. Please try again.'),
          backgroundColor: Colors.red.shade700));
    }
  }

  void _showReportDialog(dynamic vendor) {
    final cs = Theme.of(context).colorScheme;
    final vendorId = vendor['id'];
    reportControllers.putIfAbsent(
        vendorId, () => TextEditingController());
    selectedReportReason[vendorId] ??= null;
    final reasons = [
      'Misleading Information',
      'False Claims',
      'Spam or Promotional',
      'Inappropriate Behavior',
      'Suspected Fraud',
      'Other'
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final charCount = reportControllers[vendorId]!.text.length;
        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 40),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        const Spacer(),
                        Expanded(
                            flex: 6,
                            child: Text(
                                'Report "${vendor['business_name'] ?? 'Vendor'}"',
                                style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2)),
                        Expanded(
                            child: Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                    onTap: () => Navigator.pop(ctx),
                                    child: Icon(Icons.close,
                                        color: cs.onSurface
                                            .withOpacity(0.5),
                                        size: 22)))),
                      ]),
                  const SizedBox(height: 6),
                  Text(
                      'Help us maintain quality. Your report will be reviewed within 48 hours.',
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(0.6),
                          fontSize: 13,
                          height: 1.5),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Text("What's the issue?",
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...reasons.map((reason) {
                    final selected =
                        selectedReportReason[vendorId] == reason;
                    return GestureDetector(
                      onTap: () => setS(() =>
                      selectedReportReason[vendorId] = reason),
                      child: Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: [
                            Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: selected
                                            ? const Color(0xFF6BC4B2)
                                            : const Color(0xFF6BC4B2)
                                            .withOpacity(0.5),
                                        width: 2)),
                                child: selected
                                    ? Center(
                                    child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration:
                                        const BoxDecoration(
                                            color: Color(
                                                0xFF6BC4B2),
                                            shape: BoxShape
                                                .circle)))
                                    : null),
                            const SizedBox(width: 14),
                            Text(reason,
                                style: TextStyle(
                                    color: cs.onSurface, fontSize: 15)),
                          ])),
                    );
                  }),
                  const SizedBox(height: 20),
                  Text('Describe the issue *',
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reportControllers[vendorId],
                    maxLines: 5,
                    maxLength: 1000,
                    style:
                    TextStyle(color: cs.onSurface, fontSize: 14),
                    onChanged: (_) => setS(() {}),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText:
                      'Please provide details about the issue (minimum 20 characters)...',
                      hintStyle: TextStyle(
                          color: cs.onSurface.withOpacity(0.4),
                          fontSize: 13),
                      filled: true,
                      fillColor: cs.onSurface.withOpacity(0.04),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF6BC4B2))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: cs.onSurface.withOpacity(0.15))),
                      focusedBorder: const OutlineInputBorder(
                          borderRadius:
                          BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(
                              color: Color(0xFF6BC4B2), width: 2)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('$charCount/1000 characters',
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(0.4),
                          fontSize: 12)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: cs.onSurface.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10)),
                    child: RichText(
                        text: TextSpan(
                            style: TextStyle(
                                color: cs.onSurface.withOpacity(0.5),
                                fontSize: 12,
                                height: 1.5),
                            children: [
                              TextSpan(
                                  text: 'Note: ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                      cs.onSurface.withOpacity(0.8))),
                              const TextSpan(
                                  text:
                                  'Filing false reports may result in account suspension. Reports are reviewed as per the Information Technology Act, 2000.'),
                            ])),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                              backgroundColor:
                              cs.onSurface.withOpacity(0.1),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(12))),
                          child: Text('Cancel',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface)),
                        )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton(
                          onPressed: () => _submitReport(
                              ctx, vendorId, vendor['id']),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0E3D2E),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(12))),
                          child: const Text('Submit Report',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                        )),
                  ]),
                ]),
          ),
        );
      }),
    );
  }

  Future<void> _submitReport(
      BuildContext ctx, dynamic vendorId, rawVendorId) async {
    final reason = selectedReportReason[vendorId];
    final description =
        reportControllers[vendorId]?.text.trim() ?? '';
    if (reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a reason.'),
          backgroundColor: Colors.orange));
      return;
    }
    if (description.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
          Text('Please describe the issue (min 20 chars).'),
          backgroundColor: Colors.orange));
      return;
    }
    Navigator.pop(ctx);
    final result = await _api.submitReport(
        rawVendorId.toString(), null, reason, description);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        reportControllers[vendorId]?.clear();
        selectedReportReason[vendorId] = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Report submitted! Our team will review it within 48 hours.'),
          backgroundColor: Color(0xFF0E3D2E),
          duration: Duration(seconds: 3)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['error']?.toString() ??
              'Failed to submit report. Please try again.'),
          backgroundColor: Colors.red.shade700));
    }
  }

  Widget _buildPlatformGuidelines() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.onSurface.withOpacity(0.08))),
        child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.info_outline, color: Color(0xFF6BC4B2)),
            const SizedBox(width: 12),
            Text('Platform Guidelines',
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          Text(
              'KonnectKashmir operates as an intermediary under IT Act, 2000. Credits are non-refundable as per our Refund Policy.',
              style: TextStyle(
                  color: cs.onSurface.withOpacity(0.6),
                  fontSize: 14,
                  height: 1.5)),
          const SizedBox(height: 16),
          Wrap(children: [
            TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                child: const Text('Privacy Policy',
                    style: TextStyle(color: Color(0xFF6BC4B2)))),
            Text(' | ',
                style:
                TextStyle(color: cs.onSurface.withOpacity(0.3))),
            TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TermsScreen())),
                child: const Text('Terms',
                    style: TextStyle(color: Color(0xFF6BC4B2)))),
          ]),
        ]),
      ),
    );
  }

  Widget _buildFooter() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _adaptiveLogo(height: 60),
        const SizedBox(height: 16),
        Text("Connecting Kashmir's local service providers with customers.",
            style: TextStyle(
                color: cs.onSurface.withOpacity(0.6), fontSize: 14),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Text('Quick Links',
            style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildFooterLink('Browse Vendors', '/vendors'),
        _buildFooterLink('Job Listings', '/jobs'),
        _buildFooterLink('Register as Vendor', '/register-vendor'),
        _buildFooterLink('Contact Us', '/contact'),
        const SizedBox(height: 24),
        Text('Legal',
            style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildFooterLink('Terms of Service', '/terms'),
        _buildFooterLink('Privacy Policy', '/privacy'),
        _buildFooterLink('Refund Policy', '/refund'),
        _buildFooterLink('Grievance Redressal', '/grievance'),
        const SizedBox(height: 24),
        Text('Contact Us',
            style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text('info@konnectkashmir.com',
            style: TextStyle(
                color: cs.onSurface.withOpacity(0.6), fontSize: 14)),
        const SizedBox(height: 8),
        Text('+91 9055566624',
            style: TextStyle(
                color: cs.onSurface.withOpacity(0.6), fontSize: 14)),
        const SizedBox(height: 32),
        Divider(color: cs.onSurface.withOpacity(0.1)),
        const SizedBox(height: 16),
        Text(
            '© 2026 Media Mosiac (OPC) Pvt. Ltd. All rights reserved.',
            style: TextStyle(
                color: cs.onSurface.withOpacity(0.4), fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildFooterLink(String title, String route) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(title,
                style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 14))));
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(
      {required this.icon,
        required this.activeIcon,
        required this.label});
}