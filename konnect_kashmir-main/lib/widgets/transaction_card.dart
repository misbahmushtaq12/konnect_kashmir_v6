import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';

/// One credit transaction row from the backend (`credit_transactions`): what it
/// was, the credits added/deducted, date and time, a short reference, and the
/// status when the backend sends one.
class TransactionCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const TransactionCard(this.row, {super.key});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  ({String title, String subtitle, IconData icon, Color color}) _describe(
      BuildContext context, String type, int amount) {
    switch (type) {
      case 'unlock_contact':
        return (
          title: context.l10n.txnContactUnlocked,
          subtitle: context.l10n.txnVendorRevealed,
          icon: Icons.lock_open_rounded,
          color: AppColors.accent
        );
      case 'initial_bonus':
        return (
          title: context.l10n.txnWelcomeBonus,
          subtitle: context.l10n.txnNewAccountReward,
          icon: Icons.card_giftcard_rounded,
          color: AppColors.success
        );
      case 'referral_bonus':
        return (
          title: context.l10n.txnReferralBonus,
          subtitle: context.l10n.txnReferralReward,
          icon: Icons.group_add_rounded,
          color: AppColors.success
        );
      case 'purchase':
        return (
          title: context.l10n.txnCreditPurchase,
          subtitle: context.l10n.txnCreditsAdded,
          icon: Icons.shopping_bag_rounded,
          color: AppColors.primary
        );
      case 'refund':
        return (
          title: context.l10n.txnRefund,
          subtitle: context.l10n.txnCreditsRefunded,
          icon: Icons.undo_rounded,
          color: AppColors.primary
        );
      default:
        return amount > 0
            ? (
                title: context.l10n.txnAdReward,
                subtitle: context.l10n.txnWatchedAd,
                icon: Icons.play_circle_rounded,
                color: AppColors.success
              )
            : (
                title: context.l10n.txnCreditsSpent,
                subtitle: context.l10n.txnCreditUsed,
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

  /// Short reference taken from the transaction's id (e.g. "3F9A12BC").
  String? _ref(dynamic id) {
    final raw = id?.toString().replaceAll('-', '');
    if (raw == null || raw.isEmpty) return null;
    return (raw.length > 8 ? raw.substring(0, 8) : raw).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final amount = (row['amount'] as num?)?.toInt() ?? 0;
    final d = _describe(context, row['transaction_type']?.toString() ?? '', amount);
    final positive = amount > 0;
    final ref = _ref(row['id']);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: AppText.body)),
            const SizedBox(height: 2),
            Text(_fmt(row['created_at']?.toString()),
                style: TextStyle(
                    fontSize: AppText.caption,
                    color: cs.onSurface.withValues(alpha: 0.55))),
            if (ref != null)
              Text(
                  '${context.l10n.txnReference(ref)}'
                  '${row['status'] != null ? '  ·  ${context.l10n.txnStatusIs(row['status'].toString())}' : ''}',
                  style: TextStyle(
                      fontSize: AppText.caption,
                      color: cs.onSurface.withValues(alpha: 0.55))),
          ]),
        ),
        Text(
          '${positive ? '+' : ''}$amount',
          style: TextStyle(
            fontSize: AppText.heading,
            fontWeight: FontWeight.w800,
            color: positive ? AppColors.success : AppColors.danger,
          ),
        ),
      ]),
    );
  }
}
