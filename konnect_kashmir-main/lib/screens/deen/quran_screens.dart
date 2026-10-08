import 'dart:async';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/error_retry.dart';
import 'quran_service.dart';

/// All 114 surahs, with search. Tapping one opens the reader.
class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  List<Surah> _all = [];
  String _q = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await QuranService.surahs();
      if (!mounted) return;
      setState(() {
        _all = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty
        ? _all
        : _all
            .where((s) =>
                s.english.toLowerCase().contains(q) ||
                s.translation.toLowerCase().contains(q) ||
                s.arabic.contains(q) ||
                s.number.toString() == q)
            .toList();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.deenQuran)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: context.l10n.deenSearchSurah,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? ListView(padding: const EdgeInsets.all(20), children: [
                  for (var i = 0; i < 8; i++) ...[
                    const Skeleton(height: 64, radius: AppRadius.md),
                    const SizedBox(height: 10),
                  ]
                ])
              : _error != null
                  ? ErrorRetry.fromError(_error, onRetry: _load)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = shown[i];
                        return AppCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => SurahReaderScreen(surah: s))),
                          child: Row(children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('${s.number}',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.english,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: AppText.body)),
                                    const SizedBox(height: 2),
                                    Text(
                                        '${s.translation} · ${context.l10n.deenVerses(s.ayahs.toString())}',
                                        style: TextStyle(
                                            fontSize: AppText.caption,
                                            color: cs.onSurface
                                                .withValues(alpha: 0.6))),
                                  ]),
                            ),
                            Text(s.arabic,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                    fontSize: AppText.heading,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

/// Reads one surah: Arabic with the English meaning under each verse. The
/// verse the reader reaches is remembered for "Continue Reading".
class SurahReaderScreen extends StatefulWidget {
  final Surah surah;

  /// Start from this verse (used by "Continue Reading").
  final int startAyah;

  const SurahReaderScreen({super.key, required this.surah, this.startAyah = 1});

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  List<Ayah> _ayahs = [];
  bool _loading = true;
  String? _error;
  late int _from = (widget.startAyah - 1).clamp(0, 1 << 20);
  int _reached = 0;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _reached = widget.startAyah;
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    QuranService.saveLastRead(widget.surah.number, _reached);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final a = await QuranService.ayahs(widget.surah.number);
      if (!mounted) return;
      setState(() {
        _ayahs = a;
        _loading = false;
        if (_from >= a.length) _from = 0;
      });
      QuranService.saveLastRead(widget.surah.number, _reached);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _seen(int ayahNumber) {
    if (ayahNumber <= _reached) return;
    _reached = ayahNumber;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800),
        () => QuranService.saveLastRead(widget.surah.number, _reached));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = widget.surah;
    final hasEarlier = _from > 0;

    return Scaffold(
      appBar: AppBar(title: Text('${s.number}. ${s.english}')),
      body: _loading
          ? ListView(padding: const EdgeInsets.all(20), children: [
              for (var i = 0; i < 4; i++) ...[
                const Skeleton(height: 120, radius: AppRadius.md),
                const SizedBox(height: 12),
              ]
            ])
          : _error != null
              ? ErrorRetry.fromError(_error, onRetry: _load)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  itemCount: _ayahs.length - _from + (hasEarlier ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (hasEarlier && i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _from = 0),
                          icon: const Icon(Icons.keyboard_arrow_up_rounded),
                          label: Text(context.l10n.deenShowEarlier),
                        ),
                      );
                    }
                    final a = _ayahs[_from + i - (hasEarlier ? 1 : 0)];
                    _seen(a.number);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text('${s.number}:${a.number}',
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: AppText.caption,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: Text(a.arabic,
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontSize: 26, height: 2.0)),
                              ),
                              const SizedBox(height: 10),
                              Text(a.english,
                                  textDirection: TextDirection.ltr,
                                  style: TextStyle(
                                      fontSize: AppText.body,
                                      height: 1.5,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.8))),
                            ]),
                      ),
                    );
                  },
                ),
    );
  }
}
