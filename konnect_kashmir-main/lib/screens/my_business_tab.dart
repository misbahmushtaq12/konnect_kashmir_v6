import 'dart:convert';

import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/live_sync.dart';
import '../widgets/app_chip.dart';
import '../widgets/category_meta.dart';
import '../widgets/app_header.dart';
import '../widgets/app_snack.dart';
import '../widgets/error_retry.dart';
import '../services/lead_loader.dart';
import '../widgets/lead_contact_sheet.dart';
import '../theme/app_theme.dart';

import 'ad_credits_screen.dart';
import 'login_screen.dart';
import 'vendor_screen.dart';

/// My Business tab: shows the user's registered businesses, or a
/// context.l10n.listMyBusiness prompt if they have none.
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
  // The one shared balance (live from the backend); null until first loaded.
  int? get _credits => context.read<LiveSync>().credits;
  int? _leadsTick;

  // Revealed lead phones stay for this session so re-opening never re-charges.
  final Map<String, String> _revealedPhones = {};
  final Set<String> _revealing = {};

  void _snack(String msg, {SnackType type = SnackType.info}) {
    if (!mounted) return;
    showAppSnack(context, msg, type: type);
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
      _snack(context.l10n.couldntOpenWhatsapp, type: SnackType.error);
    }
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
        _snack(context.l10n.snackRevealedNoBalance,
            type: SnackType.warning);
      }
    } catch (_) {}
  }

  /// Reveals the lead's contact (1 credit) and shows it in a sheet, in place.
  Future<void> _getLead(dynamic lead, String vendorId) async {
    final leadId = lead['id'].toString();
    final name = lead['user_name']?.toString() ?? context.l10n.customer;

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
        _snack(context.l10n.snackNotEnoughCredits,
            type: SnackType.warning);
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
        HapticFeedback.lightImpact(); // gentle buzz: contact revealed
        _loadCredits(force: true);
        context.read<LiveSync>().transactionHappened();
        // Stop the button spinner BEFORE the sheet opens, not after it closes.
        setState(() {
          _revealedPhones[leadId] = phone;
          _revealing.remove(leadId);
        });
        await showLeadContactSheet(context, shownName, phone);
      } else {
        _snack(result['error']?.toString() ??
            context.l10n.snackCouldNotReveal, type: SnackType.error);
      }
    } catch (_) {
      _snack(context.l10n.snackNetworkError, type: SnackType.error);
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

  // New lead activity reported by the backend refreshes the leads at once.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tick = context.watch<LiveSync>().leadsTick;
    if (_leadsTick != null && tick != _leadsTick) _load(silent: true);
    _leadsTick = tick;
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
    _loadCredits(); // header balance (quiet)
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
          showAppSnack(
            context,
            expired
                ? context.l10n.snackSessionExpiredLeads
                : context.l10n.snackCouldntRefreshLeads(leadsError ?? ''),
            type: expired ? SnackType.warning : SnackType.error,
            duration: Duration(seconds: expired ? 12 : 4),
            action: expired
                ? SnackBarAction(label: context.l10n.signIn, onPressed: _signInAgain)
                : null,
          );
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
    context.watch<LiveSync>(); // rebuild when the shared balance changes
    final size = MediaQuery.of(context).size;
    final hPad = size.width > 600 ? size.width * 0.12 : 20.0;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _load(silent: true),
            child: LayoutBuilder(builder: (context, constraints) {
              _viewportHeight = constraints.maxHeight;
              return ListView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
              children: [
                AppHeader(
                  title: context.l10n.navMyBusiness,
                  actions: [
                    if (_credits != null) CreditChip(_credits!),
                    if (!_loading && _errorMsg == null && _businesses.isNotEmpty)
                      IconButton(
                        onPressed: () => _push(const ListBusinessScreen()),
                        icon: const Icon(Icons.add_circle_outline, size: 28),
                        color: AppColors.primary,
                      ),
                  ],
                ),
                if (_credits == 0) _outOfCreditsBanner(),
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

  // ── Credits ───────────────────────────────────────────────────────────────
  Future<void> _loadCredits({bool force = false}) async {
    await context.read<LiveSync>().refreshCredits(force: force);
  }

  Future<void> _openAds() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AdCreditsScreen()));
    if (mounted) _loadCredits(force: true);
  }

  Widget _outOfCreditsBanner() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded,
            size: 20, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(context.l10n.noCreditsBanner,
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.85),
                  fontSize: AppText.secondary,
                  height: 1.3)),
        ),
        FilledButton.icon(
          onPressed: _openAds,
          icon: const Icon(Icons.play_arrow_rounded, size: 20),
          label: Text(context.l10n.watchAd),
          style: AppButtons.compact(AppButtons.primary),
        ),
      ]),
    );
  }

  // "just now", "5 min ago", "2 hours ago", "3 days ago", else the date.
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return context.l10n.timeJustNow;
    if (diff.inMinutes < 60) return context.l10n.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return context.l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return context.l10n.daysAgo(diff.inDays);
    // Older than a week: a plain day/month/year date that reads the same in any language.
    final l = dt.toLocal();
    return '${l.day}/${l.month}/${l.year}';
  }

  // Circular loader centered in the space below the title.
  List<Widget> _skeletons() => [
        SizedBox(
          height: (_viewportHeight - 12 - 32 - 16 - 24).clamp(240.0, double.infinity),
          child: const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                  strokeWidth: 3.2, color: AppColors.primary),
            ),
          ),
        ),
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
            Text(context.l10n.noBusinessYet,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: AppText.title, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                context.l10n.listBusinessIntro,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: AppText.body,
                    height: 1.5,
                    color: cs.onSurface.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _push(const ListBusinessScreen()),
              style: AppButtons.primary,
              icon: const Icon(Icons.add_business_rounded),
              label: Text(context.l10n.listMyBusiness,
                  style: TextStyle(fontSize: AppText.body, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _errorState() => ErrorRetry.fromError(
        _errorMsg,
        title: ErrorRetry.isOfflineError(_errorMsg)
            ? null
            : context.l10n.couldntLoadBusiness,
        onRetry: () => _load(),
      );

  void _toggleBiz(String? id) =>
      setState(() => _expandedBizId = _expandedBizId == id ? null : id);

  Widget _businessCard(Map<String, dynamic> b) {
    final cs = Theme.of(context).colorScheme;
    final name = (b['business_name'] ?? 'Business').toString();
    final svcType = b['service_type']?.toString() ?? '';
    final locality = b['localities'] is Map
        ? (b['localities']['name']?.toString() ?? '')
        : '';
    final isApproved = b['is_approved'] == true;
    final bizId = b['id']?.toString();

    String formatSlug(String s) => s.isEmpty
        ? ''
        : s
            .split('_')
            .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');

    final meta = CategoryMeta.of(svcType);
    final leads = _leadsByVendor[bizId] ?? const [];
    final expanded = _expandedBizId == bizId;
    final subtitle = [formatSlug(svcType), locality]
        .where((s) => s.isNotEmpty)
        .join(' • ');
    final border = cs.onSurface.withValues(alpha: 0.10);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.solid(cs).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border),
      ),
      child: Column(children: [
        // Header: tap anywhere to open/close the leads.
        InkWell(
          onTap: () => _toggleBiz(bizId),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(meta.icon, color: meta.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: AppText.heading,
                              fontWeight: FontWeight.w400)),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.7),
                                fontSize: AppText.secondary)),
                      ],
                    ]),
              ),
              const SizedBox(width: 8),
              AppChip(isApproved ? context.l10n.statusActive : context.l10n.statusPending,
                  tone: isApproved ? ChipTone.success : ChipTone.warning),
            ]),
          ),
        ),

        // Actions: Edit and Leads, side by side (as before).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _push(ListBusinessScreen(existingVendor: b)),
                style: AppButtons.secondary,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(context.l10n.edit,
                    style: TextStyle(
                        fontSize: AppText.secondary,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _toggleBiz(bizId),
                style: AppButtons.secondary,
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18),
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(context.l10n.leads,
                      style: TextStyle(
                          fontSize: AppText.secondary,
                          fontWeight: FontWeight.bold)),
                  if (leads.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${leads.length}',
                          style: const TextStyle(
                              fontSize: AppText.caption,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  ],
                ]),
              ),
            ),
          ]),
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? _leadsPanel(bizId, leads)
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }

  Widget _leadsPanel(String? bizId, List<dynamic> leads) {
    final cs = Theme.of(context).colorScheme;
    final anyHidden =
        leads.any((l) => !_revealedPhones.containsKey(l['id'].toString()));

    // A faint tinted band instead of a hard divider line.
    return Container(
      color: cs.onSurface.withValues(alpha: 0.04),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (leads.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outline_rounded,
                  size: 32, color: cs.onSurface.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(context.l10n.noLeadsYet,
                  style: TextStyle(
                      fontSize: AppText.body, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(context.l10n.noLeadsHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: AppText.secondary,
                      color: cs.onSurface.withValues(alpha: 0.7))),
            ]),
          ),
        )
      else ...[
        if (anyHidden)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: cs.onSurface.withValues(alpha: 0.66)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(context.l10n.revealCostsCredit,
                    style: TextStyle(
                        fontSize: AppText.caption,
                        color: cs.onSurface.withValues(alpha: 0.7))),
              ),
            ]),
          ),
        // Each lead is its own card with a light border.
        for (var i = 0; i < leads.length; i++)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            decoration: BoxDecoration(
              color: AppColors.solid(cs),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
            ),
            child: _leadRow(leads[i], bizId),
          ),
        const SizedBox(height: 12),
      ],
    ]),
    );
  }

  /// One lead as a slim row: avatar, name, time, and a single action.
  Widget _leadRow(dynamic lead, String? bizId) {
    final cs = Theme.of(context).colorScheme;
    final id = lead['id'].toString();
    final leadName = lead['user_name']?.toString() ?? context.l10n.customer;
    final initial =
        leadName.trim().isEmpty ? '?' : leadName.trim()[0].toUpperCase();
    final dt = DateTime.tryParse(lead['created_at']?.toString() ?? '') ??
        DateTime.now();
    final isFresh = DateTime.now().difference(dt).inHours < 24;
    final phone = _revealedPhones[id];
    final busy = _revealing.contains(id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(initial,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: AppText.heading,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(leadName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: AppText.body,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.access_time_rounded,
                  size: 13,
                  color: isFresh
                      ? AppColors.primary
                      : cs.onSurface.withValues(alpha: 0.66)),
              const SizedBox(width: 4),
              Text(_timeAgo(dt),
                  style: TextStyle(
                      fontSize: AppText.secondary,
                      fontWeight: isFresh ? FontWeight.w600 : FontWeight.w400,
                      color: isFresh
                          ? AppColors.primary
                          : cs.onSurface.withValues(alpha: 0.7))),
            ]),
            if (phone != null) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _callPhone(phone),
                child: Text(_displayPhone(phone),
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: AppText.body,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4)),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 6),
        if (phone != null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              onPressed: () => _callPhone(phone),
              tooltip: context.l10n.call,
              icon: const Icon(Icons.call_rounded,
                  color: AppColors.primary, size: 22),
            ),
            IconButton(
              onPressed: () => _openWhatsApp(phone),
              tooltip: context.l10n.chatOnWhatsapp,
              icon: const FaIcon(FontAwesomeIcons.whatsapp,
                  color: Color(0xFF25D366), size: 25),
            ),
          ])
        else
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: busy ? null : () => _getLead(lead, bizId ?? ''),
              style: AppButtons.compact(AppButtons.primary),
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_open_rounded, size: 17),
              label: Text(context.l10n.getLead),
            ),
          ),
      ]),
    );
  }
}
