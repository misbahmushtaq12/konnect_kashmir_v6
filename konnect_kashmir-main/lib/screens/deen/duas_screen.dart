import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'deen_data.dart';

/// Everyday duas: Arabic, meaning in the app language, and where it is from.
class DuasScreen extends StatelessWidget {
  const DuasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.deenDuas)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        itemCount: kDuas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final d = kDuas[i];
          return AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.titleFor(locale),
                  style: const TextStyle(
                      fontSize: AppText.heading, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Text(d.arabic,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 24, height: 1.9)),
              ),
              const SizedBox(height: 10),
              Text(d.meaningFor(locale),
                  style: TextStyle(
                      fontSize: AppText.body,
                      height: 1.5,
                      color: cs.onSurface.withValues(alpha: 0.8))),
              const SizedBox(height: 8),
              Text(context.l10n.deenDuaSource(d.source),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                      fontSize: AppText.caption,
                      color: cs.onSurface.withValues(alpha: 0.55))),
            ]),
          );
        },
      ),
    );
  }
}
