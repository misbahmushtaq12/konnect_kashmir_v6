import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/lead_loader.dart';
import '../widgets/lead_contact_sheet.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

import 'login_screen.dart';
import 'vendor_screen.dart';

/// My Business tab: shows the user's registered businesses, or a
/// "List my business" prompt if they have none.
class MyBusinessTab extends StatefulWidget {
  /// False while another bottom-nav tab is showing (this tab stays alive in an
  /// IndexedStack); returning to it refreshes businesses and leads.
  final bool isActive;
  const MyBusinessTab({super.key, this.isActive = true});

  @override
  State<MyBusinessTab> createState() => _MyBusinessTabState();
}

class _MyBusinessTabState extends State<MyBusinessTab> {
  static const String _baseUrl = 'https://fmmpsqnpezjofsluirrv.supabase.co';

  List<Map<String, dynamic>> _businesses = [];
  Map<String, List<dynamic>> _leadsByVendor = {};
  bool _loading = true;
  String? _errorMsg;
  String? _expandedBizId;

  // Revealed lead phones stay for this session so re-opening never re-charges.
  final Map<String, String> _revealedPhones = {};
  final Set<String> _revealing = {};

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg, maxLines: 3)));
  }

  /// The stored session can no longer be refreshed (server rejects it), so the
  /// only fix is a fresh sign-in. Same flow as Profile > Sign out.
  Future<void> _signInAgain() async {
    final nav = Navigator.of(context, rootNavigator: true);
    await context.read<AuthProvider>().logout();
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ── Remembering revealed leads ────────────────────────────────────────────
  // Only lead IDs are stored (never phone numbers). The number is fetched again
  // when needed; that call returns the phone without charging a credit.
  String _revealKey(AuthProvider a) => 'revealed_leads_${a.userId}';

  Future<Map<String, dynamic>> _revealWithRetry(
      AuthProvider auth, String leadUserId, String vendorId) async {
    ApiService api() =>
        ApiService(token: auth.accessToken, userId: auth.userId);
    var r = await api().revealLeadPhone(leadUserId, vendorId);
    // A rejected token is refused before anything is charged: refresh, retry.
    if (r['success'] != true &&
        '${r['error']}'.contains('(401)') &&
        await auth.refreshToken()) {
      r = await api().revealLeadPhone(leadUserId, vendorId);
    }
    return r;
  }

  Future<void> _rememberRevealed(AuthProvider auth, String leadId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_revealKey(auth)) ?? <String>[];
      if (!ids.contains(leadId)) {
        ids.add(leadId);
        await prefs.setStringList(_revealKey(auth), ids);
      }
    } catch (_) {}
  }

  Future<void> _restoreRevealed() async {
    try {
      final auth = context.read<AuthProvider>();
      final prefs = await SharedPreferences.getInstance();
      final ids = (prefs.getStringList(_revealKey(auth)) ?? <String>[]).toSet();
      if (ids.isEmpty) return;

      final jobs = <Future<void>>[];
      _leadsByVendor.forEach((vendorId, leads) {
        for (final lead in leads) {
          final id = lead['id'].toString();
          if (!ids.contains(id) || _revealedPhones.containsKey(id)) continue;
          jobs.add(() async {
            final r = await _revealWithRetry(
                auth, lead['user_id'].toString(), vendorId);
            if (r['success'] == true && r['phone'] != null && mounted) {
              setState(() => _revealedPhones[id] = r['phone'].toString());
            }
          }());
        }
      });
      await Future.wait(jobs);
    } catch (_) {}
  }

  String _digits(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

  String _displayPhone(String phone) {
    final d = _digits(phone);
    if (d.length == 10) return '+91  $d';
    if (d.length == 12 && d.startsWith('91')) return '+91  ${d.substring(2)}';
    return phone;
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: _digits(phone));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phone) async {
    final d = _digits(phone);
    final number = d.length == 10 ? '91$d' : d;
    try {
      await launchUrl(Uri.parse('https://wa.me/$number'),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      _snack("Couldn't open WhatsApp");
    }
  }

  /// Shown instead of "Get Lead" once the contact is revealed: number + chat.
  Widget _revealedContact(String phone) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Expanded(
          child: InkWell(
            onTap: () => _callPhone(phone),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                const Icon(Icons.phone_outlined,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(_displayPhone(phone),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ),
              ]),
            ),
          ),
        ),
        IconButton(
          onPressed: () => _openWhatsApp(phone),
          tooltip: 'Chat on WhatsApp',
          icon: const FaIcon(FontAwesomeIcons.whatsapp,
              color: Color(0xFF25D366), size: 26),
        ),
      ]),
    );
  }

  /// `reveal-lead-phone` returns the number but does not always charge. If the
  /// balance did not drop after the reveal, spend the 1 credit here (once), then
  /// verify it really changed.
  Future<void> _ensureCreditSpent(AuthProvider auth, int? before) async {
    if (before == null || before <= 0) return;
    ApiService api() =>
        ApiService(token: auth.accessToken, userId: auth.userId);
    try {
      final after = await api().getUserCredits();
      if (after == null || after < before) return; // server already charged
      await api().updateUserCredits(auth.userId, -1);
      final verify = await api().getUserCredits();
      if (verify != null && verify >= before) {
        _snack('Contact revealed, but your credit balance could not be updated.');
      }
    } catch (_) {}
  }

  /// Reveals the lead's contact (1 credit) and shows it in a sheet, in place.
  Future<void> _getLead(dynamic lead, String vendorId) async {
    final leadId = lead['id'].toString();
    final name = lead['user_name']?.toString() ?? 'Customer';

    final cached = _revealedPhones[leadId];
    if (cached != null) {
      showLeadContactSheet(context, name, cached);
      return;
    }

    final auth = context.read<AuthProvider>();
    setState(() => _revealing.add(leadId));
    try {
      ApiService api() =>
          ApiService(token: auth.accessToken, userId: auth.userId);

      final credits = await api().getUserCredits();
      if (credits != null && credits <= 0) {
        _snack('Not enough credits. Watch an ad to earn credits.');
        return;
      }

      final leadUserId = lead['user_id'].toString();
      final result = await _revealWithRetry(auth, leadUserId, vendorId);
      if (!mounted) return;

      if (result['success'] == true && result['phone'] != null) {
        final phone = result['phone'].toString();
        final shownName = result['name']?.toString() ?? name;
        await _ensureCreditSpent(auth, credits);
        await _rememberRevealed(auth, leadId);
        // Stop the button spinner BEFORE the sheet opens, not after it closes.
        setState(() {
          _revealedPhones[leadId] = phone;
          _revealing.remove(leadId);
        });
        await showLeadContactSheet(context, shownName, phone);
      } else {
        _snack(result['error']?.toString() ??
            'Could not reveal contact. Try again.');
      }
    } catch (_) {
      _snack('Network error. Please try again.');
    } finally {
      if (mounted && _revealing.contains(leadId)) {
        setState(() => _revealing.remove(leadId));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MyBusinessTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Back on this tab: pick up new leads without showing the skeleton again.
    if (!oldWidget.isActive && widget.isActive) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    if (mounted && !silent) setState(() => _loading = true);
    try {
      final uri = Uri.parse('$_baseUrl/rest/v1/vendors').replace(
        queryParameters: {
          'user_id': 'eq.$userId',
          'select': '*,localities(name)',
          'order': 'created_at.desc',
        },
      );
      final res = await http
          .get(uri, headers: auth.authHeaders)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final bizList = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        
        final vendorIds = bizList.map((b) => b['id'].toString()).toList();

        Map<String, List<dynamic>> leadsByVendor = {};
        bool leadsFailed = false;
        String? leadsError;
        if (vendorIds.isNotEmpty) {
          final leadsResult = await fetchLeadNames(auth, vendorIds);
          if (leadsResult['success'] == true && leadsResult['leads'] != null) {
            for (final lead in leadsResult['leads'] as List) {
              final vId = lead['vendor_id'].toString();
              leadsByVendor.putIfAbsent(vId, () => []).add(lead);
            }
          } else {
            leadsFailed = true;
            leadsError = leadsResult['error']?.toString();
          }
        }

        if (!mounted) return;
        if (leadsFailed) {
          // Don't wipe leads we already have with a false "0".
          final expired = (leadsError ?? '').contains('(401)');
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              duration: Duration(seconds: expired ? 12 : 4),
              content: Text(
                  expired
                      ? 'Your session has expired, so leads cannot load. '
                          'Please sign in again.'
                      : "Couldn't refresh leads. ${leadsError ?? ''}",
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              action: expired
                  ? SnackBarAction(label: 'Sign in', onPressed: _signInAgain)
                  : null,
            ));
        }
        setState(() {
          _businesses = bizList;
          if (!leadsFailed) _leadsByVendor = leadsByVendor;
          _errorMsg = null;
          _loading = false;
        });
        _restoreRevealed(); // leads revealed earlier show their number again
        return;
      }

      if (!mounted || silent) return; // a failed background refresh keeps old data
      setState(() {
        _errorMsg = 'Server returned status code: ${res.statusCode}\nResponse: ${res.body}';
        _loading = false;
      });
      return;
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _errorMsg = e.toString();
        _loading = false;
      });
    }
  }

  double _viewportHeight = 0;

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load(); // pick up new / edited business
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final hPad = size.width > 600 ? size.width * 0.12 : 20.0;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _load,
            child: LayoutBuilder(builder: (context, constraints) {
              _viewportHeight = constraints.maxHeight;
              return ListView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('My Business',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    if (!_loading && _errorMsg == null && _businesses.isNotEmpty)
                      IconButton(
                        onPressed: () => _push(const ListBusinessScreen()),
                        icon: const Icon(Icons.add_circle_outline, size: 28),
                        color: AppColors.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loading)
                  ..._skeletons()
                else if (_errorMsg != null)
                  _errorState()
                else if (_businesses.isEmpty)
                  _emptyState()
                else ...[
                  for (final b in _businesses) _businessCard(b),
                ],
              ],
              );
            }),
          ),
        ),
      ),
    );
  }

  List<Widget> _skeletons() => [
        for (var i = 0; i < 1; i++) ...[
          const Skeleton(height: 170, radius: AppRadius.lg),
          const SizedBox(height: 14),
        ]
      ];

  Widget _emptyState() {
    final cs = Theme.of(context).colorScheme;
    // Exact space left below the title: viewport minus list padding (12 top,
    // 24 bottom), title row (~32) and the 16px gap under it.
    const double headerHeight = 12 + 32 + 16 + 24;
    final double availableHeight =
        (_viewportHeight - headerHeight).clamp(360.0, double.infinity);

    return SizedBox(
      height: availableHeight,
      child: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - val)),
              child: Opacity(
                opacity: val,
                child: child,
              ),
            );
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_rounded,
                  size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 28),
            const Text("You haven't listed a business yet",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'List your services and get discovered by customers across Kashmir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: cs.onSurface.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _push(const ListBusinessScreen()),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(240, 56)),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('List my business',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _errorState() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(children: [
        Icon(Icons.wifi_off_rounded,
            size: 40, color: cs.onSurface.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        const Text("Couldn't load your business",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        if (_errorMsg != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
            child: Text(
              _errorMsg!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error, fontSize: 13),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _load,
          style: OutlinedButton.styleFrom(minimumSize: const Size(140, 46)),
          child: const Text('Retry'),
        ),
      ]),
    );
  }

  Widget _businessCard(Map<String, dynamic> b) {
    final cs = Theme.of(context).colorScheme;
    final name = (b['business_name'] ?? 'Business').toString();
    final svcType = b['service_type']?.toString() ?? '';
    final locality = b['localities'] is Map
        ? (b['localities']['name']?.toString() ?? '')
        : '';
    final isApproved = b['is_approved'] == true;
    final bizId = b['id']?.toString();

    String formatSlug(String s) {
      if (s.isEmpty) return '';
      return s
          .split('_')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }

    const svcIcons = <String, IconData>{
      'electrician': Icons.bolt,
      'plumber': Icons.plumbing,
      'carpenter': Icons.handyman,
      'painter': Icons.brush,
      'cleaner': Icons.cleaning_services,
      'catering': Icons.restaurant,
      'mechanic': Icons.build,
      'home_tutor': Icons.school,
    };

    final kTeal = AppColors.primary;
    final tealContainer = kTeal.withValues(alpha: 0.15);

    return GestureDetector(
      onTap: () => setState(() {
        if (_expandedBizId == bizId) {
          _expandedBizId = null;
        } else {
          _expandedBizId = bizId;
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: tealContainer,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(svcIcons[svcType] ?? Icons.storefront,
                  color: kTeal, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  Text('${formatSlug(svcType)} • $locality',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontSize: 13)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: tealContainer,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_alt_rounded, size: 12, color: kTeal),
                    const SizedBox(width: 4),
                    Text('${_leadsByVendor[bizId]?.length ?? 0} Leads',
                        style: TextStyle(
                            fontSize: 11,
                            color: kTeal,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: isApproved
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(isApproved ? 'Active' : 'Pending',
                    style: TextStyle(
                        color: isApproved ? Colors.green : Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _push(ListBusinessScreen(existingVendor: b)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                      foregroundColor: cs.onSurface,
                      elevation: 0,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() {
                    if (_expandedBizId == bizId) {
                      _expandedBizId = null;
                    } else {
                      _expandedBizId = bizId;
                    }
                  }),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: tealContainer,
                      foregroundColor: kTeal,
                      elevation: 0,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  icon: Icon(_expandedBizId == bizId ? Icons.expand_less : Icons.expand_more, size: 18),
                  label: const Text('Leads',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          if (_expandedBizId == bizId) ...[
            const SizedBox(height: 16),
            Divider(color: cs.onSurface.withValues(alpha: 0.08)),
            const SizedBox(height: 8),
            if ((_leadsByVendor[bizId] ?? []).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text('No leads yet',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontSize: 13)),
                ),
              )
            else
              ...(_leadsByVendor[bizId] ?? []).map((lead) {
                final leadName = lead['user_name']?.toString() ?? 'Customer';
                final dtStr = lead['created_at']?.toString() ?? '';
                final dt = DateTime.tryParse(dtStr) ?? DateTime.now();
                
                String monthName(int m) {
                  const mths = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                  return m >= 1 && m <= 12 ? mths[m - 1] : '';
                }
                final dateStr = '${dt.day} ${monthName(dt.month)} ${dt.year}';
                final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour < 12 ? 'am' : 'pm'}';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.onSurface.withValues(alpha: 0.08))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.person_outline, color: kTeal, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(leadName,
                                    style: TextStyle(
                                        color: cs.onSurface,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(Icons.calendar_today_outlined,
                                      color: cs.onSurface.withValues(alpha: 0.4), size: 13),
                                  const SizedBox(width: 4),
                                  Text(dateStr,
                                      style: TextStyle(
                                          color: cs.onSurface.withValues(alpha: 0.4),
                                          fontSize: 12)),
                                  const SizedBox(width: 10),
                                  Icon(Icons.access_time_outlined,
                                      color: cs.onSurface.withValues(alpha: 0.4), size: 13),
                                  const SizedBox(width: 4),
                                  Text(timeStr,
                                      style: TextStyle(
                                          color: cs.onSurface.withValues(alpha: 0.4),
                                          fontSize: 12)),
                                ]),
                              ])),
                    ]),
                    const SizedBox(height: 12),
                    if (_revealedPhones.containsKey(lead['id'].toString()))
                      _revealedContact(_revealedPhones[lead['id'].toString()]!)
                    else ...[
                    ElevatedButton.icon(
                      onPressed: _revealing.contains(lead['id'].toString())
                          ? null
                          : () => _getLead(lead, bizId ?? ""),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tealContainer,
                        foregroundColor: kTeal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: _revealing.contains(lead['id'].toString())
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.visibility_outlined, size: 18),
                      label: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Get Lead',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: kTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Text('1',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text('Costs 1 credit to reveal contact',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.4),
                              fontSize: 11)),
                    ),
                    ],
                  ]),
                );
              }),
          ],
        ]),
      ),
    );
  }
}
