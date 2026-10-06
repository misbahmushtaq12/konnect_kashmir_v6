import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../static/contact_screen.dart';
import '../static/grevience_screen.dart';
import '../static/privacy_screen.dart';
import '../static/refund_screen.dart';
import '../static/terms_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'ad_credits_screen.dart';
import 'login_screen.dart';
import 'transaction_history_screen.dart';

/// Profile tab: edit profile, ad credits, transaction history, legal,
/// contact us and sign out.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  int? _credits;

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    final auth = context.read<AuthProvider>();
    int? c;
    try {
      c = await ApiService(token: auth.accessToken, userId: auth.userId)
          .getUserCredits();
    } catch (_) {}
    if (mounted) setState(() => _credits = c);
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _loadCredits();
  }

  // ── Edit profile ──────────────────────────────────────────────────────────
  Future<void> _editProfile() async {
    final auth = context.read<AuthProvider>();
    final ctrl = TextEditingController(text: auth.user?.name ?? '');
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 0, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit profile',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              Text('Full name',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Enter your name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Text('Phone: ${auth.user?.phoneNumber ?? ''}',
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.55))),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final name = ctrl.text.trim();
                        if (name.length < 2) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Please enter a valid name')));
                          return;
                        }
                        setSheet(() => saving = true);
                        final api = ApiService(
                            token: auth.accessToken, userId: auth.userId);
                        final r = await api.updateUserProfile(
                            auth.userId ?? '', {'full_name': name});
                        if (r['success'] == true) {
                          try {
                            await auth.refreshProfile();
                          } catch (_) {}
                        }
                        if (!ctx.mounted) return;
                        if (r['success'] == true) {
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Profile updated')));
                          }
                        } else {
                          setSheet(() => saving = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text("Couldn't save. Try again.")));
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white))
                    : const Text('Save changes'),
              ),
            ],
          ),
        );
      }),
    );
    ctrl.dispose();
  }

  // ── Legal ─────────────────────────────────────────────────────────────────
  void _showLegal() {
    Widget item(IconData icon, String title, Widget screen, BuildContext ctx) =>
        ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            Navigator.pop(ctx);
            _push(screen);
          },
        );

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Legal',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ),
          item(Icons.description_outlined, 'Terms of Service',
              const TermsScreen(), ctx),
          item(Icons.privacy_tip_outlined, 'Privacy Policy',
              const PrivacyScreen(), ctx),
          item(Icons.currency_rupee_rounded, 'Refund Policy',
              const RefundPolicy(), ctx),
          item(Icons.support_agent_outlined, 'Grievance Redressal',
              const GrievanceScreen(), ctx),
        ]),
      ),
    );
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    await context.read<AuthProvider>().logout();
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;
    final name = (auth.user?.name ?? '').trim();
    final size = MediaQuery.of(context).size;
    final hPad = size.width > 600 ? size.width * 0.12 : 20.0;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadCredits,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
              children: [
                const Text('Profile',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name.isEmpty ? 'Your name' : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(auth.user?.phoneNumber ?? '',
                                style: TextStyle(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.6))),
                          ]),
                    ),
                    if (_credits != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.stars_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text('$_credits',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 18),
                _group([
                  _row(Icons.person_outline_rounded, 'Edit profile',
                      onTap: _editProfile),
                  _row(Icons.stars_outlined, 'Ad credits',
                      onTap: () => _push(const AdCreditsScreen())),
                  _row(Icons.receipt_long_outlined, 'Transaction history',
                      onTap: () => _push(const TransactionHistoryScreen())),
                ]),
                const SizedBox(height: 14),
                _group([
                  _row(Icons.gavel_rounded, 'Legal', onTap: _showLegal),
                  _row(Icons.mail_outline_rounded, 'Contact us',
                      onTap: () => _push(const ContactScreen())),
                ]),
                const SizedBox(height: 14),
                _group([
                  _row(Icons.logout_rounded, 'Sign out',
                      color: AppColors.danger,
                      chevron: false,
                      onTap: _signOut),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _group(List<Widget> rows) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            Divider(
                indent: 58, color: cs.onSurface.withValues(alpha: 0.07)),
          rows[i],
        ]
      ]),
    );
  }

  Widget _row(IconData icon, String label,
      {required VoidCallback onTap, Color? color, bool chevron = true}) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(children: [
          Icon(icon, color: color ?? AppColors.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w600, color: c)),
          ),
          if (chevron)
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.35)),
        ]),
      ),
    );
  }
}
