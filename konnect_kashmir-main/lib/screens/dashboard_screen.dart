import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:konnect_kashmir/screens/customer_screen.dart';
import 'package:konnect_kashmir/static/grevience_screen.dart';
import 'package:konnect_kashmir/screens/profile2.dart';
import 'package:konnect_kashmir/screens/profile_screen.dart';
import 'package:konnect_kashmir/static/refund_screen.dart';
import 'package:konnect_kashmir/screens/vendor_dashboard.dart';
import 'package:konnect_kashmir/screens/vendor_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'package:konnect_kashmir/static/privacy_screen.dart';
import 'package:konnect_kashmir/static/terms_screen.dart';
import 'ad_watch_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String _supabaseUrl = 'https://fmmpsqnpezjofsluirrv.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtbXBzcW5wZXpqb2ZzbHVpcnJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MzIyNTgsImV4cCI6MjA4NTIwODI1OH0'
      '.6FCU_FLaHsKsE7G50A7-_zYf46GZiKpecg4l_de3tn4';

  final ScrollController _scrollController = ScrollController();
  bool _isNavBarVisible = true;
  double _lastScrollOffset = 0;

  bool isLoading = true;
  bool referExpanded = false;

  int _selectedNavIndex = 1;

  int creditBalance = 0;
  String referralCode = '';
  String userName = 'Guest User';

  int totalVendors = 0;
  int totalDistricts = 0;
  int totalServices = 0;

  List<Map<String, dynamic>> adsList = [];
  List<Map<String, dynamic>> transactions = [];
  Map<String, int> adViewCounts = {};

  // ── CHANGE 1: Responsive helpers ─────────────────────────────────────────
  // All sizing is derived from screen width so the layout adapts to any device.
  double get _sw => MediaQuery.of(context).size.width;
  double get _sh => MediaQuery.of(context).size.height;

  /// Clamp a value between [min] and [max] based on a fraction of screen width.
  double _rs(double fraction, {double min = 0, double max = double.infinity}) =>
      (_sw * fraction).clamp(min, max);

  // ── CHANGE 2: Safe-area top padding helper ────────────────────────────────
  // Was hardcoded 40 px; now respects the device's actual status-bar height.
  double get _topPad => MediaQuery.of(context).padding.top;

  ApiService get _api => ApiService(
    token: context.read<AuthProvider>().accessToken,
    userId: context.read<AuthProvider>().userId,
  );

  Widget _adaptiveLogo({double? height}) {
    // ── CHANGE 3: Logo height is proportional to screen width ───────────────
    final h = height ?? _rs(0.12, min: 32, max: 56);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: Image.asset('assets/images/konnectkashmir.png', height: h),
      );
    } else {
      return Image.asset('assets/images/konnectkashmir.png', height: h);
    }
  }

  Map<String, String> _authHeaders(String? token) => {
    'Content-Type': 'application/json',
    'apikey': _supabaseAnonKey,
    'Authorization': 'Bearer ${token ?? _supabaseAnonKey}',
  };

  Future<dynamic> _get(String path, String? token) async {
    try {
      final res = await http.get(
        Uri.parse('$_supabaseUrl$path'),
        headers: _authHeaders(token),
      );
      debugPrint('GET $path => ${res.statusCode}');
      if (res.statusCode == 200) return jsonDecode(res.body);
      debugPrint('GET body: ${res.body}');
    } catch (e) {
      debugPrint('GET $path error: $e');
    }
    return null;
  }

  Future<dynamic> _rpc(String fn, Map<String, dynamic> body, String? token) async {
    try {
      final res = await http.post(
        Uri.parse('$_supabaseUrl/rest/v1/rpc/$fn'),
        headers: _authHeaders(token),
        body: jsonEncode(body),
      );
      debugPrint('RPC $fn => ${res.statusCode}: ${res.body}');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      debugPrint('RPC $fn error: $e');
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => isLoading = true);
    final auth = context.read<AuthProvider>();
    final token = auth.accessToken;
    final userId = auth.userId ?? auth.user?.id;
    userName = auth.user?.name ?? 'Guest User';
    try {
      await Future.wait([
        _fetchProfile(token, userId),
        _fetchAds(token, userId),
        _fetchTransactions(token, userId),
        _fetchStats(token),
      ]);
    } catch (e) {
      debugPrint('Dashboard load error: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> _fetchProfile(String? token, String? userId) async {
    if (userId == null || userId.isEmpty) return;
    try {
      final credits = await _api.getUserCredits();
      if (credits != null) {
        creditBalance = credits;
        debugPrint('Credits from ApiService: $creditBalance');
      }
    } catch (e) {
      debugPrint('ApiService credits error: $e');
      try {
        final credits = await _rpc('get_user_credits', {}, token);
        if (credits != null) creditBalance = (credits as num).toInt();
      } catch (e2) {
        debugPrint('RPC credits error: $e2');
      }
    }
    try {
      final rows = await _get(
        '/rest/v1/profiles?id=eq.$userId&select=referral_code,credit_balance,full_name&limit=1',
        token,
      );
      if (rows != null && (rows as List).isNotEmpty) {
        final profile = rows.first as Map<String, dynamic>;
        referralCode = profile['referral_code'] as String? ?? '';
        if (creditBalance == 0) {
          creditBalance = (profile['credit_balance'] as num?)?.toInt() ?? 0;
        }
        final name = profile['full_name'] as String?;
        if (name != null && name.isNotEmpty) userName = name;
      }
    } catch (e) {
      debugPrint('Profile fetch error: $e');
    }
  }

  Future<void> _fetchAds(String? token, String? userId) async {
    try {
      final rawAds = await _api.getAvailableAds();
      final Map<String, int> viewCounts = {};
      if (userId != null && userId.isNotEmpty) {
        final viewRows = await _get(
          '/rest/v1/ad_views?user_id=eq.$userId&select=ad_id',
          token,
        );
        if (viewRows != null) {
          for (final r in (viewRows as List)) {
            final id = r['ad_id'] as String? ?? '';
            if (id.isNotEmpty) viewCounts[id] = (viewCounts[id] ?? 0) + 1;
          }
        }
      }
      setState(() {
        adsList = rawAds;
        adViewCounts = viewCounts;
      });
      debugPrint('Ads loaded: ${adsList.length}');
    } catch (e) {
      debugPrint('fetchAds error: $e');
    }
  }

  Future<void> _fetchTransactions(String? token, String? userId) async {
    if (userId == null || userId.isEmpty) return;
    try {
      final rows = await _get(
        '/rest/v1/credit_transactions'
            '?user_id=eq.$userId'
            '&select=id,amount,transaction_type,created_at,vendor_id'
            '&order=created_at.desc'
            '&limit=20',
        token,
      );
      if (rows == null) return;
      final list = rows as List;
      if (list.isEmpty) return;
      transactions = list.map((r) {
        final type = r['transaction_type'] as String? ?? 'other';
        final amount = (r['amount'] as num?)?.toInt() ?? 0;
        final dt = DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now();
        String title, subtitle;
        switch (type) {
          case 'unlock_contact':  title = 'Contact Unlocked'; subtitle = 'Vendor contact revealed'; break;
          case 'initial_bonus':   title = 'Welcome Bonus';    subtitle = 'New account reward';       break;
          case 'referral_bonus':  title = 'Referral Bonus';   subtitle = 'Referral credit reward';   break;
          case 'purchase':        title = 'Credit Purchase';  subtitle = 'Credits added';             break;
          case 'refund':          title = 'Refund';           subtitle = 'Credits refunded';          break;
          default:
            title    = amount > 0 ? 'Ad Reward'  : 'Credits Spent';
            subtitle = amount > 0 ? 'Watched ad' : 'Credit used';
        }
        final txType = type == 'unlock_contact' ? 'unlock'
            : type == 'initial_bonus'  ? 'bonus'
            : type == 'referral_bonus' ? 'referral'
            : amount > 0               ? 'ad_reward'
            : 'unlock';
        return {
          'type': txType, 'title': title, 'subtitle': subtitle, 'amount': amount,
          'date': '${dt.day} ${_monthName(dt.month)} ${dt.year}',
          'time': '${dt.hour.toString().padLeft(2, '0')}:'
              '${dt.minute.toString().padLeft(2, '0')} '
              '${dt.hour < 12 ? 'am' : 'pm'}',
        };
      }).toList();
    } catch (e) {
      debugPrint('fetchTransactions error: $e');
    }
  }

  Future<void> _fetchStats(String? token) async {
    try {
      Future<int> countTable(String path) async {
        final res = await http.head(
          Uri.parse('$_supabaseUrl$path'),
          headers: {..._authHeaders(token), 'Prefer': 'count=exact'},
        );
        if (res.statusCode == 200) {
          final range = res.headers['content-range'];
          if (range != null && range.contains('/')) {
            return int.tryParse(range.split('/').last) ?? 0;
          }
        }
        return 0;
      }
      final results = await Future.wait([
        countTable('/rest/v1/vendors_public?is_approved=eq.true'),
        countTable('/rest/v1/districts'),
        countTable('/rest/v1/service_categories?is_active=eq.true'),
      ]);
      totalVendors = results[0];
      totalDistricts = results[1];
      totalServices = results[2];
    } catch (e) {
      debugPrint('fetchStats error: $e');
    }
  }

  int _adCredits(Map<String, dynamic> ad)  => ad['credits_reward']     as int? ?? 1;
  int _adMaxViews(Map<String, dynamic> ad) => ad['max_views_per_user'] as int? ?? 1;

  List<Map<String, dynamic>> get _watchableAds => adsList.where((ad) {
    if (ad['is_active'] != true) return false;
    final adId = ad['id']?.toString() ?? '';
    final maxViews = _adMaxViews(ad);
    return (adViewCounts[adId] ?? 0) < maxViews;
  }).toList();

  Future<void> _watchAd(Map<String, dynamic> ad) async {
    final String adId     = ad['id']?.toString() ?? '';
    final int    maxViews = _adMaxViews(ad);
    final int    watched  = adViewCounts[adId] ?? 0;
    if (watched >= maxViews) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You have already watched this ad the maximum times.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final bool? completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AdWatchDialog(ad: ad),
    );
    if (completed == true) await _claimAdCredits(ad);
  }

  Future<void> _claimAdCredits(Map<String, dynamic> ad) async {
    final String adId           = ad['id']?.toString() ?? '';
    final int    expectedReward = _adCredits(ad);
    try {
      final raw    = await _api.claimAdCredits(adId);
      final result = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);

      debugPrint('claimAdCredits result: $result');

      // Treat alreadyClaimed as a soft success — credits already there
      if (result['alreadyClaimed'] == true) {
        setState(() => adViewCounts[adId] = (adViewCounts[adId] ?? 0) + 1);
        return;
      }

      // Any response that carries a balance or success flag = success
      final bool isSuccess = result['success'] == true
          || result['newBalance'] != null
          || result['credits_earned'] != null
          || result['creditsEarned'] != null;

      if (isSuccess) {
        final int earned = (result['creditsEarned'] as num?)?.toInt()
            ?? (result['credits_earned'] as num?)?.toInt()
            ?? expectedReward;
        final int newBalance = (result['newBalance'] as num?)?.toInt()
            ?? (creditBalance + earned);
        _onAdCompleted(ad, earned, newBalance, adId);

        // Sync with server after a short delay
        Future.delayed(const Duration(seconds: 1), () async {
          try {
            final serverCredits = await _api.getUserCredits();
            if (serverCredits != null && mounted) {
              setState(() => creditBalance = serverCredits);
            }
          } catch (_) {}
        });
      } else {
        // Backend responded but with an error message
        final errMsg = result['error']?.toString() ?? '';
        if (errMsg.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(errMsg),
              backgroundColor: Colors.orange));
        } else {
          // No clear error — assume optimistic success
          _onAdCompleted(ad, expectedReward, creditBalance + expectedReward, adId);
        }
      }
    } catch (e) {
      debugPrint('_claimAdCredits error: $e');
      // Credits likely went through — show optimistic success instead of error
      _onAdCompleted(ad, expectedReward, creditBalance + expectedReward, adId);
      // Then verify with server
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          final serverCredits = await _api.getUserCredits();
          if (serverCredits != null && mounted) {
            setState(() => creditBalance = serverCredits);
          }
        } catch (_) {}
      });
    }
  }

  void _onAdCompleted(Map<String, dynamic> ad, int earned, int newBalance, String adId) {
    final now = DateTime.now();
    setState(() {
      creditBalance = newBalance;
      adViewCounts[adId] = (adViewCounts[adId] ?? 0) + 1;
      transactions.insert(0, <String, dynamic>{
        'type': 'ad_reward', 'title': 'Ad Reward',
        'subtitle': 'Watched ${ad['title']} ad', 'amount': earned,
        'date': '${now.day} ${_monthName(now.month)} ${now.year}',
        'time': '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')} '
            '${now.hour < 12 ? 'am' : 'pm'}',
      });
    });
    if (mounted) {
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.stars_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text('+$earned credit${earned > 1 ? 's' : ''} earned! Balance: $newBalance'),
          ),
        ]),
        backgroundColor: cs.primary.withOpacity(0.85),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  String _monthName(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m - 1];
  }

  void _handleNavTap(int index) {
    switch (index) {
      case 0:
        setState(() => _selectedNavIndex = 0);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CustomerScreen()));
        break;
      case 1:
        setState(() => _selectedNavIndex = 1);
        _loadDashboardData();
        break;
      case 2:
        setState(() => _selectedNavIndex = 2);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorDashboardScreen()));
        break;
      case 3:
        setState(() => _selectedNavIndex = 3);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ).then((_) => setState(() => _selectedNavIndex = 1));
        break;
    }
  }

  void _showSignOutDialog(AuthProvider auth) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cs.outline.withOpacity(0.3)),
        ),
        title: Text('Sign Out',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(color: cs.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
            child: Text('Sign Out', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  // ── Bottom Nav Bar ────────────────────────────────────────────────────────
  Widget _buildBottomNavBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final Color bgColor = theme.scaffoldBackgroundColor;
    const Color activeColor = Color(0xFF6BC4B2);
    final Color inactiveColor = cs.onSurface.withOpacity(0.4);

    // ── CHANGE 4: Nav bar height adapts to text-scale / small screens ────────
    final double navHeight = _rs(0.18, min: 60, max: 80);

    final List<_NavItem> items = [
      _NavItem(icon: Icons.home_outlined,      activeIcon: Icons.home_rounded,      label: 'Home'),
      _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
      _NavItem(icon: Icons.store_outlined,     activeIcon: Icons.store_rounded,     label: 'Register'),
      _NavItem(icon: Icons.person_outline,     activeIcon: Icons.person_rounded,    label: 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: cs.onSurface.withOpacity(0.08))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: navHeight,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = _selectedNavIndex == index;
              // ── CHANGE 5: Icon size scales with screen width ───────────────
              final double iconSize = _rs(0.065, min: 20, max: 28);
              final double fontSize = _rs(0.028, min: 9, max: 12);
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handleNavTap(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: isSelected ? iconSize : 0,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? activeColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          color: isSelected ? activeColor : inactiveColor,
                          size: isSelected ? iconSize + 2 : iconSize,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? activeColor : inactiveColor,
                            fontSize: fontSize,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                            letterSpacing: isSelected ? 0.3 : 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    return Scaffold(
      bottomNavigationBar: _buildBottomNavBar(),
      body: Stack(children: [
        Positioned.fill(child: Container(color: theme.scaffoldBackgroundColor)),
        Positioned.fill(
          child: Center(
            child: Opacity(
              opacity: 0.18,
              child: Image.asset('assets/images/chinar.png',
                  width: _sw,
                  height: _sh,
                  fit: BoxFit.contain),
            ),
          ),
        ),
        Column(children: [
          _buildAppBar(theme, cs),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: cs.primary))
                : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: const Color(0xFF6BC4B2),
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(children: [
                  // ── CHANGE 6: Vertical spacing scales with screen height ──
                  SizedBox(height: _sh * 0.03),
                  _adaptiveLogo(),
                  SizedBox(height: _sh * 0.025),
                  _buildStats(cs),
                  SizedBox(height: _sh * 0.025),
                  _buildCreditBalanceCard(theme, cs),
                  const SizedBox(height: 16),
                  _buildWatchAdsCard(theme, cs),
                  const SizedBox(height: 16),
                  _buildQuickActions(cs),
                  const SizedBox(height: 16),
                  _buildTransactionHistory(theme, cs),
                  const SizedBox(height: 16),
                  _buildPlatformGuidelines(cs),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────
  // ── CHANGE 7: Top padding uses real safe-area inset, not hardcoded 40 ────
  Widget _buildAppBar(ThemeData theme, ColorScheme cs) => Container(
    padding: EdgeInsets.only(
      top: _topPad + 8,   // safe-area + breathing room
      left: 16, right: 16, bottom: 14,
    ),
    decoration: BoxDecoration(
      color: theme.scaffoldBackgroundColor,
      border: Border(bottom: BorderSide(color: cs.outline.withOpacity(0.15))),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      _adaptiveLogo(),
    ]),
  );

  // ── Stats ─────────────────────────────────────────────────────────────────
  Widget _buildStats(ColorScheme cs) => Padding(
    // ── CHANGE 8: Horizontal padding proportional to screen width ───────────
    padding: EdgeInsets.symmetric(horizontal: _rs(0.06, min: 16, max: 32)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _buildStatItem(Icons.store_outlined,       '$totalVendors',   'Vendors',   cs),
      _buildStatItem(Icons.location_on_outlined, '$totalDistricts', 'Districts', cs),
      _buildStatItem(Icons.build_outlined,       '$totalServices+', 'Services',  cs),
    ]),
  );

  Widget _buildStatItem(IconData icon, String value, String label, ColorScheme cs) {
    // ── CHANGE 9: Stat values use FittedBox so they never overflow ──────────
    final double valSize  = _rs(0.055, min: 18, max: 26);
    final double lblSize  = _rs(0.033, min: 11, max: 15);
    final double iconSize = _rs(0.065, min: 22, max: 30);
    return Expanded(
      child: Column(children: [
        Icon(icon, color: cs.primary, size: iconSize),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: TextStyle(color: cs.onSurface, fontSize: valSize, fontWeight: FontWeight.bold)),
        ),
        Text(label,
            style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: lblSize)),
      ]),
    );
  }

  // ── Credit Balance Card ───────────────────────────────────────────────────
  Widget _buildCreditBalanceCard(ThemeData theme, ColorScheme cs) {
    final deepTeal = cs.primary.withOpacity(0.18);
    // ── CHANGE 10: Content padding proportional to screen width ─────────────
    final double hp = _rs(0.05, min: 14, max: 24);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _rs(0.05, min: 14, max: 24)),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outline.withOpacity(0.15)),
        ),
        child: Column(children: [
          Padding(
            padding: EdgeInsets.all(hp),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── CHANGE 11: Balance pill wraps on narrow screens ─────────────
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text('Credit Balance',
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: _rs(0.045, min: 15, max: 20),
                          fontWeight: FontWeight.bold)),
                  // Container(
                  //   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  //   decoration: BoxDecoration(
                  //     color: creditBalance > 0 ? deepTeal : Colors.red.shade700,
                  //     borderRadius: BorderRadius.circular(30),
                  //   ),
                  //   child: Row(mainAxisSize: MainAxisSize.min, children: [
                  //     Icon(Icons.stars_rounded, size: 16,
                  //         color: creditBalance > 0 ? cs.primary : Colors.white),
                  //     const SizedBox(width: 6),
                  //     Text('$creditBalance Credits',
                  //         style: const TextStyle(
                  //             color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  //   ]),
                  // ),
                ],
              ),
              const SizedBox(height: 14),
              // ── CHANGE 12: Giant balance number uses FittedBox ───────────────
              // On small devices (320 px wide) "52 sp" used to overflow.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('$creditBalance',
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: _rs(0.13, min: 36, max: 60),
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Text('Use credits to unlock vendor contacts',
                  style: TextStyle(
                      color: cs.onSurface.withOpacity(0.5),
                      fontSize: _rs(0.035, min: 12, max: 16))),
            ]),
          ),

          Divider(color: cs.outline.withOpacity(0.12), height: 1),

          InkWell(
            onTap: () => setState(() => referExpanded = !referExpanded),
            borderRadius: referExpanded ? BorderRadius.zero
                : const BorderRadius.vertical(bottom: Radius.circular(18)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hp, vertical: 14),
              child: Row(children: [
                Icon(Icons.group_outlined, color: cs.primary, size: 22),
                const SizedBox(width: 10),
                Text('Refer & Earn Credits',
                    style: TextStyle(
                        color: cs.primary,
                        fontSize: _rs(0.038, min: 13, max: 17),
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Icon(referExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: cs.primary),
              ]),
            ),
          ),

          if (referExpanded) ...[
            Divider(color: cs.outline.withOpacity(0.12), height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(hp, 20, hp, 24),
              child: Column(children: [
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                        color: cs.onSurface.withOpacity(0.6),
                        fontSize: _rs(0.035, min: 12, max: 15),
                        height: 1.6),
                    children: [
                      const TextSpan(text: 'Both you and your friend earn '),
                      TextSpan(text: '+5 credits',
                          style: TextStyle(color: cs.secondary, fontWeight: FontWeight.bold)),
                      const TextSpan(text: ' (customer) or '),
                      TextSpan(text: '+10 credits',
                          style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                      const TextSpan(text: ' (vendor)'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outline.withOpacity(0.2)),
                      ),
                      // ── CHANGE 13: Referral code text also uses FittedBox ─────
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          referralCode.isEmpty ? 'Loading...' : referralCode,
                          style: TextStyle(
                            color: referralCode.isEmpty
                                ? cs.onSurface.withOpacity(0.3)
                                : cs.onSurface,
                            fontSize: _rs(0.045, min: 15, max: 20),
                            fontWeight: FontWeight.bold,
                            letterSpacing: referralCode.isEmpty ? 0 : 3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      if (referralCode.isEmpty) return;
                      Clipboard.setData(ClipboardData(text: referralCode));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Referral code copied!'),
                        duration: Duration(seconds: 2),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: cs.onSurface.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.copy_rounded, color: cs.onSurface, size: 22),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final code = referralCode.isEmpty ? 'my referral code' : referralCode;
                      Share.share(
                        'Join KonnectKashmir — Kashmir\'s trusted local services platform!\n\n'
                            'Use my referral code *$code* to sign up and we both earn credits.\n\n'
                            '• Customers earn +5 credits each\n'
                            '• Vendors earn +10 credits each\n\n'
                            'Download: https://konnectkashmir.com',
                        subject: 'Join KonnectKashmir — use code $code',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text('Share with Friends',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Watch Ads Card ────────────────────────────────────────────────────────
  Widget _buildWatchAdsCard(ThemeData theme, ColorScheme cs) {
    final availableAds = _watchableAds;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _rs(0.05, min: 14, max: 24)),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outline.withOpacity(0.15)),
        ),
        padding: EdgeInsets.all(_rs(0.05, min: 14, max: 24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.play_arrow, color: cs.secondary,
                size: _rs(0.07, min: 22, max: 32)),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Watch Ads for Credits',
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: _rs(0.045, min: 15, max: 20),
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Watch short ads to earn free credits',
              style: TextStyle(
                  color: cs.onSurface.withOpacity(0.5),
                  fontSize: _rs(0.032, min: 11, max: 14))),
          const SizedBox(height: 16),
          adsList.isEmpty
              ? _buildAdsLoading(cs)
              : availableAds.isEmpty
              ? _buildAllCaughtUp(cs)
              : Column(children: availableAds.map((ad) => _buildAdItem(ad, cs)).toList()),
        ]),
      ),
    );
  }

  Widget _buildAdsLoading(ColorScheme cs) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text('Loading ads...',
          style: TextStyle(color: cs.onSurface.withOpacity(0.4), fontSize: 14)),
    ),
  );

  Widget _buildAllCaughtUp(ColorScheme cs) => Column(children: [
    const SizedBox(height: 8),
    Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: cs.secondary, width: 3)),
      child: Icon(Icons.check_rounded, color: cs.secondary, size: 36),
    ),
    const SizedBox(height: 16),
    Text('All caught up!',
        style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 4),
    Text('No new ads to watch right now.',
        style: TextStyle(color: cs.onSurface.withOpacity(0.4), fontSize: 14)),
    const SizedBox(height: 8),
  ]);

  Widget _buildAdItem(Map<String, dynamic> ad, ColorScheme cs) {
    final String adId      = ad['id']?.toString() ?? '';
    final int    reward    = _adCredits(ad);
    final int    watched   = adViewCounts[adId] ?? 0;
    final int    total     = _adMaxViews(ad);
    final int    remaining = total - watched;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(_rs(0.035, min: 10, max: 16)),
      decoration: BoxDecoration(
        color: cs.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.secondary.withOpacity(0.3)),
      ),
      // ── CHANGE 14: Ad row is wrapped in LayoutBuilder so the thumbnail
      //    and Watch button never crowd the title on small screens ────────────
      child: LayoutBuilder(builder: (context, constraints) {
        final bool narrow = constraints.maxWidth < 320;
        final double thumbSize = _rs(0.12, min: 40, max: 56);
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: thumbSize, height: thumbSize,
            decoration: BoxDecoration(
                color: Colors.red.shade800,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ad['title'] as String? ?? '',
                  style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: _rs(0.038, min: 13, max: 16)),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: cs.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.secondary.withOpacity(0.4))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.toll_outlined, color: cs.secondary, size: 12),
                      const SizedBox(width: 3),
                      Text('+$reward credit${reward > 1 ? 's' : ''}',
                          style: TextStyle(
                              color: cs.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  Text(
                    total > 1
                        ? '$watched/$total  •  $remaining left'
                        : '$remaining left',
                    style: TextStyle(
                        color: cs.onSurface.withOpacity(0.4), fontSize: 11),
                  ),
                ],
              ),
            ]),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _watchAd(ad),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: narrow ? 10 : 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.primary.withOpacity(0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.monetization_on, color: cs.primary,
                    size: _rs(0.04, min: 14, max: 18)),
                const SizedBox(width: 4),
                Text('+$reward',
                    style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: _rs(0.038, min: 13, max: 17))),
              ]),
            ),
          ),
        ]);
      }),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────
  Widget _buildQuickActions(ColorScheme cs) => Padding(
    padding: EdgeInsets.symmetric(horizontal: _rs(0.05, min: 14, max: 24)),
    child: Row(children: [
      Expanded(child: _buildQuickActionButton(
        icon: Icons.arrow_forward,
        label: 'Browse Services',
        cs: cs,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CustomerScreen()))
            .then((_) async {
          try {
            final credits = await _api.getUserCredits();
            if (credits != null && mounted) setState(() => creditBalance = credits);
          } catch (_) {}
        }),
      )),
      const SizedBox(width: 12),
      Expanded(child: _buildQuickActionButton(
        icon: Icons.store_outlined,
        label: 'List Business',
        cs: cs,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ListBusinessScreen())),
      )),
    ]),
  );

  Widget _buildQuickActionButton({
    required IconData icon, required String label,
    required VoidCallback onTap, required ColorScheme cs,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(vertical: _rs(0.045, min: 14, max: 22)),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.15)),
      ),
      child: Column(children: [
        Icon(icon, color: cs.primary, size: _rs(0.07, min: 22, max: 32)),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                color: cs.onSurface,
                fontSize: _rs(0.035, min: 12, max: 16),
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center),
      ]),
    ),
  );

  // ── Transaction History ───────────────────────────────────────────────────
  Widget _buildTransactionHistory(ThemeData theme, ColorScheme cs) {
    final double hp = _rs(0.05, min: 14, max: 24);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hp),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outline.withOpacity(0.15)),
        ),
        padding: EdgeInsets.all(hp),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.history, color: cs.primary,
                size: _rs(0.065, min: 20, max: 28)),
            const SizedBox(width: 10),
            Flexible(
              child: Text('Transaction History',
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: _rs(0.045, min: 15, max: 20),
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Your credit activity and unlocked contacts',
              style: TextStyle(
                  color: cs.onSurface.withOpacity(0.5),
                  fontSize: _rs(0.032, min: 11, max: 14))),
          const SizedBox(height: 16),
          transactions.isEmpty
              ? Column(children: [
            const SizedBox(height: 8),
            Icon(Icons.receipt_long_outlined,
                color: cs.onSurface.withOpacity(0.25), size: 40),
            const SizedBox(height: 12),
            Text('No transactions yet',
                style: TextStyle(
                    color: cs.onSurface.withOpacity(0.4),
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('Watch an ad or unlock a vendor contact\nto see your activity here.',
                style: TextStyle(
                    color: cs.onSurface.withOpacity(0.25),
                    fontSize: 12,
                    height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
          ])
              : Column(
              children: transactions
                  .map((tx) => _buildTransactionItem(tx, cs))
                  .toList()),
        ]),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx, ColorScheme cs) {
    final int    amount   = tx['amount'] as int;
    final bool   isCredit = amount > 0;
    final String type     = tx['type'] as String;

    IconData txIcon;
    Color txIconColor, txIconBg;
    switch (type) {
      case 'unlock':
        txIcon = Icons.lock_open_outlined;
        txIconColor = cs.primary;
        txIconBg = cs.primary.withOpacity(0.12);
        break;
      case 'ad_reward':
        txIcon = Icons.play_circle_outline;
        txIconColor = cs.secondary;
        txIconBg = cs.secondary.withOpacity(0.12);
        break;
      case 'bonus':
        txIcon = Icons.card_giftcard;
        txIconColor = cs.secondary;
        txIconBg = cs.secondary.withOpacity(0.12);
        break;
      case 'referral':
        txIcon = Icons.group_outlined;
        txIconColor = Colors.purple.shade300;
        txIconBg = Colors.purple.withOpacity(0.12);
        break;
      default:
        txIcon = Icons.swap_horiz;
        txIconColor = cs.onSurface.withOpacity(0.4);
        txIconBg = cs.onSurface.withOpacity(0.08);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(_rs(0.035, min: 10, max: 16)),
      decoration: BoxDecoration(
          color: cs.onSurface.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withOpacity(0.1))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: txIconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(txIcon, color: txIconColor,
              size: _rs(0.05, min: 16, max: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx['title'] as String,
                style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: _rs(0.036, min: 12, max: 16))),
            const SizedBox(height: 2),
            Text(tx['subtitle'] as String,
                style: TextStyle(
                    color: cs.onSurface.withOpacity(0.55),
                    fontSize: _rs(0.032, min: 11, max: 14))),
            const SizedBox(height: 6),
            // ── CHANGE 15: Date/time row wraps on tiny screens ───────────────
            Wrap(
              spacing: 8, runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calendar_today_outlined,
                      color: cs.onSurface.withOpacity(0.3), size: 13),
                  const SizedBox(width: 4),
                  Text(tx['date'] as String,
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(0.3), fontSize: 12)),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.access_time_outlined,
                      color: cs.onSurface.withOpacity(0.3), size: 13),
                  const SizedBox(width: 4),
                  Text(tx['time'] as String,
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(0.3), fontSize: 12)),
                ]),
              ],
            ),
          ]),
        ),
        // ── CHANGE 16: Amount column never overflows ─────────────────────────
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(isCredit ? '+$amount' : '$amount',
                style: TextStyle(
                    color: isCredit ? cs.secondary : cs.primary,
                    fontSize: _rs(0.045, min: 15, max: 20),
                    fontWeight: FontWeight.bold)),
          ),
          Text(amount.abs() == 1 ? 'credit' : 'credits',
              style: TextStyle(
                  color: isCredit ? cs.secondary : cs.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }

  // ── Platform Guidelines ───────────────────────────────────────────────────
  Widget _buildPlatformGuidelines(ColorScheme cs) => Padding(
    padding: EdgeInsets.symmetric(horizontal: _rs(0.05, min: 14, max: 24)),
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(_rs(0.05, min: 16, max: 24)),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_outlined, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Platform Guidelines',
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: _rs(0.043, min: 15, max: 19),
                    fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 16),
        Text(
          'KonnectKashmir operates as an intermediary connecting service seekers '
          'with providers under the IT Act, 2000.',
          style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.7),
              fontSize: _rs(0.033, min: 13, max: 15),
              height: 1.5),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _guidelineLink(context, 'Privacy Policy', Icons.privacy_tip_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())), cs),
            _guidelineLink(context, 'Terms', Icons.description_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())), cs),
            _guidelineLink(context, 'Refunds', Icons.receipt_long_outlined, () => Navigator.pushNamed(context, '/refund'), cs),
          ],
        ),
      ]),
    ),
  );

  Widget _guidelineLink(BuildContext context, String text, IconData icon, VoidCallback onTap, ColorScheme cs) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text(text,
                style: TextStyle(
                    color: cs.primary,
                    fontSize: _rs(0.033, min: 13, max: 15),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }


}