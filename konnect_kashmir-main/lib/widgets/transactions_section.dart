import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/live_sync.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';
import 'transaction_card.dart';

/// Credit transactions straight from the backend, for the Profile screen. It
/// shows only the latest 2 at first; "Show more" loads further ones, a page at
/// a time. It loads on its own, so it never holds up the rest of the screen,
/// and it refreshes by itself when the backend reports a new transaction.
class TransactionsSection extends StatefulWidget {
  const TransactionsSection({super.key});

  @override
  State<TransactionsSection> createState() => TransactionsSectionState();
}

class TransactionsSectionState extends State<TransactionsSection> {
  static const int _first = 2;
  static const int _step = 20;

  List<Map<String, dynamic>> _rows = [];
  int _count = _first; // how many are shown
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  int? _tick;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tick = context.watch<LiveSync>().transactionsTick;
    if (_tick != null && tick != _tick) _load();
    _tick = tick;
  }

  /// Reloads the list (used by pull-to-refresh).
  Future<void> reload() => _load();

  /// Newest first. Asks for one more than is shown, to know if there are more.
  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    try {
      final rows = await ApiService(token: auth.accessToken, userId: auth.userId)
          .getUserTransactions(limit: _count + 1);
      if (!mounted) return;
      setState(() {
        _hasMore = rows.length > _count;
        _rows = rows.take(_count).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showMore() async {
    if (_loadingMore) return;
    setState(() {
      _loadingMore = true;
      _count += _step;
    });
    await _load();
    if (mounted) setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(title: context.l10n.transactionHistory),
      const SizedBox(height: 10),
      if (_loading)
        for (var i = 0; i < 2; i++) ...[
          const Skeleton(height: 68, radius: AppRadius.md),
          const SizedBox(height: 10),
        ]
      else if (_rows.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: Text(context.l10n.noTransactionsYet,
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
          ),
        )
      else ...[
        for (final r in _rows) ...[
          TransactionCard(r),
          const SizedBox(height: 10),
        ],
        if (_hasMore)
          OutlinedButton.icon(
            onPressed: _loadingMore ? null : _showMore,
            icon: _loadingMore
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.expand_more_rounded),
            label: Text(context.l10n.showMore),
          ),
      ],
    ]);
  }
}
