import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'customer_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            CustomerScreen(isActive: _index == 0),
            _opened.contains(1)
                ? const MyBusinessTab()
                : const SizedBox.shrink(),
            _opened.contains(2) ? const ProfileTab() : const SizedBox.shrink(),
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
