import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../widgets/english_only.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';

/// Language picker (English / हिन्दी / اردو).
///
/// Shown once after the first OTP login ([onContinue] opens the next screen),
/// and reachable any time from Profile ([isSettings] = true, pops on Continue).
/// Tapping a language switches the whole app immediately, so the user sees the
/// result before confirming.
class LanguageScreen extends StatelessWidget {
  final VoidCallback? onContinue;
  final bool isSettings;

  const LanguageScreen({super.key, this.onContinue, this.isSettings = false});

  static const _englishNames = {'en': 'English', 'hi': 'Hindi', 'ur': 'Urdu'};

  @override
  Widget build(BuildContext context) {
    final body = Builder(builder: _buildBody);
    // The picker shown right after sign-in is always English; the one opened from
    // Profile follows the current app language.
    return isSettings ? body : EnglishOnly(child: body);
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = context.watch<LocaleProvider>();

    return PopScope(
      // First-time picker must be completed; Profile one can be backed out of.
      canPop: isSettings,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(children: [
              // Scrollable, so a short screen (e.g. keyboard still open) never overflows.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
              if (isSettings)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const BackButtonIcon(),
                  ),
                )
              else
                const SizedBox(height: 48),
              const SizedBox(height: 16),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.translate_rounded,
                    color: AppColors.primary, size: 28),
              ),
              const SizedBox(height: 20),
              Text(context.l10n.chooseLanguage,
                  style: const TextStyle(
                      fontSize: AppText.title, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(context.l10n.chooseLanguageHint,
                  style: TextStyle(
                      fontSize: AppText.body,
                      height: 1.4,
                      color: cs.onSurface.withValues(alpha: 0.7))),
              const SizedBox(height: 28),
              for (final lang in LocaleProvider.supported) ...[
                _LanguageTile(
                  nativeName: lang.nativeName,
                  englishName: _englishNames[lang.locale.languageCode] ?? '',
                  selected: locale.locale.languageCode ==
                      lang.locale.languageCode,
                  onTap: () => context.read<LocaleProvider>().setLocale(lang.locale),
                ),
                const SizedBox(height: 12),
              ],
                      ]),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: AppButtons.block(AppButtons.primary),
                onPressed: () async {
                  await context.read<LocaleProvider>().confirmChoice();
                  if (!context.mounted) return;
                  if (onContinue != null) {
                    onContinue!();
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Text(context.l10n.continueLabel),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String nativeName;
  final String englishName;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.nativeName,
    required this.englishName,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.10)
              : AppColors.solid(cs).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : cs.onSurface.withValues(alpha: 0.12),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nativeName,
                  style: const TextStyle(
                      fontSize: AppText.heading, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(englishName,
                  style: TextStyle(
                      fontSize: AppText.secondary,
                      color: cs.onSurface.withValues(alpha: 0.65))),
            ]),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              key: ValueKey(selected),
              color: selected
                  ? AppColors.primary
                  : cs.onSurface.withValues(alpha: 0.35),
              size: 26,
            ),
          ),
        ]),
      ),
    );
  }
}
