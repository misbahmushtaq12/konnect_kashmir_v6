import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/app_links.dart';
import 'main_shell.dart';

/// Where a link that opens the app lands while the app is already open (when
/// the app is started by the link, main.dart handles it instead). It shows
/// nothing: if the user is signed in and the link is for the leads it asks the
/// shell for the My Business tab, and it leaves at once.
class LeadsLinkScreen extends StatefulWidget {
  /// The link, such as "/go?utm_campaign=new_lead".
  final String route;
  const LeadsLinkScreen({super.key, this.route = AppLinks.leadsPath});

  @override
  State<LeadsLinkScreen> createState() => _LeadsLinkScreenState();
}

class _LeadsLinkScreenState extends State<LeadsLinkScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = Navigator.of(context);
      final loggedIn = context.read<AuthProvider>().isAuthenticated;
      // Signed in: the shell switches to My Business at once if it is open.
      // Signed out: nothing is kept, so after signing in the user sees Home.
      if (loggedIn && AppLinks.isLeadsLink(widget.route)) {
        MainShell.tabRequest.value = MainShell.tabMyBusiness;
      }
      if (MainShell.isShowing || !loggedIn) {
        nav.pop();
      } else {
        nav.pushNamedAndRemoveUntil('/home', (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}
