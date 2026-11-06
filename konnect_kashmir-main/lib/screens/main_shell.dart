import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/app_analytics.dart';

import '../theme/app_theme.dart';
import '../l10n/l10n.dart';
import '../widgets/app_overlays.dart';
import '../widgets/floating_nav_bar.dart';
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
  static const _tabNames = ['home', 'my_business', 'deen', 'profile'];
  // Tabs are built the first time they are opened (saves API calls at start).
  final Set<int> _opened = {0};

  void _select(int i) {
    setState(() {
      _index = i;
      _opened.add(i);
    });
    AppAnalytics.instance.tab(_tabNames[i]);
  }

  bool _expiredDialogOpen = false;

  @override
  void initState() {
    super.initState();
    MainShell._showing++;
    MainShell.tabRequest.addListener(_onTabRequest);
    _onTabRequest();
    AppAnalytics.instance.tab(_tabNames[_index]);
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

  @override
  Widget build(BuildContext context) {
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
        // The pages run behind the floating bar instead of stopping above a
        // blank strip; each one pads its list's end (FloatingNavBar.bottomClearance).
        extendBody: true,
        // (The scope hands the bar's height to each page's main list only, so
        // lists and grids nested inside a page add no blank strip of their own.)
        body: FloatingNavBarScope(
          child: IndexedStack(
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
        ),
        // The bottom bar is on every tab, Deen included. (Android's back button on
        // another tab goes to Home.) It floats a little above the bottom edge, over
        // the pages, which scroll behind it and pad their last item clear of it.
        bottomNavigationBar: FloatingNavBar(
          selectedIndex: _index,
          onSelected: _select,
          items: [
            FloatingNavItem(
              label: context.l10n.navHome,
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
            ),
            FloatingNavItem(
              label: context.l10n.navMyBusiness,
              icon: const Icon(Icons.storefront_outlined),
              selectedIcon: const Icon(Icons.storefront_rounded),
            ),
            FloatingNavItem(
              label: context.l10n.navDeen,
              icon: const Icon(Icons.mosque_outlined),
              selectedIcon: const Icon(Icons.mosque_rounded),
            ),
            FloatingNavItem(
              label: context.l10n.navProfile,
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
