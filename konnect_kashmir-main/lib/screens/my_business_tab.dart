import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/category_meta.dart';
import 'vendor_dashboard.dart';
import 'vendor_screen.dart';

/// My Business tab: shows the user's registered businesses, or a
/// "List my business" prompt if they have none.
class MyBusinessTab extends StatefulWidget {
  const MyBusinessTab({super.key});

  @override
  State<MyBusinessTab> createState() => _MyBusinessTabState();
}

class _MyBusinessTabState extends State<MyBusinessTab> {
  static const String _baseUrl = 'https://fmmpsqnpezjofsluirrv.supabase.co';

  List<Map<String, dynamic>> _businesses = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = true);
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
        setState(() {
          _businesses = List<Map<String, dynamic>>.from(jsonDecode(res.body));
          _failed = false;
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _failed = true;
      _loading = false;
    });
  }

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
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
              children: [
                const Text('My Business',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                if (_loading)
                  ..._skeletons()
                else if (_failed)
                  _errorState()
                else if (_businesses.isEmpty)
                  _emptyState()
                else ...[
                  for (final b in _businesses) _businessCard(b),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => _push(const ListBusinessScreen()),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add another business'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _skeletons() => [
        for (var i = 0; i < 2; i++) ...[
          const Skeleton(height: 170, radius: AppRadius.lg),
          const SizedBox(height: 14),
        ]
      ];

  Widget _emptyState() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.storefront_rounded,
              size: 48, color: AppColors.accent),
        ),
        const SizedBox(height: 22),
        const Text("You haven't listed a business yet",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'List your services and get discovered by customers across Kashmir.',
          textAlign: TextAlign.center,
          style: TextStyle(
              height: 1.4, color: cs.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _push(const ListBusinessScreen()),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              minimumSize: const Size(220, 52)),
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('List my business'),
        ),
      ]),
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
    final slug = b['service_type']?.toString();
    final meta = CategoryMeta.of(slug);
    final locality = b['localities'] is Map
        ? (b['localities']['name']?.toString() ?? '')
        : '';
    final approved = b['is_approved'] == true;
    final verified = b['is_verified'] == true;
    final logo = b['logo_url']?.toString();
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    final initialsWidget = Center(
      child: Text(initials,
          style: TextStyle(
              color: meta.color, fontSize: 18, fontWeight: FontWeight.w800)),
    );

    Widget chip(String text, Color color, IconData icon) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(text,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ]),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 56,
              height: 56,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: (logo != null && logo.isNotEmpty)
                  ? Image.network(logo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => initialsWidget)
                  : initialsWidget,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (slug != null && slug.isNotEmpty)
                          slug
                              .split('_')
                              .map((w) => w.isEmpty
                                  ? w
                                  : '${w[0].toUpperCase()}${w.substring(1)}')
                              .join(' '),
                        if (locality.isNotEmpty) locality,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: [
            approved
                ? chip('Live', AppColors.success, Icons.check_circle_rounded)
                : chip('Pending approval', AppColors.accent,
                    Icons.hourglass_top_rounded),
            if (verified)
              chip('Verified', const Color(0xFF378ADD), Icons.verified),
          ]),
          if (!approved) ...[
            const SizedBox(height: 10),
            Text(
              'Our team is reviewing your listing. It will appear to customers once approved.',
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _push(ListBusinessScreen(existingVendor: b)),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _push(const VendorDashboardScreen()),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
                icon: const Icon(Icons.people_alt_outlined, size: 18),
                label: const Text('Leads'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
