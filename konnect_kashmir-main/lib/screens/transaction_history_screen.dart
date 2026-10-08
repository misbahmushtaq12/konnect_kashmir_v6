import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final api = ApiService(token: auth.accessToken, userId: auth.userId);
    List<Map<String, dynamic>> rows = [];
    try {
      rows = await api.getUserTransactions(limit: 100);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  ({String title, String subtitle, IconData icon, Color color}) _describe(
      String type, int amount) {
    switch (type) {
      case 'unlock_contact':
        return (
          title: 'Contact unlocked',
          subtitle: 'Vendor contact revealed',
          icon: Icons.lock_open_rounded,
          color: AppColors.accent
        );
      case 'initial_bonus':
        return (
          title: 'Welcome bonus',
          subtitle: 'New account reward',
          icon: Icons.card_giftcard_rounded,
          color: AppColors.success
        );
      case 'referral_bonus':
        return (
          title: 'Referral bonus',
          subtitle: 'Referral credit reward',
          icon: Icons.group_add_rounded,
          color: AppColors.success
        );
      case 'purchase':
        return (
          title: 'Credit purchase',
          subtitle: 'Credits added',
          icon: Icons.shopping_bag_rounded,
          color: AppColors.primary
        );
      case 'refund':
        return (
          title: 'Refund',
          subtitle: 'Credits refunded',
          icon: Icons.undo_rounded,
          color: AppColors.primary
        );
      default:
        return amount > 0
            ? (
                title: 'Ad reward',
                subtitle: 'Watched an ad',
                icon: Icons.play_circle_rounded,
                color: AppColors.success
              )
            : (
                title: 'Credits spent',
                subtitle: 'Credit used',
                icon: Icons.remove_circle_outline_rounded,
                color: AppColors.accent
              );
    }
  }

  String _fmt(String? iso) {
    final dt = DateTime.tryParse(iso ?? '')?.toLocal();
    if (dt == null) return '';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}, $h:$m ${dt.hour < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction history')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _loading
            ? ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    const Skeleton(height: 68, radius: AppRadius.md),
                    const SizedBox(height: 10),
                  ]
                ],
              )
            : _rows.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 120),
                    Icon(Icons.receipt_long_outlined,
                        size: 56, color: cs.onSurface.withValues(alpha: 0.35)),
                    const SizedBox(height: 14),
                    const Center(
                        child: Text('No transactions yet',
                            style: TextStyle(
                                fontSize: AppText.heading, fontWeight: FontWeight.w700))),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                          'Credits you earn or spend will show up here.',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.6))),
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final r = _rows[i];
                      final amount = (r['amount'] as num?)?.toInt() ?? 0;
                      final d = _describe(
                          r['transaction_type']?.toString() ?? '', amount);
                      final positive = amount > 0;
                      return AppCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: d.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(d.icon, color: d.color, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: AppText.body)),
                                  const SizedBox(height: 2),
                                  Text(_fmt(r['created_at']?.toString()),
                                      style: TextStyle(
                                          fontSize: AppText.caption,
                                          color: cs.onSurface
                                              .withValues(alpha: 0.55))),
                                ]),
                          ),
                          Text(
                            '${positive ? '+' : ''}$amount',
                            style: TextStyle(
                              fontSize: AppText.heading,
                              fontWeight: FontWeight.w800,
                              color: positive
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
      ),
    );
  }
}
