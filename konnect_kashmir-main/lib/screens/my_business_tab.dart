import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
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
  Map<String, List<dynamic>> _leadsByVendor = {};
  bool _loading = true;
  String? _errorMsg;
  String? _expandedBizId;

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
        final bizList = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        
        final api = ApiService(token: auth.accessToken, userId: userId);
        final vendorIds = bizList.map((b) => b['id'].toString()).toList();
        
        Map<String, List<dynamic>> leadsByVendor = {};
        if (vendorIds.isNotEmpty) {
          final leadsResult = await api.getLeadNames(vendorIds);
          if (leadsResult['success'] == true && leadsResult['leads'] != null) {
            for (final lead in leadsResult['leads'] as List) {
              final vId = lead['vendor_id'].toString();
              leadsByVendor.putIfAbsent(vId, () => []).add(lead);
            }
          }
        }

        if (!mounted) return;
        setState(() {
          _businesses = bizList;
          _leadsByVendor = leadsByVendor;
          _errorMsg = null;
          _loading = false;
        });
        return;
      }
      
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Server returned status code: ${res.statusCode}\nResponse: ${res.body}';
        _loading = false;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString();
        _loading = false;
      });
    }
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
            ),
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
                    ElevatedButton.icon(
                      onPressed: () => _push(VendorDashboardScreen(initialBusinessId: bizId)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tealContainer,
                        foregroundColor: kTeal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
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
                  ]),
                );
              }),
          ],
        ]),
      ),
    );
  }
}
