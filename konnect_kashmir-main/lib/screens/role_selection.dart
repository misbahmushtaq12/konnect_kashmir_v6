import 'package:flutter/material.dart';
import 'package:konnect_kashmir/screens/vendor_dashboard.dart';
import 'customer_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  final String role;
  final String name;
  final String phone;

  const RoleSelectionScreen({
    super.key,
    required this.role,
    required this.name,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final size       = MediaQuery.of(context).size;
    final isVendor   = role == 'vendor';
    final theme      = Theme.of(context);
    final cs         = theme.colorScheme;
    final isDark     = theme.brightness == Brightness.dark;

    final cardBg = cs.surface.withOpacity(0.1);

    final mutedText = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    const customerColor = Colors.blue;
    const vendorColor   = Colors.orange;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: isDark ? 0.18 : 0.08,
                child: Image.asset(
                  'assets/images/chinar.png',
                  width: size.width,
                  height: size.height,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.primary.withOpacity(0.5),
                          ),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: cs.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'KonnectKashmir',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  Text(
                    name.isNotEmpty ? 'Welcome, $name! 👋' : 'Welcome! 👋',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'How would you like to continue?',
                    style: TextStyle(fontSize: 15, color: mutedText),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 52),

                  _RoleCard(
                    icon: Icons.person_outline,
                    iconBg: customerColor.withOpacity(0.15),
                    iconColor: isDark
                        ? Colors.blue.shade300
                        : Colors.blue.shade700,
                    borderColor: (!isVendor)
                        ? customerColor.withOpacity(0.55)
                        : customerColor.withOpacity(0.15),
                    cardBg: cardBg,
                    title: 'Customer View',
                    subtitle: 'Browse local services and connect with vendors',
                    badgeText: (!isVendor) ? 'Your Account' : null,
                    badgeColor: isDark
                        ? Colors.blue.shade400
                        : Colors.blue.shade700,
                    mutedText: mutedText,
                    onTap: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CustomerScreen()),
                          (_) => false,
                    ),
                  ),

                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.store_outlined,
                    iconBg: vendorColor.withOpacity(0.15),
                    iconColor: isDark
                        ? Colors.orange.shade300
                        : Colors.orange.shade800,
                    borderColor: isVendor
                        ? vendorColor.withOpacity(0.55)
                        : vendorColor.withOpacity(0.15),
                    cardBg: cardBg,
                    title: 'Vendor Panel',
                    subtitle: 'Manage your businesses and view leads',
                    badgeText: isVendor ? 'Your Account' : null,
                    badgeColor: isDark
                        ? Colors.orange.shade400
                        : Colors.orange.shade800,
                    mutedText: mutedText,
                    onTap: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const VendorDashboardScreen()),
                          (_) => false,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── Signed in as ───────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_outlined,
                            color: mutedText, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Signed in as $phone',
                          style: TextStyle(color: mutedText, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small account badge (currently unused but kept for opt-in use) ────────────
class _AccountBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _AccountBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Role Card widget ─────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color borderColor;
  final Color cardBg;
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final Color mutedText;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.borderColor,
    required this.cardBg,
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.badgeColor,
    required this.mutedText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // ── Icon ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),

            const SizedBox(width: 16),

            // ── Text ──────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (badgeText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? cs.onSurface)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText!,
                            style: TextStyle(
                              color: badgeColor ?? cs.onSurface,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: mutedText,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Arrow ─────────────────────────────────────────────────────
            Icon(Icons.arrow_forward_ios,
                color: mutedText, size: 16),
          ],
        ),
      ),
    );
  }
}