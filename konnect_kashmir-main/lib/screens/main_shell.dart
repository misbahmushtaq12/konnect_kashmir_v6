import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

import '../theme/app_theme.dart';
import 'customer_screen.dart';
import 'login_screen.dart';
import 'my_business_tab.dart';
import 'profile_tab.dart';

/// The app's main dashboard: bottom navigation with Home, My Business, Profile.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  // Tabs are built the first time they are opened (saves API calls at start).
  final Set<int> _opened = {0};

  void _select(int i) => setState(() {
        _index = i;
        _opened.add(i);
      });

  bool _expiredDialogOpen = false;

  /// The server permanently rejected this login (see AuthProvider). Only a fresh
  /// sign-in recovers it, so say so once instead of failing silently.
  Future<void> _showSessionExpired() async {
    if (_expiredDialogOpen) return;
    _expiredDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Session expired'),
        content: const Text(
            'For your security you need to sign in again to load your leads '
            'and credits.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Sign in')),
        ],
      ),
    );
    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    await context.read<AuthProvider>().logout();
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final expired =
        context.select<AuthProvider, bool>((a) => a.sessionExpired);
    if (expired && !_expiredDialogOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSessionExpired();
      });
    }

    return PopScope(
      // Back on another tab returns to Home instead of closing the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            CustomerScreen(isActive: _index == 0, onOpenProfile: () => _select(2)),
            _opened.contains(1)
                ? MyBusinessTab(isActive: _index == 1)
                : const SizedBox.shrink(),
            _opened.contains(2)
                ? ProfileTab(isActive: _index == 2)
                : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: cs.onSurface.withValues(alpha: 0.08))),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            backgroundColor: AppColors.baseBg(Theme.of(context)),
            indicatorColor: AppColors.primary.withValues(alpha: 0.16),
            elevation: 0,
            height: 68,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon:
                    Icon(Icons.storefront_rounded, color: AppColors.primary),
                label: 'My Business',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon:
                    Icon(Icons.person_rounded, color: AppColors.primary),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
