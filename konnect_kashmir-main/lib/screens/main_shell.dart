import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

import '../theme/app_theme.dart';
import '../l10n/l10n.dart';
import '../widgets/app_overlays.dart';
import 'customer_screen.dart';
import 'deen/deen_tab.dart';
import 'login_screen.dart';
import 'my_business_tab.dart';
import 'profile_tab.dart';

/// The app's main dashboard: bottom navigation with Home, My Business, Deen, Profile.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static const int tabHome = 0;
  static const int tabMyBusiness = 1;
  static const int tabDeen = 2;
  static const int tabProfile = 3;

  /// Ask the shell to switch tab (e.g. from a tapped notification).
  static final ValueNotifier<int?> tabRequest = ValueNotifier<int?>(null);
  static int _showing = 0;
  static bool get isShowing => _showing > 0;

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

  @override
  void initState() {
    super.initState();
    MainShell._showing++;
    MainShell.tabRequest.addListener(_onTabRequest);
    _onTabRequest();
  }

  void _onTabRequest() {
    final t = MainShell.tabRequest.value;
    if (t == null) return;
    MainShell.tabRequest.value = null;
    _select(t);
  }

  @override
  void dispose() {
    MainShell.tabRequest.removeListener(_onTabRequest);
    MainShell._showing--;
    super.dispose();
  }

  /// The server permanently rejected this login (see AuthProvider). Only a fresh
  /// sign-in recovers it, so say so once instead of failing silently.
  Future<void> _showSessionExpired() async {
    if (_expiredDialogOpen) return;
    _expiredDialogOpen = true;
    await showAppDialog<void>(
      context,
      title: context.l10n.sessionExpiredTitle,
      message: context.l10n.sessionExpiredMsg,
      barrierDismissible: false,
      actions: [
        Builder(
          builder: (ctx) => ElevatedButton(
            style: AppButtons.primary,
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.signIn),
          ),
        ),
      ],
    );
    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    await context.read<AuthProvider>().logout();
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  /// The Profile tab's icon: the round initial the Home screen used to show.
  Widget _profileIcon(String name, bool selected) {
    final n = name.trim();
    return CircleAvatar(
      radius: 13,
      backgroundColor:
          AppColors.primary.withValues(alpha: selected ? 1.0 : 0.6),
      child: Text(n.isNotEmpty ? n[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final expired =
        context.select<AuthProvider, bool>((a) => a.sessionExpired);
    final name =
        context.select<AuthProvider, String>((a) => a.user?.name ?? '');
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
            CustomerScreen(isActive: _index == 0, onOpenProfile: () => _select(MainShell.tabProfile)),
            _opened.contains(1)
                ? MyBusinessTab(isActive: _index == 1)
                : const SizedBox.shrink(),
            _opened.contains(2)
                ? DeenTab(isActive: _index == 2)
                : const SizedBox.shrink(),
            _opened.contains(3)
                ? ProfileTab(isActive: _index == 3)
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
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
                label: context.l10n.navHome,
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon:
                    Icon(Icons.storefront_rounded, color: AppColors.primary),
                label: context.l10n.navMyBusiness,
              ),
              NavigationDestination(
                icon: const Icon(Icons.mosque_outlined),
                selectedIcon:
                    const Icon(Icons.mosque_rounded, color: AppColors.primary),
                label: context.l10n.navDeen,
              ),
              NavigationDestination(
                icon: _profileIcon(name, false),
                selectedIcon: _profileIcon(name, true),
                label: context.l10n.navProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
