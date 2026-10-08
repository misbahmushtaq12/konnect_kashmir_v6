import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/live_sync.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/transaction_card.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  int? _tick;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // A new transaction (reported by the backend) refreshes the list at once.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tick = context.watch<LiveSync>().transactionsTick;
    if (_tick != null && tick != _tick) _load();
    _tick = tick;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.transactionHistory)),
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
                    Center(
                        child: Text(context.l10n.noTransactionsYet,
                            style: TextStyle(
                                fontSize: AppText.heading, fontWeight: FontWeight.w700))),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                          context.l10n.noTransactionsHint,
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.6))),
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => TransactionCard(_rows[i]),
                  ),
      ),
    );
  }
}
