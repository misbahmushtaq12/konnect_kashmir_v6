import 'package:konnect_kashmir/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../widgets/app_overlays.dart';
import '../widgets/app_snack.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:konnect_kashmir/services/api_service.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSavingName = false;
  final TextEditingController _nameController = TextEditingController();

  ApiService get _api => ApiService(
    token: context.read<AuthProvider>().accessToken,
    userId: context.read<AuthProvider>().userId,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  Future<void> _showEditProfileDialog() async {
    final auth = context.read<AuthProvider>();
    final cs = Theme.of(context).colorScheme;
    _nameController.text = auth.user?.name ?? '';

    await showAppSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar

            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFF6BC4B2).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Icon(Icons.edit_outlined,
                    color: Color(0xFF6BC4B2), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit Profile',
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: AppText.title,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Update your display name',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.5),
                              fontSize: AppText.secondary)),
                    ]),
              ),
              GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Icon(Icons.close,
                      color: cs.onSurface.withValues(alpha: 0.45), size: 22)),
            ]),
            const SizedBox(height: 24),
            Text('Display Name',
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: AppText.body,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: cs.onSurface, fontSize: AppText.body),
              decoration: InputDecoration(
                hintText: 'Enter your name',
                hintStyle:
                TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
                prefixIcon: Icon(Icons.person_outline,
                    color: cs.onSurface.withValues(alpha: 0.5)),
                filled: true,
                fillColor: cs.onSurface.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                        color: cs.onSurface.withValues(alpha: 0.1))),
                focusedBorder: const OutlineInputBorder(
                    borderRadius:
                    BorderRadius.all(Radius.circular(AppRadius.md)),
                    borderSide: BorderSide(
                        color: Color(0xFF6BC4B2), width: 2)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSavingName
                    ? null
                    : () async {
                  final newName = _nameController.text.trim();
                  if (newName.isEmpty) {
                    showAppSnack(context, 'Name cannot be empty.', type: SnackType.warning);
                    return;
                  }
                  setState(() => _isSavingName = true);

                  // FIX 1: Use updateUserProfile instead of updateProfile
                  try {
                    final userId = context.read<AuthProvider>().userId ?? '';
                    await _api.updateUserProfile(userId, {'full_name': newName});
                  } catch (_) {}

                  if (!mounted) return;

                  // FIX 2: Use refreshProfile instead of updateName
                  try {
                    await context.read<AuthProvider>().refreshProfile();
                  } catch (_) {}

                  setState(() => _isSavingName = false);
                  if (mounted) {
                    Navigator.pop(ctx);
                    showAppSnack(context, 'Profile updated successfully!', type: SnackType.success);
                  }
                },
                style: AppButtons.primary,
                child: _isSavingName
                    ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes',
                    style: TextStyle(
                        fontSize: AppText.body, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ));
  }

  // ──────────────────────────────────────────────────────────
  // Sign Out Dialog
  // ──────────────────────────────────────────────────────────
  void _showSignOutDialog(AuthProvider auth) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out',
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to sign out?',
            style:
            TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: Text('Sign Out',
                style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Delete Account Sheet
  // ──────────────────────────────────────────────────────────
  Future<void> _showDeleteAccountSheet() async {
    const String supportEmail = 'info@konnectkashmir.com';
    const String supportPhone = '+919055566624';
    const String supportPhoneDisplay = '+91 9055566624';
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showAppSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Icon(Icons.delete_forever_outlined,
                    color: AppColors.danger, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Delete Account',
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: AppText.title,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text("We're sorry to see you go",
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.5),
                              fontSize: AppText.secondary)),
                    ]),
              ),
              GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Icon(Icons.close,
                      color: cs.onSurface.withValues(alpha: 0.45),
                      size: 22)),
            ]),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.danger.withValues(alpha: 0.08)
                    : AppColors.danger.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.25)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline,
                          color: AppColors.danger.withValues(alpha: 0.8),
                          size: 18),
                      const SizedBox(width: 8),
                      Text('Before you proceed',
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: AppText.body,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                      'Account deletion is permanent and cannot be undone. '
                          'All your data, credits, and unlocked contacts will be lost.\n\n'
                          'To request deletion, please contact us. Our team will process '
                          'your request within 7 business days.',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.65),
                          fontSize: AppText.secondary,
                          height: 1.6),
                    ),
                  ]),
            ),
            const SizedBox(height: 20),
            Text('Contact Us To Delete',
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: AppText.body,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final Uri emailUri = Uri(
                  scheme: 'mailto',
                  path: supportEmail,
                  query:
                  'subject=Account Deletion Request&body=Hi KonnectKashmir team,%0A%0AI would like to request the deletion of my account.',
                );
                if (await canLaunchUrl(emailUri)) {
                  await launchUrl(emailUri);
                }
              },
              child: _contactTile(
                  cs, Icons.email_outlined, 'Email Us', supportEmail),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final Uri telUri =
                Uri(scheme: 'tel', path: supportPhone);
                if (await canLaunchUrl(telUri)) {
                  await launchUrl(telUri);
                }
              },
              child: _contactTile(cs, Icons.phone_outlined, 'Call Us',
                  supportPhoneDisplay),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: AppButtons.secondary,
                child: Text('Cancel',
                    style: TextStyle(
                        fontSize: AppText.body,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
              ),
            ),
          ],
        ),
      ));
  }

  Widget _contactTile(
      ColorScheme cs, IconData icon, String title, String subtitle) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: const Color(0xFF6BC4B2).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: const Color(0xFF6BC4B2).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Icon(icon, color: const Color(0xFF6BC4B2), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: AppText.body,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF6BC4B2), fontSize: AppText.secondary)),
                ])),
        Icon(Icons.arrow_forward_ios_rounded,
            color: const Color(0xFF6BC4B2).withValues(alpha: 0.6), size: 14),
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final String userName = auth.user?.name ?? 'User';

    // FIX 3: AuthUser has no 'email' field — use phoneNumber instead
    final String userEmail = auth.user?.phoneNumber ?? '';

    // Initials for avatar
    final initials = userName
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(children: [
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                              color: cs.onSurface.withValues(alpha: 0.1)),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: cs.onSurface, size: 18),
                      ),
                    ),
                    const Spacer(),
                    Text('Profile',
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: AppText.heading,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    const SizedBox(width: 44), // balance
                  ]),
                ),

                const SizedBox(height: 36),

                // ── Avatar ───────────────────────────────────
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0E3D2E),
                        border: Border.all(
                            color: const Color(0xFF6BC4B2),
                            width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6BC4B2)
                                .withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: initials.isNotEmpty
                            ? Text(initials,
                            style: const TextStyle(
                                color: Color(0xFF6BC4B2),
                                fontSize: 36,
                                fontWeight: FontWeight.bold))
                            : const Icon(Icons.person_rounded,
                            color: Color(0xFF6BC4B2), size: 52),
                      ),
                    ),
                    // Edit badge
                    GestureDetector(
                      onTap: _showEditProfileDialog,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6BC4B2),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.baseBg(theme),
                              width: 2),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Name ─────────────────────────────────────
                Text(
                  userName,
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3),
                ),

                if (userEmail.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6BC4B2).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                          color:
                          const Color(0xFF6BC4B2).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      userEmail,
                      style: const TextStyle(
                          color: Color(0xFF6BC4B2),
                          fontSize: AppText.secondary,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // ── Menu items ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(children: [
                    // Edit Profile
                    _buildMenuItem(
                      cs: cs,
                      isDark: isDark,
                      icon: Icons.edit_outlined,
                      iconBg: const Color(0xFF6BC4B2).withValues(alpha: 0.15),
                      iconColor: const Color(0xFF6BC4B2),
                      title: 'Edit Profile',
                      subtitle: 'Update your display name',
                      onTap: _showEditProfileDialog,
                    ),

                    const SizedBox(height: 12),

                    // Delete Account
                    _buildMenuItem(
                      cs: cs,
                      isDark: isDark,
                      icon: Icons.delete_outline_rounded,
                      iconBg: AppColors.danger.withValues(alpha: 0.1),
                      iconColor: AppColors.danger,
                      title: 'Delete Account',
                      subtitle: 'Permanently remove your account',
                      onTap: _showDeleteAccountSheet,
                    ),

                    const SizedBox(height: 12),

                    // Sign Out
                    _buildMenuItem(
                      cs: cs,
                      isDark: isDark,
                      icon: Icons.logout_rounded,
                      iconBg: AppColors.warning.withValues(alpha: 0.1),
                      iconColor: AppColors.warning,
                      title: 'Sign Out',
                      subtitle: 'Log out of your account',
                      titleColor: AppColors.warning,
                      onTap: () => _showSignOutDialog(auth),
                    ),
                  ]),
                ),

                const SizedBox(height: 48),

                // ── Footer note ──────────────────────────────
                Text(
                  '© 2026 Media Mosiac (OPC) Pvt. Ltd.',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.3),
                      fontSize: AppText.caption),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildMenuItem({
    required ColorScheme cs,
    required bool isDark,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isDark
                ? cs.onSurface.withValues(alpha: 0.04)
                : cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
            boxShadow: isDark
                ? []
                : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: titleColor ?? cs.onSurface,
                              fontSize: AppText.body,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.45),
                              fontSize: AppText.caption)),
                    ])),
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.3), size: 22),
          ]),
        ),
      ),
    );
  }
}