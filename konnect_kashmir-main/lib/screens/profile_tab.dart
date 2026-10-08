import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../widgets/app_overlays.dart';
import '../widgets/app_snack.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import 'language_screen.dart';
import '../widgets/theme_reveal.dart';
import '../services/api_service.dart';
import '../static/contact_screen.dart';
import '../static/grevience_screen.dart';
import '../static/privacy_screen.dart';
import '../static/refund_screen.dart';
import '../static/terms_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_widgets.dart';
import 'ad_credits_screen.dart';
import 'login_screen.dart';
import 'transaction_history_screen.dart';

/// Profile tab: edit profile, ad credits, transaction history, legal,
/// contact us and sign out.
class ProfileTab extends StatefulWidget {
  /// False while another bottom-nav tab is showing; returning refreshes credits
  /// (they change elsewhere, e.g. after revealing a lead).
  final bool isActive;
  const ProfileTab({super.key, this.isActive = true});

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

  @override
  void didUpdateWidget(ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _loadCredits();
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

    await showAppSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 0, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.editProfile,
                  style: TextStyle(fontSize: AppText.title, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              Text(context.l10n.fullName,
                  style: TextStyle(
                      fontSize: AppText.secondary,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.7))),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: context.l10n.enterYourName,
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Text(context.l10n.phoneLabel(auth.user?.phoneNumber ?? ''),
                  style: TextStyle(
                      fontSize: AppText.secondary,
                      color: cs.onSurface.withValues(alpha: 0.7))),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final name = ctrl.text.trim();
                        if (name.length < 2) {
                          showAppSnack(ctx, context.l10n.validNameError, type: SnackType.info);
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
                            showAppSnack(context, context.l10n.profileUpdated, type: SnackType.info);
                          }
                        } else {
                          setSheet(() => saving = false);
                          showAppSnack(ctx, context.l10n.couldntSave, type: SnackType.info);
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white))
                    : Text(context.l10n.saveChanges),
              ),
            ],
          ),
        );
      }));
    // The sheet is still animating out here; dispose once it is fully gone.
    Future.delayed(const Duration(milliseconds: 500), ctrl.dispose);
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

    showAppSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(context.l10n.legal,
                  style: TextStyle(fontSize: AppText.title, fontWeight: FontWeight.w800)),
            ),
          ),
          item(Icons.description_outlined, context.l10n.termsOfService,
              const TermsScreen(), ctx),
          item(Icons.privacy_tip_outlined, context.l10n.privacyPolicy,
              const PrivacyScreen(), ctx),
          item(Icons.currency_rupee_rounded, context.l10n.refundPolicy,
              const RefundPolicy(), ctx),
          item(Icons.support_agent_outlined, context.l10n.grievanceRedressal,
              const GrievanceScreen(), ctx),
        ]),
      ));
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  Future<void> _signOut() async {
    final ok = await showAppConfirm(
      context,
      title: context.l10n.signOut,
      message: context.l10n.signOutConfirm,
      confirmLabel: context.l10n.signOut,
      danger: true,
    );
    if (!ok || !mounted) return;
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
                AppHeader(
                  title: context.l10n.navProfile,
                  actions: [if (_credits != null) CreditChip(_credits!)],
                ),
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
                            Text(name.isEmpty ? context.l10n.yourName : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: AppText.heading, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text(auth.user?.phoneNumber ?? '',
                                style: TextStyle(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.7))),
                          ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
                _group([
                  _row(Icons.person_outline_rounded, context.l10n.editProfile,
                      onTap: _editProfile),
                  _row(Icons.stars_outlined, context.l10n.adCredits,
                      onTap: () => _push(const AdCreditsScreen())),
                  _row(Icons.receipt_long_outlined, context.l10n.transactionHistory,
                      onTap: () => _push(const TransactionHistoryScreen())),
                ]),
                const SizedBox(height: 14),
                _group([
                  _themeRow(),
                  _languageRow(),
                  _row(Icons.gavel_rounded, context.l10n.legal, onTap: _showLegal),
                  _row(Icons.mail_outline_rounded, context.l10n.contactUs,
                      onTap: () => _push(const ContactScreen())),
                ]),
                const SizedBox(height: 14),
                _group([
                  _row(Icons.logout_rounded, context.l10n.signOut,
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

  // Light/Dark switch. ON = Dark. Reflects the theme currently in effect, so it
  // is correct even while the app is still following the device setting.
  Widget _themeRow() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 10),
        child: Row(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              key: ValueKey(isDark),
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(context.l10n.theme,
                style: TextStyle(
                    fontSize: AppText.body,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface)),
          ),
          Text(isDark ? context.l10n.themeDark : context.l10n.themeLight,
              style: TextStyle(
                  fontSize: AppText.secondary, color: cs.onSurface.withValues(alpha: 0.7))),
          const SizedBox(width: 6),
          Builder(
            builder: (switchContext) => Switch(
              value: isDark,
              onChanged: (v) => ThemeReveal.setDark(switchContext, v),
            ),
          ),
        ]),
      ),
    );
  }

  // Language: shows the current language and opens the picker.
  Widget _languageRow() {
    final cs = Theme.of(context).colorScheme;
    final current = context.watch<LocaleProvider>().nativeName;
    return InkWell(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const LanguageScreen(isSettings: true))),
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 12),
          child: Row(children: [
            const Icon(Icons.translate_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(context.l10n.language,
                  style: TextStyle(
                      fontSize: AppText.body,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
            ),
            Text(current,
                style: TextStyle(
                    fontSize: AppText.secondary,
                    color: cs.onSurface.withValues(alpha: 0.7))),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.35)),
          ]),
        ),
      ),
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
                    fontSize: AppText.body, fontWeight: FontWeight.w600, color: c)),
          ),
          if (chevron)
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.35)),
        ]),
      ),
    );
  }
}
