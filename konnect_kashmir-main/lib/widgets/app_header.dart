import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Top row used by every main screen so they all line up: a title (or a custom
/// [leading] widget such as the logo) on the left and [actions] on the right.
class AppHeader extends StatelessWidget {
  final String? title;
  final Widget? leading;
  final List<Widget> actions;

  const AppHeader({
    super.key,
    this.title,
    this.leading,
    this.actions = const [],
  }) : assert(title != null || leading != null);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(children: [
        if (leading != null)
          Expanded(child: Align(alignment: Alignment.centerLeft, child: leading))
        else
          Expanded(
            child: Text(title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: AppText.titleLg, fontWeight: FontWeight.w800)),
          ),
        for (var i = 0; i < actions.length; i++) ...[
          const SizedBox(width: 8),
          actions[i],
        ],
      ]),
    );
  }
}

/// The credit balance pill (star + number). Tappable when [onTap] is given.
class CreditChip extends StatelessWidget {
  final int credits;
  final VoidCallback? onTap;

  const CreditChip(this.credits, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.stars_rounded, size: 16, color: AppColors.primary),
        const SizedBox(width: 4),
        Text('$credits',
            style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: AppText.secondary)),
      ]),
    );
    if (onTap == null) return chip;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: chip,
    );
  }
}
