import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../widgets/add_credit_section.dart';

/// The Add Credit UI on its own screen (also opened from My Business). The same
/// UI sits on the main Profile screen.
class AdCreditsScreen extends StatefulWidget {
  const AdCreditsScreen({super.key});

  @override
  State<AdCreditsScreen> createState() => _AdCreditsScreenState();
}

class _AdCreditsScreenState extends State<AdCreditsScreen> {
  final GlobalKey<AddCreditSectionState> _section = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.adCredits)),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => _section.currentState?.reload(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [AddCreditSection(key: _section)],
        ),
      ),
    );
  }
}
