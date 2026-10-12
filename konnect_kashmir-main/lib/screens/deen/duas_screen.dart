import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/text_size_sheet.dart';
import 'deen_data.dart';

/// Everyday duas: Arabic, meaning in the app language, and where it is from.
/// The text size can be changed (and is remembered), like in the Quran reader.
class DuasScreen extends StatefulWidget {
  const DuasScreen({super.key});

  @override
  State<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends State<DuasScreen> {
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadScale();
  }

  Future<void> _loadScale() async {
    try {
      final v = (await SharedPreferences.getInstance()).getDouble('duas_text_scale');
      if (v != null && mounted) setState(() => _scale = v.clamp(0.8, 1.8));
    } catch (_) {}
  }

  Future<void> _saveScale() async {
    try {
      await (await SharedPreferences.getInstance())
          .setDouble('duas_text_scale', _scale);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.deenDuas),
        actions: [
          IconButton(
            tooltip: context.l10n.textSize,
            icon: const Icon(Icons.text_fields_rounded),
            onPressed: () => showTextSizeSheet(context, value: _scale,
                onChanged: (v) {
              setState(() => _scale = v);
              _saveScale();
            }),
          ),
        ],
      ),
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
                  style: TextStyle(
                      fontSize: AppText.heading * _scale,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Text(d.arabic,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 24 * _scale, height: 1.9)),
              ),
              const SizedBox(height: 10),
              Text(d.meaningFor(locale),
                  style: TextStyle(
                      fontSize: AppText.body * _scale,
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
