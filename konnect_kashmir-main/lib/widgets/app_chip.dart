import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum ChipTone { neutral, primary, success, warning, danger, info }

/// The one small pill used for tags and status labels everywhere ("Active",
/// "3 Leads", "Home visit", "Pending"...). Tone picks the colour from [AppColors].
class AppChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final ChipTone tone;

  const AppChip(
    this.label, {
    super.key,
    this.icon,
    this.tone = ChipTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color fg;
    final Color bg;
    switch (tone) {
      case ChipTone.neutral:
        fg = cs.onSurface.withValues(alpha: 0.78);
        bg = cs.onSurface.withValues(alpha: 0.07);
      case ChipTone.primary:
        fg = AppColors.primary;
        bg = AppColors.primary.withValues(alpha: 0.15);
      case ChipTone.success:
        fg = AppColors.success;
        bg = AppColors.success.withValues(alpha: 0.15);
      case ChipTone.warning:
        // Amber on a light background is hard to read; darken it in Light mode.
        fg = Theme.of(context).brightness == Brightness.dark
            ? AppColors.warning
            : const Color(0xFF9A6200);
        bg = AppColors.warning.withValues(alpha: 0.18);
      case ChipTone.danger:
        fg = AppColors.danger;
        bg = AppColors.danger.withValues(alpha: 0.15);
      case ChipTone.info:
        fg = AppColors.info;
        bg = AppColors.info.withValues(alpha: 0.15);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: TextStyle(
                fontSize: AppText.caption,
                fontWeight: FontWeight.w700,
                color: fg)),
      ]),
    );
  }
}
