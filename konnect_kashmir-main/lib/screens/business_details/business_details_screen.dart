import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../l10n/l10n.dart';
import '../../services/business_share.dart';
import '../../services/map_link.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/category_meta.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/share_business_button.dart';
import 'business_details_host.dart';

/// The route to a business's details. It is the app's normal page route, so it
/// has the app's background and the same page transition as every other screen.
Route<void> businessDetailsRoute({
  required BusinessDetailsHost host,
  String? vendorId,
  Map<String, dynamic>? vendor,
}) {
  return MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/business'),
    builder: (_) =>
        BusinessDetailsScreen(host: host, vendorId: vendorId, vendor: vendor),
  );
}

/// The price range as a label ("₹500 – 1,500"), or null when the business has none.
String? businessPriceLabel(Map<String, dynamic> v) {
  double? asNum(dynamic x) =>
      x is num ? x.toDouble() : double.tryParse('${x ?? ''}');
  final lo = asNum(v['min_price']);
  final hi = asNum(v['max_price']);
  if ((lo ?? 0) <= 0 && (hi ?? 0) <= 0) return null;
  // Indian digit grouping: 123456 -> 1,23,456
  String money(double n) {
    final s = n.round().toString();
    if (s.length <= 3) return s;
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '${parts.join(',')},${s.substring(s.length - 3)}';
  }

  if (lo != null && hi != null && lo > 0 && hi > 0 && lo != hi) {
    return '₹${money(lo)} – ${money(hi)}';
  }
  return '₹${money(((lo ?? 0) > 0 ? lo : hi)!)}';
}

/// Every detail of one business, shown from the card's data at once and filled in
/// as the full record arrives. Everything shown is real data: a field that is
/// empty is simply not drawn.
class BusinessDetailsScreen extends StatefulWidget {
  final BusinessDetailsHost host;

  /// The business's id; taken from [vendor] when that is given.
  final String? vendorId;

  /// What the card already knew (shown immediately). Null when opened from a link.
  final Map<String, dynamic>? vendor;

  const BusinessDetailsScreen({
    super.key,
    required this.host,
    this.vendorId,
    this.vendor,
  }) : assert(vendorId != null || vendor != null);

  @override
  State<BusinessDetailsScreen> createState() => _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends State<BusinessDetailsScreen> {
  late final String _id = (widget.vendorId ?? widget.vendor!['id']).toString();
  BusinessDetailsHost get _host => widget.host;

  Map<String, dynamic>? _fetched;
  bool _loading = true; // the full record is on its way
  bool _notFound = false;
  String? _error;

  List<String> _categorySlugs = const [];
  List<Map<String, dynamic>> _reviews = const [];
  bool _allReviews = false;

  /// The card's data with the full record laid over it.
  Map<String, dynamic>? get _v {
    final a = widget.vendor;
    final b = _fetched;
    if (a == null && b == null) return null;
    return {...?a, ...?b};
  }

  // The name is in the page itself; it joins the app bar once it has scrolled away.
  final ScrollController _scroll = ScrollController();
  bool _titleShown = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.hasClients && _scroll.offset > 220;
      if (show != _titleShown) setState(() => _titleShown = show);
    });
    // Known already (the list asked for them): shown in the very first frame.
    _categorySlugs = _host.source.cachedCategorySlugs(_id) ?? const [];
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Whether the card already carries everything the screen shows, so the full
  /// record does not have to be asked for again.
  static bool _hasFullRecord(Map<String, dynamic> v) => const [
    'gallery_urls',
    'working_hours',
    'services_offered',
    'other_service_description',
  ].every(v.containsKey);

  /// Asks for what is missing. Each answer is shown the moment it arrives; the
  /// screen never waits for the slowest request before showing the others.
  Future<void> _load({bool force = false}) async {
    final card = widget.vendor;
    final needDetails = force || card == null || !_hasFullRecord(card);
    final needCategories =
        force || _host.source.cachedCategorySlugs(_id) == null;
    setState(() {
      _loading = needDetails && card == null;
      _error = null;
      _notFound = false;
    });
    await Future.wait<void>([
      if (needDetails)
        _host.source
            .details(_id)
            .then<void>(
              (d) {
                if (!mounted) return;
                setState(() {
                  _loading = false;
                  if (d != null) {
                    _fetched = d;
                  } else {
                    // Asked fine, nothing there: gone, unless the card still has it.
                    _notFound = card == null;
                  }
                });
              },
              onError: (Object e) {
                if (!mounted) return;
                // Could not ask: keep what the card gave; with nothing, offer a retry.
                setState(() {
                  _loading = false;
                  _error = card == null ? e.toString() : null;
                });
              },
            ),
      if (needCategories)
        _host.source.categorySlugs(_id).then<void>((c) {
          if (mounted) setState(() => _categorySlugs = c);
        }, onError: (Object _) {}),
      _host.source.reviews(_id).then<void>((r) {
        if (mounted) setState(() => _reviews = r);
      }, onError: (Object _) {}),
    ]);
  }

  // ── Small readers over the record ──────────────────────────────────────────

  static String _text(Object? x) => x?.toString().trim() ?? '';

  static List<String> _urls(Map<String, dynamic> v) {
    final out = <String>[];
    void add(Object? x) {
      final s = _text(x);
      final u = Uri.tryParse(s);
      if (s.isNotEmpty &&
          u != null &&
          (u.scheme == 'http' || u.scheme == 'https') &&
          !out.contains(s)) {
        out.add(s);
      }
    }

    add(v['logo_url']);
    final g = v['gallery_urls'];
    if (g is List) g.forEach(add);
    return out;
  }

  double? get _average {
    final r = [
      for (final x in _reviews)
        if (x['rating'] is num) (x['rating'] as num).toDouble(),
    ];
    if (r.isEmpty) return null;
    return (r.reduce((a, b) => a + b) / r.length * 10).round() / 10;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _host.changes,
      builder: (context, _) {
        final v = _v;
        final name = v == null ? '' : _text(v['business_name']);
        return Scaffold(
          appBar: AppBar(
            title: AnimatedOpacity(
              opacity: _titleShown ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            actions: [
              if (v != null)
                ShareBusinessButton(data: _shareData(context, v), size: 22),
              const SizedBox(width: 4),
            ],
          ),
          body: _body(context, v),
          bottomNavigationBar: v == null ? null : _actionBar(context, v),
        );
      },
    );
  }

  /// What is shared: the address and number only once the contact is unlocked.
  BusinessShareData _shareData(BuildContext context, Map<String, dynamic> v) {
    final unlocked = _host.isUnlocked(_id);
    return BusinessShareData(
      id: _id,
      name: _text(v['business_name']),
      category: _host.categoryLabel(context, _text(v['service_type'])),
      locality: _locality(v),
      address: unlocked ? MapLink.split(_text(v['address'])).text : '',
      phone: unlocked ? _host.phoneOf(_id, v) : '',
    );
  }

  static String _locality(Map<String, dynamic> v) => v['localities'] is Map
      ? _text((v['localities'] as Map)['name'])
      : _text(v['locality']);

  Widget _body(BuildContext context, Map<String, dynamic>? v) {
    if (v == null) {
      if (_loading) return const _DetailsSkeleton();
      if (_notFound) {
        return _Message(
          icon: Icons.storefront_outlined,
          text: context.l10n.detailsNotFound,
        );
      }
      return ErrorRetry.fromError(_error, onRetry: _load);
    }

    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.66);
    final slug = _text(v['service_type']);
    final meta = CategoryMeta.of(slug, name: slug);
    final category = _host.categoryLabel(context, slug);
    final locality = _locality(v);
    final unlocked = _host.isUnlocked(_id);
    final phone = unlocked ? _host.phoneOf(_id, v) : '';
    if (unlocked && phone.isEmpty && _host.isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _host.resolvePhone(_id);
      });
    }
    final rawAddress = _text(v['address']);
    final address = MapLink.split(rawAddress).text;
    final mapUri = unlocked && (rawAddress.isNotEmpty || locality.isNotEmpty)
        ? MapLink.target(
            address: rawAddress,
            locality: locality,
            businessName: _text(v['business_name']),
          )
        : null;

    final desc = _text(v['description']);
    final hours = _text(v['working_hours']);
    final services = _services(context, v, slug);
    final price = businessPriceLabel(v);
    final years = v['experience_years'] is num
        ? (v['experience_years'] as num).round()
        : int.tryParse('${v['experience_years'] ?? ''}');
    final avg = _average;

    final facts = <Widget>[
      if (price != null)
        AppChip(price, icon: Icons.currency_rupee_rounded, compact: true),
      if (years != null && years > 0)
        AppChip(
          context.l10n.yrs('$years'),
          icon: Icons.work_outline_rounded,
          compact: true,
        ),
      if (v['provides_home_service'] == true)
        AppChip(
          context.l10n.homeVisit,
          icon: Icons.home_outlined,
          compact: true,
        ),
      if (v['accepts_online_payment'] == true)
        AppChip(
          context.l10n.onlinePay,
          icon: Icons.account_balance_wallet_outlined,
          compact: true,
        ),
    ];

    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _Gallery(urls: _urls(v), meta: meta, name: _text(v['business_name'])),
          const SizedBox(height: 16),
          // Name and the quick facts.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _text(v['business_name']),
                  style: const TextStyle(
                    fontSize: AppText.titleLg - 2,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
              if (v['is_verified'] == true) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: AppChip(
                    context.l10n.detailsVerified,
                    icon: Icons.verified,
                    tone: ChipTone.success,
                    compact: true,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (category.isNotEmpty)
                AppChip(category, icon: meta.icon, tone: ChipTone.primary),
              if (locality.isNotEmpty)
                AppChip(locality, icon: Icons.location_on_outlined),
              if (avg != null)
                AppChip(
                  '$avg  ·  ${context.l10n.detailsReviewCount(_reviews.length)}',
                  icon: Icons.star_rounded,
                  tone: ChipTone.warning,
                ),
            ],
          ),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: facts),
          ],
          if (desc.isNotEmpty)
            _Section(
              title: context.l10n.detailsAbout,
              child: Text(
                desc,
                style: TextStyle(
                  fontSize: AppText.body,
                  height: 1.5,
                  color: cs.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ),
          if (services.isNotEmpty)
            _Section(
              title: context.l10n.detailsServices,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final s in services) AppChip(s)],
              ),
            ),
          if (hours.isNotEmpty)
            _Section(
              title: context.l10n.detailsWorkingHours,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hours,
                      style: const TextStyle(
                        fontSize: AppText.body,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _Section(
            title: context.l10n.detailsContactLocation,
            child: _contactCard(
              context,
              unlocked,
              phone,
              address,
              locality,
              mapUri,
            ),
          ),
          _Section(
            title: context.l10n.detailsReviews,
            child: _reviewsBlock(context, unlocked),
          ),
          if (unlocked && _host.isSignedIn)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _host.report(v),
                icon: Icon(Icons.flag_outlined, size: 18, color: muted),
                label: Text(
                  context.l10n.detailsReport,
                  style: TextStyle(color: muted, fontSize: AppText.secondary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The other categories the business is listed in and the services it offers,
  /// without repeating its own category.
  List<String> _services(
    BuildContext context,
    Map<String, dynamic> v,
    String ownSlug,
  ) {
    final seen = <String>{
      _host.categoryLabel(context, ownSlug).toLowerCase(),
      ownSlug.toLowerCase(),
    };
    final out = <String>[];
    void add(String s) {
      final t = s.trim();
      if (t.isNotEmpty && seen.add(t.toLowerCase())) out.add(t);
    }

    for (final c in _categorySlugs) {
      if (c != ownSlug) add(_host.categoryLabel(context, c));
    }
    final offered = v['services_offered'];
    if (offered is List) {
      for (final s in offered) {
        add(_text(s));
      }
    }
    add(_text(v['other_service_description']));
    return out;
  }

  static Widget _icon(IconData i) =>
      Icon(i, size: 20, color: AppColors.primary);

  Widget _contactCard(
    BuildContext context,
    bool unlocked,
    String phone,
    String address,
    String locality,
    Uri? mapUri,
  ) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.66);
    Widget row(Widget icon, String label, String value, {Widget? trailing}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: AppText.caption, color: muted),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: AppText.body,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        );

    final rows = <Widget>[];
    if (unlocked) {
      if (phone.isNotEmpty) {
        rows.add(
          row(
            _icon(Icons.call_rounded),
            context.l10n.detailsPhone,
            '+91 $phone',
            trailing: IconButton(
              onPressed: () => _host.call(phone, _id),
              tooltip: context.l10n.call,
              icon: const Icon(Icons.call_rounded, color: AppColors.primary),
            ),
          ),
        );
        rows.add(
          row(
            const FaIcon(
              FontAwesomeIcons.whatsapp,
              size: 20,
              color: Color(0xFF25D366),
            ),
            context.l10n.whatsapp,
            '+91 $phone',
            trailing: IconButton(
              onPressed: () => _host.whatsApp(phone, _id),
              tooltip: context.l10n.whatsapp,
              icon: const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Color(0xFF25D366),
                size: 24,
              ),
            ),
          ),
        );
      } else {
        rows.add(
          row(
            _icon(Icons.call_rounded),
            context.l10n.detailsPhone,
            context.l10n.phoneNotAvailable,
          ),
        );
      }
      if (address.isNotEmpty || locality.isNotEmpty) {
        rows.add(
          row(
            _icon(Icons.location_on_outlined),
            address.isNotEmpty
                ? context.l10n.detailsAddress
                : context.l10n.detailsArea,
            address.isNotEmpty ? address : locality,
            trailing: mapUri == null
                ? null
                : IconButton(
                    onPressed: () => _host.openMap(mapUri),
                    tooltip: context.l10n.detailsDirections,
                    icon: const Icon(
                      Icons.directions_rounded,
                      color: AppColors.primary,
                    ),
                  ),
          ),
        );
      }
    } else {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, size: 20, color: muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.detailsLocked,
                  style: TextStyle(
                    fontSize: AppText.body,
                    color: muted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (locality.isNotEmpty) {
        rows.add(
          row(
            _icon(Icons.location_on_outlined),
            context.l10n.detailsArea,
            locality,
          ),
        );
      }
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.07)),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _reviewsBlock(BuildContext context, bool unlocked) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.66);
    final shown = _allReviews ? _reviews : _reviews.take(3).toList();
    final locale = Localizations.localeOf(context).toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_reviews.isEmpty)
          Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 18, color: muted),
              const SizedBox(width: 8),
              Text(
                context.l10n.detailsNoReviews,
                style: TextStyle(color: muted, fontSize: AppText.body),
              ),
            ],
          )
        else ...[
          for (final r in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < 5; i++)
                          Icon(
                            i < ((r['rating'] as num?) ?? 0)
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 18,
                            color: AppColors.warning,
                          ),
                        const Spacer(),
                        Text(
                          _date(r['created_at'], locale),
                          style: TextStyle(
                            fontSize: AppText.caption,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    if (_text(r['review_text']).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _text(r['review_text']),
                        style: const TextStyle(
                          fontSize: AppText.body,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (_reviews.length > 3)
            TextButton(
              onPressed: () => setState(() => _allReviews = !_allReviews),
              child: Text(
                _allReviews
                    ? context.l10n.detailsShowFewerReviews
                    : context.l10n.detailsShowAllReviews(_reviews.length),
              ),
            ),
        ],
        // Only someone who has unlocked the contact can review it (the same rule
        // as the cards).
        if (unlocked && _host.isSignedIn) ...[
          const SizedBox(height: 12),
          _host.reviewForm(_id),
        ],
      ],
    );
  }

  static String _date(Object? iso, String locale) {
    final d = DateTime.tryParse(_text(iso));
    return d == null ? '' : DateFormat.yMMMd(locale).format(d.toLocal());
  }

  // ── The bottom bar: the actions that matter ────────────────────────────────

  Widget _actionBar(BuildContext context, Map<String, dynamic> v) {
    final cs = Theme.of(context).colorScheme;
    final unlocked = _host.isUnlocked(_id);
    final phone = unlocked ? _host.phoneOf(_id, v) : '';
    final rawAddress = _text(v['address']);
    final mapUri =
        unlocked && (rawAddress.isNotEmpty || _locality(v).isNotEmpty)
        ? MapLink.target(
            address: rawAddress,
            locality: _locality(v),
            businessName: _text(v['business_name']),
          )
        : null;

    Widget content;
    if (_host.isUnlocking(_id)) {
      content = const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    } else if (!_host.isSignedIn) {
      content = _wide(
        icon: Icons.lock_outline_rounded,
        label: context.l10n.signInToUnlock,
        onPressed: _host.signIn,
      );
    } else if (!unlocked) {
      content = _wide(
        icon: Icons.lock_open_rounded,
        label: _host.credits > 0
            ? context.l10n.unlockContact
            : context.l10n.watchAdToUnlock,
        onPressed: () => _host.unlock(v),
      );
    } else if (phone.isEmpty && mapUri == null) {
      return const SizedBox.shrink(); // nothing to offer
    } else {
      content = Row(
        children: [
          if (phone.isNotEmpty)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _host.call(phone, _id),
                style: AppButtons.block(AppButtons.primary),
                icon: const Icon(Icons.call_rounded, size: 20),
                label: Text(
                  context.l10n.callNow,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: AppText.body,
                  ),
                ),
              ),
            ),
          if (phone.isNotEmpty) ...[
            const SizedBox(width: 10),
            _square(
              tooltip: context.l10n.whatsapp,
              onPressed: () => _host.whatsApp(phone, _id),
              child: const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Color(0xFF25D366),
                size: 24,
              ),
            ),
          ],
          if (mapUri != null) ...[
            const SizedBox(width: 10),
            if (phone.isEmpty)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _host.openMap(mapUri),
                  style: AppButtons.block(AppButtons.primary),
                  icon: const Icon(Icons.directions_rounded, size: 20),
                  label: Text(
                    context.l10n.detailsDirections,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              )
            else
              _square(
                tooltip: context.l10n.detailsDirections,
                onPressed: () => _host.openMap(mapUri),
                child: const Icon(
                  Icons.directions_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
          ],
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: cs.onSurface.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: content,
        ),
      ),
    );
  }

  Widget _wide({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      style: AppButtons.block(AppButtons.primary),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: AppText.body,
        ),
      ),
    ),
  );

  Widget _square({
    required String tooltip,
    required VoidCallback onPressed,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onPressed,
          child: SizedBox(width: 52, height: 52, child: Center(child: child)),
        ),
      ),
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: AppText.heading,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: muted),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppText.body,
                color: muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
    children: const [
      Skeleton(height: 200, radius: 20),
      SizedBox(height: 16),
      Skeleton(height: 28, width: 220, radius: 8),
      SizedBox(height: 12),
      Skeleton(height: 28, width: 160, radius: 14),
      SizedBox(height: 24),
      Skeleton(height: 16, radius: 6),
      SizedBox(height: 8),
      Skeleton(height: 16, radius: 6),
      SizedBox(height: 8),
      Skeleton(height: 16, width: 200, radius: 6),
    ],
  );
}

/// The business's photos, swipeable; a category picture when it has none.
class _Gallery extends StatefulWidget {
  final List<String> urls;
  final CategoryMeta meta;
  final String name;
  const _Gallery({required this.urls, required this.meta, required this.name});

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final PageController _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  /// The first letters of the first two words of the name ("Ajaz Koul" -> "AK"),
  /// the same as on the business card.
  String get _initials => widget.name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => String.fromCharCode(w.runes.first).toUpperCase())
      .join();

  Widget _placeholder() {
    final c = widget.meta.color;
    final initials = _initials;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.withValues(alpha: 0.28), c.withValues(alpha: 0.08)],
        ),
      ),
      child: Center(
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.withValues(alpha: 0.16),
          ),
          alignment: Alignment.center,
          child: initials.isEmpty
              ? Icon(widget.meta.icon, size: 42, color: c)
              : Text(
                  initials,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: c,
                    height: 1,
                  ),
                ),
        ),
      ),
    );
  }

  void _open(int i) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          _PhotoViewer(urls: widget.urls, start: i, name: widget.name),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final cs = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg + 4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (urls.isEmpty)
              _placeholder()
            else
              PageView.builder(
                controller: _page,
                itemCount: urls.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => Semantics(
                  image: true,
                  button: true,
                  label: context.l10n.detailsPhotoLabel(i + 1, urls.length),
                  child: GestureDetector(
                    onTap: () => _open(i),
                    child: Image.network(
                      urls[i],
                      fit: BoxFit.cover,
                      cacheWidth: 1000,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : ColoredBox(
                              color: widget.meta.color.withValues(alpha: 0.08),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                ),
                              ),
                            ),
                      errorBuilder: (_, __, ___) => _placeholder(),
                    ),
                  ),
                ),
              ),
            if (urls.length > 1) ...[
              Positioned(
                top: 10,
                right: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      '${_index + 1}/${urls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppText.caption,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < urls.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? Colors.white
                              : cs.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int start;
  final String name;
  const _PhotoViewer({
    required this.urls,
    required this.start,
    required this.name,
  });

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _page = PageController(initialPage: widget.start);
  late int _index = widget.start;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(
        '${_index + 1}/${widget.urls.length}',
        style: const TextStyle(fontSize: AppText.body),
      ),
    ),
    body: PageView.builder(
      controller: _page,
      itemCount: widget.urls.length,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (_, i) => InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: Image.network(
            widget.urls[i],
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    ),
  );
}
