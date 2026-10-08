import 'package:konnect_kashmir/theme/app_theme.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/force_ltr.dart';
import '../widgets/app_overlays.dart';
import '../widgets/app_snack.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:konnect_kashmir/screens/profile2.dart';
import 'package:konnect_kashmir/screens/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/lead_loader.dart';
import 'ad_watch_dialog.dart';
import 'vendor_screen.dart';
import '../static/privacy_screen.dart';
import '../static/terms_screen.dart';
import 'customer_screen.dart';

const Color _kTeal        = Color(0xFF6BC4B2);
const Color _kTealDark    = Color(0xFF0E3D2E);
const Color _kTealLight   = Color(0xFFD6F0EB);
const Color _kOrange      = Color(0xFFE07B2E);

class VendorDashboardScreen extends StatefulWidget {
  final String? initialBusinessId;
  const VendorDashboardScreen({super.key, this.initialBusinessId});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  static const _supabaseUrl = 'https://fmmpsqnpezjofsluirrv.supabase.co';
  static const _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtbXBzcW5wZXpqb2ZzbHVpcnJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MzIyNTgsImV4cCI6MjA4NTIwODI1OH0'
      '.6FCU_FLaHsKsE7G50A7-_zYf46GZiKpecg4l_de3tn4';

  bool _isLoading = true;
  bool _referExpanded = false;
  bool _notifEnabled = false;
  bool _notifDismissed = false;
  int _selectedNavIndex = 0;

  // ── Scroll controller (scroll-hide nav removed) ───────────────────────────
  final ScrollController _scrollController = ScrollController();

  int _credits = 0;
  String _referralCode = '';
  String _userName = 'Vendor';

  List<Map<String, dynamic>> _businesses = [];
  Map<String, dynamic>? _selectedBiz;

  List<Map<String, dynamic>> _leads = [];
  bool _isLoadingLeads = false;

  final Map<String, bool> _revealedLeads = {};
  final Map<String, String> _revealedPhones = {};
  final Map<String, bool> _isRevealing = {};

  final Map<String, List<Map<String, dynamic>>> _leadsByVendor = {};

  List<Map<String, dynamic>> _ads = [];
  Map<String, int> _adViewCounts = {};
  List<Map<String, dynamic>> _transactions = [];

  ApiService get _api => ApiService(
    token: context.read<AuthProvider>().accessToken,
    userId: context.read<AuthProvider>().userId,
  );

  Map<String, String> get _headers {
    final token = context.read<AuthProvider>().accessToken;
    return {
      'Content-Type': 'application/json',
      'apikey': _supabaseAnonKey,
      'Authorization': 'Bearer ${token ?? _supabaseAnonKey}',
    };
  }

  Future<dynamic> _get(String path) async {
    try {
      final res =
      await http.get(Uri.parse('$_supabaseUrl$path'), headers: _headers);
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      debugPrint('GET $path: $e');
    }
    return null;
  }

  // ── Theme-adaptive logo ───────────────────────────────────────────────────
  Widget _adaptiveLogo({double height = 48}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,  0,  0, 0, 255,
          0, -1,  0, 0, 255,
          0,  0, -1, 0, 255,
          0,  0,  0, 1,   0,
        ]),
        child: Image.asset('assets/images/konnectkashmir.png', height: height),
      );
    } else {
      return Image.asset('assets/images/konnectkashmir.png', height: height);
    }
  }

  @override
  void initState() {
    super.initState();
    // CHANGE 1: Removed scroll listener for nav hide/show — nav is now static
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll({bool quiet = false}) async {
    if (!quiet) setState(() => _isLoading = true);
    _userName = context.read<AuthProvider>().user?.name ?? 'Vendor';
    await Future.wait([
      _fetchProfile(),
      _fetchBusinessesAndLeads(),
      _fetchAds(),
      _fetchTransactions(),
    ]);
    setState(() => _isLoading = false);
  }

  // ── Profile ───────────────────────────────────────────────────────────────
  Future<void> _fetchProfile() async {
    try {
      final c = await _api.getUserCredits();
      if (c != null) setState(() => _credits = c);
    } catch (_) {}

    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    final rows = await _get(
        '/rest/v1/profiles?id=eq.$userId&select=referral_code,full_name&limit=1');
    if (rows != null && (rows as List).isNotEmpty) {
      final p = rows.first as Map<String, dynamic>;
      setState(() {
        _referralCode = p['referral_code'] as String? ?? '';
        final n = p['full_name'] as String?;
        if (n != null && n.isNotEmpty) _userName = n;
      });
    }
  }

  // ── Businesses + lead counts ──────────────────────────────────────────────
  Future<void> _fetchBusinessesAndLeads() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;

    final rows = await _get(
      '/rest/v1/vendors'
          '?user_id=eq.$userId'
          '&select=id,business_name,service_type,localities(name),is_approved,is_verified'
          '&order=created_at.desc',
    );
    if (rows == null) return;

    final bizList = List<Map<String, dynamic>>.from(rows as List);
    if (bizList.isEmpty) {
      setState(() => _businesses = []);
      return;
    }

    final vendorIds = bizList.map((b) => b['id'].toString()).toList();
    final leadsResult = await fetchLeadNames(context.read<AuthProvider>(), vendorIds);
    if (!mounted) return;

    final Map<String, List<Map<String, dynamic>>> byVendor = {};
    if (leadsResult['success'] == true && leadsResult['leads'] != null) {
      for (final lead in leadsResult['leads'] as List) {
        final vId = lead['vendor_id'].toString();
        byVendor
            .putIfAbsent(vId, () => [])
            .add(Map<String, dynamic>.from(lead as Map));
      }
      // Fresh data replaces what was cached (new leads must show up).
      _leadsByVendor
        ..clear()
        ..addAll(byVendor);
    } else {
      showAppSnack(context,
          "Couldn't load leads. ${leadsResult['error'] ?? ''}",
          type: SnackType.error);
    }

    setState(() {
      _businesses = bizList;

      if (widget.initialBusinessId != null && _selectedBiz == null) {
        try {
          _selectedBiz = _businesses.firstWhere((b) => b['id'].toString() == widget.initialBusinessId);
          if (_selectedBiz != null) {
            _loadLeadsForBusiness(widget.initialBusinessId!);
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _loadLeadsForBusiness(String vendorId) async {
    setState(() {
      _isLoadingLeads = true;
      _leads = [];
    });

    if (_leadsByVendor.containsKey(vendorId)) {
      setState(() {
        _leads = List<Map<String, dynamic>>.from(_leadsByVendor[vendorId]!);
        _isLoadingLeads = false;
      });
      return;
    }

    final result = await fetchLeadNames(context.read<AuthProvider>(), [vendorId]);
    if (!mounted) return;
    final leads = <Map<String, dynamic>>[];
    final ok = result['success'] == true && result['leads'] != null;
    if (ok) {
      for (final l in result['leads'] as List) {
        leads.add(Map<String, dynamic>.from(l as Map));
      }
    } else {
      showAppSnack(context,
          "Couldn't load leads. ${result['error'] ?? ''}",
          type: SnackType.error);
    }
    setState(() {
      _leads = leads;
      if (ok) _leadsByVendor[vendorId] = leads; // never cache a failed load as 0
      _isLoadingLeads = false;
    });
  }

  // ── Get Lead ──────────────────────────────────────────────────────────────
  Future<void> _getLead(Map<String, dynamic> lead) async {
    final leadId = lead['id'].toString();
    final userId = lead['user_id'].toString();
    final vendorId = _selectedBiz!['id'].toString();

    if (_revealedLeads[leadId] == true) {
      _showContactSheet(
          lead['user_name'] as String? ?? 'Customer',
          _revealedPhones[leadId] ?? '');
      return;
    }

    if (_credits <= 0) {
      _snack('Not enough credits. Watch an ad to earn credits.', AppColors.danger);
      return;
    }

    setState(() => _isRevealing[leadId] = true);

    try {
      final result = await _api.revealLeadPhone(userId, vendorId);

      if (result['success'] == true && result['phone'] != null) {
        final phone = result['phone'].toString();
        final name = result['name']?.toString() ??
            lead['user_name']?.toString() ?? 'Customer';
        final now = DateTime.now();
        setState(() {
          _revealedLeads[leadId] = true;
          _revealedPhones[leadId] = phone;
          _isRevealing[leadId] = false;
          _credits = (_credits - 1).clamp(0, 99999);
          _transactions.insert(0, {
            'type': 'unlock_contact',
            'title': 'Contact Unlocked',
            'subtitle': name,
            'amount': -1,
            'date': '${now.day} ${_month(now.month)} ${now.year}',
            'time':
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour < 12 ? 'am' : 'pm'}',
          });
        });
        _showContactSheet(name, phone);
      } else {
        setState(() => _isRevealing[leadId] = false);
        _snack(
            result['error']?.toString() ?? 'Could not reveal contact. Try again.',
            AppColors.danger);
      }
    } catch (e) {
      setState(() => _isRevealing[leadId] = false);
      _snack('Network error. Please try again.', AppColors.danger);
    }
  }

  void _showContactSheet(String name, String phone) {
    final cs = Theme.of(context).colorScheme;
    _snack('Lead contact revealed!', _kTealDark);
    showAppSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          Row(children: [
            const Icon(Icons.phone_outlined, color: _kOrange, size: 28),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contact Details',
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: AppText.title,
                              fontWeight: FontWeight.bold)),
                      Text('Contact information for $name',
                          style: TextStyle(
                              color: cs.onSurface.withOpacity(0.6), fontSize: AppText.secondary)),
                    ])),
            GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close, color: cs.onSurface.withOpacity(0.5))),
          ]),
          const SizedBox(height: 32),
          Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: _kOrange.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.person_outline, color: _kOrange, size: 40)),
          const SizedBox(height: 16),
          Text(name,
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: AppText.heading,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          phone.isNotEmpty
              ? Text('+91  $phone',
              style: const TextStyle(
                  color: _kTeal,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5))
              : Text('Phone not available',
              style: TextStyle(
                  color: cs.onSurface.withOpacity(0.5), fontSize: AppText.body)),
          const SizedBox(height: 28),
          if (phone.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  final uri = Uri(scheme: 'tel', path: phone);
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                style: AppButtons.danger,
                icon: const Icon(Icons.phone_in_talk, size: 22),
                label: const Text('Call Now',
                    style: TextStyle(fontSize: AppText.heading, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      ));
  }

  // ── Ads ───────────────────────────────────────────────────────────────────
  Future<void> _fetchAds() async {
    final ads = await _api.getAvailableAds();
    final counts = await _api.getUserAdViewCounts();
    setState(() {
      _ads = ads;
      _adViewCounts = counts.map((k, v) => MapEntry(k.toString(), v));
    });
  }

  Future<void> _watchAd(Map<String, dynamic> ad) async {
    final adId = ad['id'].toString();
    final maxV = ad['max_views_per_user'] as int? ?? 1;
    if ((_adViewCounts[adId] ?? 0) >= maxV) {
      _snack('You\'ve already watched this ad the maximum times.', AppColors.warning);
      return;
    }
    final done = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AdWatchDialog(ad: ad));
    if (done != true) return;

    final result = await _api.claimAdCredits(adId);
    final earned = (result['creditsEarned'] as num?)?.toInt() ??
        (ad['credits_reward'] as int? ?? 1);
    final newBal =
        (result['newBalance'] as num?)?.toInt() ?? (_credits + earned);
    final now = DateTime.now();

    setState(() {
      _credits = newBal;
      _adViewCounts[adId] = (_adViewCounts[adId] ?? 0) + 1;
      _transactions.insert(0, {
        'type': 'ad_reward',
        'title': 'Ad Reward',
        'subtitle': 'Watched ${ad['title']} ad',
        'amount': earned,
        'date': '${now.day} ${_month(now.month)} ${now.year}',
        'time':
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour < 12 ? 'am' : 'pm'}',
      });
    });
    _snack('+$earned credit${earned > 1 ? 's' : ''} earned! Balance: $newBal',
        _kTealDark);
  }

  // ── Transactions ──────────────────────────────────────────────────────────
  Future<void> _fetchTransactions() async {
    try {
      final list = await _api.getUserTransactions(limit: 20);
      setState(() {
        _transactions = list.map((r) {
          final type = r['transaction_type'] as String? ?? 'other';
          final amount = (r['amount'] as num?)?.toInt() ?? 0;
          final dt = DateTime.tryParse(r['created_at'] as String? ?? '') ??
              DateTime.now();
          return <String, dynamic>{
            'type': type,
            'title': _txTitle(type),
            'subtitle': r['description'] as String? ?? _txSub(type),
            'amount': amount,
            'date': '${dt.day} ${_month(dt.month)} ${dt.year}',
            'time':
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour < 12 ? 'am' : 'pm'}',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('fetchTransactions: $e');
    }
  }

  String _txTitle(String t) {
    switch (t) {
      case 'unlock_contact': return 'Contact Unlocked';
      case 'ad_reward':      return 'Ad Reward';
      case 'referral_bonus': return 'Referral Bonus';
      case 'initial_bonus':  return 'Welcome Bonus';
      default:               return 'Credit Activity';
    }
  }

  String _txSub(String t) {
    switch (t) {
      case 'unlock_contact': return 'Customer contact revealed';
      case 'ad_reward':      return 'Watched ad';
      case 'referral_bonus': return 'Referral reward';
      case 'initial_bonus':  return 'New account reward';
      default:               return '';
    }
  }

  String _month(int m) =>
      ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  Future<void> _enableNotifications() async {
    setState(() => _notifEnabled = true);
    _snack('Lead notifications enabled!', _kTealDark);
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    final type = bg == AppColors.danger
        ? SnackType.error
        : bg == AppColors.warning
            ? SnackType.warning
            : SnackType.success;
    showAppSnack(context, msg, type: type);
  }

  int get _totalLeads =>
      _leadsByVendor.values.fold(0, (s, l) => s + l.length);
  int get _totalActive =>
      _businesses.where((b) => b['is_approved'] == true).length;

  Color _tealContainer(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _kTealDark : _kTealLight;

  // ── Bottom Navigation ─────────────────────────────────────────────────────
  void _handleNavTap(int index) {
    switch (index) {
      case 0:
        setState(() => _selectedNavIndex = 0);
        break;
      case 1:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ListBusinessScreen()))
            .then((_) => _fetchBusinessesAndLeads());
        break;
      case 2:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CustomerScreen()));
        break;
      case 3:
        setState(() => _selectedNavIndex = 3);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ).then((_) {
          if (mounted) setState(() => _selectedNavIndex = 0);
        });
        break;
    }
  }

  Widget _buildBottomNavBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const activeColor = _kTeal;
    final inactiveColor = cs.onSurface.withOpacity(0.4);

    final List<_VendorNavItem> items = [
      _VendorNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
      _VendorNavItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront_rounded, label: 'Add Biz'),
      _VendorNavItem(icon: Icons.travel_explore, activeIcon: Icons.travel_explore, label: 'Browse'),
      _VendorNavItem(icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.baseBg(theme),
        border: Border(top: BorderSide(color: cs.onSurface.withOpacity(0.08))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = _selectedNavIndex == index;
              final showSelected = isSelected && index != 3;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handleNavTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: showSelected ? 28 : 0,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: showSelected ? activeColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Icon(
                          showSelected ? item.activeIcon : item.icon,
                          color: showSelected ? activeColor : inactiveColor,
                          size: showSelected ? 26 : 24,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: showSelected ? activeColor : inactiveColor,
                            fontSize: AppText.caption,
                            fontWeight: showSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            letterSpacing: showSelected ? 0.3 : 0,
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
  @override
  Widget build(BuildContext context) =>
      ForceLtr(child: _buildScreen(context));

  Widget _buildScreen(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // CHANGE 1: bottomNavigationBar is now static — no AnimatedSlide/AnimatedOpacity
      bottomNavigationBar: _buildBottomNavBar(),
      body: Stack(children: [
        Column(children: [
          _buildAppBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _kTeal))
                : RefreshIndicator(
              onRefresh: () => _loadAll(quiet: true),
              color: _kTeal,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(children: [
                  const SizedBox(height: 24),
                  _buildWelcomeHeader(),
                  const SizedBox(height: 20),
                  _buildCreditCard(),
                  const SizedBox(height: 16),
                  _buildWatchAdsCard(),
                  if (!_notifEnabled && !_notifDismissed) ...[
                    const SizedBox(height: 16),
                    _buildNotifBanner(),
                  ],
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                  const SizedBox(height: 16),
                  _buildMyBusinesses(),
                  if (_selectedBiz != null) ...[
                    const SizedBox(height: 16),
                    _buildLeadsSection(),
                  ],
                  const SizedBox(height: 16),
                  _buildTransactions(),
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
  // CHANGE 2: Removed "Browse" TextButton and "Sign Out" GestureDetector.
  //           Replaced with user avatar + name display on the right.
  Widget _buildAppBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.only(top: 44, left: 16, right: 16, bottom: 12),
      decoration: BoxDecoration(
          color: AppColors.baseBg(theme),
          border: Border(bottom: BorderSide(color: cs.onSurface.withOpacity(0.1)))),
      child: Row(children: [
        _adaptiveLogo(height: 44),
        const Spacer(),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _kTeal.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline, color: _kTeal, size: 18),
          ),
          const SizedBox(width: 8),
          Text(
            _userName,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: AppText.body,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Welcome header ────────────────────────────────────────────────────────
  // CHANGE 3: Removed the "Vendor Mode" teal badge — only title + greeting remain.
  Widget _buildWelcomeHeader() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Vendor Dashboard',
            style: TextStyle(
                color: cs.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Welcome back, $_userName! 👋',
            style: TextStyle(
                color: cs.onSurface.withOpacity(0.6), fontSize: AppText.body)),
      ]),
    );
  }

  // ── Credit Card ───────────────────────────────────────────────────────────
  Widget _buildCreditCard() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.onSurface.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ]),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Credit Balance',
                            style: TextStyle(
                                color: cs.onSurface,
                                fontSize: AppText.heading,
                                fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: _kOrange.withOpacity(0.15),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.toll_outlined,
                              color: _kOrange, size: 20),
                        ),
                      ]),
                  const SizedBox(height: 12),
                  Text('$_credits',
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 52,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      _credits > 0
                          ? 'Use credits to reveal customer leads'
                          : 'Watch ads below to earn credits',
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(0.6), fontSize: AppText.body)),
                ]),
          ),
          Divider(color: cs.onSurface.withOpacity(0.1), height: 1),
          InkWell(
            onTap: () => setState(() => _referExpanded = !_referExpanded),
            borderRadius: _referExpanded
                ? BorderRadius.zero
                : const BorderRadius.vertical(bottom: Radius.circular(AppRadius.lg)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                const Icon(Icons.group_outlined, color: _kTeal, size: 22),
                const SizedBox(width: 10),
                const Text('Refer & Earn Credits',
                    style: TextStyle(
                        color: _kTeal, fontSize: AppText.body, fontWeight: FontWeight.bold)),
                const Spacer(),
                Icon(
                    _referExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _kTeal),
              ]),
            ),
          ),
          if (_referExpanded) ...[
            Divider(color: cs.onSurface.withOpacity(0.1), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(children: [
                RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                        style: TextStyle(
                            color: cs.onSurface.withOpacity(0.6),
                            fontSize: AppText.body,
                            height: 1.6),
                        children: const [
                          TextSpan(text: 'You and your friend both earn '),
                          TextSpan(
                              text: '+10 credits',
                              style: TextStyle(
                                  color: _kOrange, fontWeight: FontWeight.bold)),
                          TextSpan(text: ' when they register as a vendor!'),
                        ])),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                            color: cs.onSurface.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                                color: cs.onSurface.withOpacity(0.1))),
                        child: Text(
                          _referralCode.isEmpty ? 'Loading...' : _referralCode,
                          style: TextStyle(
                              color: _referralCode.isEmpty
                                  ? cs.onSurface.withOpacity(0.4)
                                  : cs.onSurface,
                              fontSize: AppText.heading,
                              fontWeight: FontWeight.bold,
                              letterSpacing: _referralCode.isEmpty ? 0 : 3),
                          textAlign: TextAlign.center,
                        ),
                      )),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      if (_referralCode.isEmpty) return;
                      Clipboard.setData(ClipboardData(text: _referralCode));
                      _snack('Referral code copied!', _kTealDark);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: cs.onSurface.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: Icon(Icons.copy_rounded,
                          color: cs.onSurface, size: 22),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final code =
                      _referralCode.isEmpty ? 'my code' : _referralCode;
                      Share.share(
                          'Join KonnectKashmir as a vendor!\nUse my referral code *$code* '
                              'and we both earn +10 credits.\nhttps://konnectkashmir.com');
                    },
                    style: AppButtons.secondary,
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text('Share with Friends',
                        style: TextStyle(
                            fontSize: AppText.body, fontWeight: FontWeight.bold)),
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
  Widget _buildWatchAdsCard() {
    final cs = Theme.of(context).colorScheme;
    final watchable = _ads.where((ad) {
      if (ad['is_active'] != true) return false;
      final maxV = ad['max_views_per_user'] as int? ?? 1;
      return (_adViewCounts[ad['id'].toString()] ?? 0) < maxV;
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.onSurface.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ]),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.play_arrow, color: _kOrange, size: 28),
            const SizedBox(width: 8),
            Text('Watch Ads for Credits',
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: AppText.heading,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text('Watch short ads to earn free credits',
              style:
              TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: AppText.secondary)),
          const SizedBox(height: 16),
          if (watchable.isEmpty)
            _buildAllCaughtUp()
          else
            ...watchable.map((ad) => _buildAdItem(ad)),
        ]),
      ),
    );
  }

  Widget _buildAllCaughtUp() {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      const SizedBox(height: 8),
      Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kOrange, width: 3)),
          child: const Icon(Icons.check_rounded, color: _kOrange, size: 36)),
      const SizedBox(height: 12),
      Text('All caught up!',
          style: TextStyle(
              color: cs.onSurface, fontSize: AppText.body, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('No new ads right now.',
          style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: AppText.body)),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildAdItem(Map<String, dynamic> ad) {
    final cs = Theme.of(context).colorScheme;
    final adId = ad['id'].toString();
    final reward = ad['credits_reward'] as int? ?? 1;
    final maxV = ad['max_views_per_user'] as int? ?? 1;
    final watched = _adViewCounts[adId] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: cs.onSurface.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: _kOrange.withOpacity(0.3))),
      child: Row(children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 26)),
        const SizedBox(width: 12),
        Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ad['title'] as String? ?? '',
                  style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: AppText.body),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: _kOrange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border:
                          Border.all(color: _kOrange.withOpacity(0.4))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.toll_outlined,
                            color: _kOrange, size: 12),
                        const SizedBox(width: 3),
                        Text('+$reward credit${reward > 1 ? 's' : ''}',
                            style: const TextStyle(
                                color: _kOrange,
                                fontSize: AppText.caption,
                                fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    Text('${maxV - watched} left',
                        style: TextStyle(
                            color: cs.onSurface.withOpacity(0.4),
                            fontSize: AppText.caption)),
                  ]),
            ])),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _watchAd(ad),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: _tealContainer(context),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: _kTeal.withOpacity(0.5))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.monetization_on, color: _kTeal, size: 16),
              const SizedBox(width: 4),
              Text('+$reward',
                  style: const TextStyle(
                      color: _kTeal,
                      fontWeight: FontWeight.bold,
                      fontSize: AppText.body)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Notification Banner ───────────────────────────────────────────────────
  Widget _buildNotifBanner() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: _kTeal.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.notifications_outlined, color: _kTeal, size: 22),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Enable Lead Notifications',
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: AppText.body,
                        fontWeight: FontWeight.bold))),
            GestureDetector(
                onTap: () => setState(() => _notifDismissed = true),
                child: Icon(Icons.close,
                    color: cs.onSurface.withOpacity(0.5), size: 20)),
          ]),
          const SizedBox(height: 8),
          Text(
              'Get instant alerts when customers show interest in your business',
              style: TextStyle(
                  color: cs.onSurface.withOpacity(0.6),
                  fontSize: AppText.secondary,
                  height: 1.5)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _enableNotifications,
              style: AppButtons.secondary,
              icon: const Icon(Icons.notifications_active, size: 20),
              label: const Text('Enable Notifications',
                  style: TextStyle(fontSize: AppText.body, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(
            child: _statCard(Icons.storefront_outlined,
                '${_businesses.length}', 'Businesses', _kTeal)),
        const SizedBox(width: 12),
        Expanded(
            child: _statCard(
                Icons.people_outline, '$_totalLeads', 'Total Leads', _kOrange)),
        const SizedBox(width: 12),
        Expanded(
            child: _statCard(Icons.trending_up, '$_totalActive', 'Active',
                _kOrange.withOpacity(0.8))),
      ]),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.onSurface.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                color: cs.onSurface,
                fontSize: AppText.title,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: cs.onSurface.withOpacity(0.4), fontSize: AppText.caption),
            textAlign: TextAlign.center),
      ]),
    );
  }

  // ── My Businesses ─────────────────────────────────────────────────────────
  Widget _buildMyBusinesses() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.onSurface.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.storefront, color: _kTeal, size: 24),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Businesses',
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: AppText.heading,
                              fontWeight: FontWeight.bold)),
                      Text('Select a business to view its leads',
                          style: TextStyle(
                              color: cs.onSurface.withOpacity(0.4),
                              fontSize: AppText.caption)),
                    ])),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ListBusinessScreen()))
                  .then((_) => _fetchBusinessesAndLeads()),
              style: AppButtons.compact(AppButtons.secondary),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add New',
                  style: TextStyle(fontSize: AppText.secondary, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 16),
          if (_businesses.isEmpty)
            _buildNoBusiness()
          else ...[
            ..._businesses.map((b) => _buildBizCard(b)),
            if (_selectedBiz == null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: cs.onSurface.withOpacity(0.08))),
                child: Column(children: [
                  Icon(Icons.people_outline,
                      color: cs.onSurface.withOpacity(0.3), size: 40),
                  const SizedBox(height: 12),
                  Text(
                      'You have $_totalLeads total lead${_totalLeads != 1 ? 's' : ''}',
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: AppText.body,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Select a business above to view its leads',
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(0.4), fontSize: AppText.secondary)),
                ]),
              ),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _buildNoBusiness() {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      const SizedBox(height: 8),
      Icon(Icons.storefront_outlined,
          color: cs.onSurface.withOpacity(0.3), size: 48),
      const SizedBox(height: 12),
      Text('No businesses yet',
          style:
          TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: AppText.body)),
      const SizedBox(height: 4),
      Text('Tap "Add New" to list your first business',
          style:
          TextStyle(color: cs.onSurface.withOpacity(0.4), fontSize: AppText.secondary)),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildBizCard(Map<String, dynamic> biz) {
    final cs = Theme.of(context).colorScheme;
    final bizId = biz['id'].toString();
    final name = biz['business_name'] as String? ?? 'Business';
    final svcType = biz['service_type'] as String? ?? '';
    final locality = (biz['localities'] as Map?)?['name']?.toString() ?? '';
    final leadCount = _leadsByVendor[bizId]?.length ?? 0;
    final isApproved = biz['is_approved'] == true;
    final isSelected = _selectedBiz?['id'] == biz['id'];

    const svcIcons = <String, IconData>{
      'electrician': Icons.bolt,
      'plumber':     Icons.plumbing,
      'carpenter':   Icons.handyman,
      'painter':     Icons.brush,
      'cleaner':     Icons.cleaning_services,
      'catering':    Icons.restaurant,
      'mechanic':    Icons.build,
      'home_tutor':  Icons.school,
    };

    return GestureDetector(
      onTap: () async {
        if (isSelected) {
          setState(() { _selectedBiz = null; _leads = []; });
        } else {
          setState(() => _selectedBiz = biz);
          await _loadLeadsForBusiness(bizId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withOpacity(0.08)
              : cs.onSurface.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.08),
              width: isSelected ? 1.5 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _tealContainer(context),
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Icon(svcIcons[svcType] ?? Icons.storefront,
                  color: _kTeal, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: AppText.body,
                              fontWeight: FontWeight.bold)),
                      Text('${_formatSlug(svcType)} • $locality',
                          style: TextStyle(
                              color: cs.onSurface.withOpacity(0.6),
                              fontSize: AppText.secondary)),
                    ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Text('$leadCount',
                    style: TextStyle(
                        color: cs.onSurface, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: isApproved
                        ? AppColors.success.withOpacity(0.15)
                        : AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Text(isApproved ? 'Active' : 'Pending',
                    style: TextStyle(
                        color: isApproved ? AppColors.success : AppColors.warning,
                        fontSize: AppText.caption,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ListBusinessScreen(existingVendor: biz)))
                  .then((_) => _fetchBusinessesAndLeads()),
              style: AppButtons.secondary,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit', style: TextStyle(fontSize: AppText.secondary)),
            ),
          ),
        ]),
      ),
    );
  }

  String _formatSlug(String slug) => slug
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  // ── Leads Section ─────────────────────────────────────────────────────────
  Widget _buildLeadsSection() {
    final cs = Theme.of(context).colorScheme;
    final bizName = _selectedBiz!['business_name'] as String? ?? 'Business';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.onSurface.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.storefront_outlined, color: _kTeal, size: 22),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Leads for $bizName',
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: AppText.heading,
                              fontWeight: FontWeight.bold)),
                      Text('Customers who showed interest in this business',
                          style: TextStyle(
                              color: cs.onSurface.withOpacity(0.4),
                              fontSize: AppText.caption)),
                    ])),
          ]),
          const SizedBox(height: 16),
          if (_isLoadingLeads)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: _kTeal)))
          else if (_leads.isEmpty)
            Column(children: [
              const SizedBox(height: 8),
              Icon(Icons.people_outline,
                  color: cs.onSurface.withOpacity(0.3), size: 40),
              const SizedBox(height: 12),
              Text('No leads yet',
                  style: TextStyle(
                      color: cs.onSurface.withOpacity(0.6), fontSize: AppText.body)),
              const SizedBox(height: 4),
              Text('When customers unlock your contact, they appear here',
                  style: TextStyle(
                      color: cs.onSurface.withOpacity(0.4), fontSize: AppText.secondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
            ])
          else
            ..._leads.map((l) => _buildLeadCard(l)),
        ]),
      ),
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> lead) {
    final cs = Theme.of(context).colorScheme;
    final leadId = lead['id'].toString();
    final name = lead['user_name'] as String? ?? 'Customer';
    final dt = DateTime.tryParse(lead['created_at'] as String? ?? '') ??
        DateTime.now();
    final dateStr = '${dt.day} ${_month(dt.month)} ${dt.year}';
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour < 12 ? 'am' : 'pm'}';
    final isRevealed = _revealedLeads[leadId] == true;
    final isReveal = _isRevealing[leadId] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cs.onSurface.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.onSurface.withOpacity(0.08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person_outline, color: _kTeal, size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: AppText.body,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.calendar_today_outlined,
                          color: cs.onSurface.withOpacity(0.4), size: 13),
                      const SizedBox(width: 4),
                      Text(dateStr,
                          style: TextStyle(
                              color: cs.onSurface.withOpacity(0.4),
                              fontSize: AppText.caption)),
                      const SizedBox(width: 10),
                      Icon(Icons.access_time_outlined,
                          color: cs.onSurface.withOpacity(0.4), size: 13),
                      const SizedBox(width: 4),
                      Text(timeStr,
                          style: TextStyle(
                              color: cs.onSurface.withOpacity(0.4),
                              fontSize: AppText.caption)),
                    ]),
                  ])),
          if (isRevealed)
            GestureDetector(
              onTap: () => setState(
                      () => _leads.removeWhere((l) => l['id'] == lead['id'])),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.delete_outline,
                    color: cs.onSurface.withOpacity(0.4), size: 20),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: isReveal ? null : () => _getLead(lead),
          style: AppButtons.block(isRevealed
              ? AppButtons.withBg(AppButtons.primary, AppColors.success)
              : AppButtons.secondary),
          icon: isReveal
              ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : Icon(
              isRevealed ? Icons.visibility : Icons.visibility_outlined,
              size: 18),
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(isRevealed ? 'View Contact' : 'Get Lead',
                style: const TextStyle(
                    fontSize: AppText.body, fontWeight: FontWeight.bold)),
            if (!isRevealed && !isReveal) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Text('1',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: AppText.secondary)),
              ),
            ],
          ]),
        ),
        if (!isRevealed && !isReveal) ...[
          const SizedBox(height: 6),
          Center(
              child: Text(
                _credits > 0
                    ? 'Costs 1 credit to reveal contact'
                    : 'Watch an ad to earn credits first',
                style: TextStyle(
                    color: cs.onSurface.withOpacity(0.4), fontSize: AppText.caption),
              )),
        ],
      ]),
    );
  }

  // ── Transaction History ───────────────────────────────────────────────────
  Widget _buildTransactions() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.onSurface.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.history, color: _kTeal, size: 26),
            const SizedBox(width: 10),
            Text('Transaction History',
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: AppText.heading,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text('Your credit activity',
              style: TextStyle(
                  color: cs.onSurface.withOpacity(0.4), fontSize: AppText.secondary)),
          const SizedBox(height: 16),
          if (_transactions.isEmpty)
            Column(children: [
              const SizedBox(height: 8),
              Icon(Icons.receipt_long_outlined,
                  color: cs.onSurface.withOpacity(0.3), size: 40),
              const SizedBox(height: 12),
              Text('No transactions yet',
                  style: TextStyle(
                      color: cs.onSurface.withOpacity(0.6), fontSize: AppText.body)),
              const SizedBox(height: 8),
            ])
          else
            ..._transactions.map((tx) => _buildTxItem(tx)),
        ]),
      ),
    );
  }

  Widget _buildTxItem(Map<String, dynamic> tx) {
    final cs = Theme.of(context).colorScheme;
    final amount = tx['amount'] as int;
    final isCredit = amount > 0;
    final type = tx['type'] as String;

    IconData txIcon;
    Color txColor, txBg;
    switch (type) {
      case 'unlock_contact':
        txIcon = Icons.lock_open_outlined;
        txColor = _kTeal;
        txBg = _tealContainer(context);
        break;
      case 'ad_reward':
        txIcon = Icons.play_circle_outline;
        txColor = _kOrange;
        txBg = _kOrange.withOpacity(0.15);
        break;
      case 'referral_bonus':
      case 'initial_bonus':
        txIcon = Icons.card_giftcard;
        txColor = Colors.purple.shade300;
        txBg = Colors.purple.withOpacity(0.15);
        break;
      default:
        txIcon = Icons.swap_horiz;
        txColor = cs.onSurface.withOpacity(0.6);
        txBg = cs.onSurface.withOpacity(0.08);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: cs.onSurface.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: cs.onSurface.withOpacity(0.08))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration:
          BoxDecoration(color: txBg, borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Icon(txIcon, color: txColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx['title'] as String,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: AppText.body)),
                  const SizedBox(height: 2),
                  Text(tx['subtitle'] as String,
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(0.6), fontSize: AppText.secondary)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        color: cs.onSurface.withOpacity(0.4), size: 12),
                    const SizedBox(width: 4),
                    Text(tx['date'] as String,
                        style: TextStyle(
                            color: cs.onSurface.withOpacity(0.4), fontSize: AppText.caption)),
                    const SizedBox(width: 10),
                    Icon(Icons.access_time_outlined,
                        color: cs.onSurface.withOpacity(0.4), size: 12),
                    const SizedBox(width: 4),
                    Text(tx['time'] as String,
                        style: TextStyle(
                            color: cs.onSurface.withOpacity(0.4), fontSize: AppText.caption)),
                  ]),
                ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(isCredit ? '+$amount' : '$amount',
              style: TextStyle(
                  color: isCredit ? _kOrange : _kTeal,
                  fontSize: AppText.heading,
                  fontWeight: FontWeight.bold)),
          Text(amount.abs() == 1 ? 'credit' : 'credits',
              style: TextStyle(
                  color: isCredit ? _kOrange : _kTeal,
                  fontSize: AppText.caption,
                  fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }

  Future<void> _confirmSignOut() async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out',
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.6)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign Out',
                  style: TextStyle(color: AppColors.danger))),
        ]),
    );
    if (ok == true && mounted) {
      await context.read<AuthProvider>().logout();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}

// ── Helper model for bottom nav items ────────────────────────────────────────
class _VendorNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _VendorNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}