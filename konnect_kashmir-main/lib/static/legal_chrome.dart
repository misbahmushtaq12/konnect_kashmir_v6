import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Space around the scrolling content of every legal page, so Terms, Privacy,
/// Refund, Grievance and Contact all start at the same distance from the bar.
const EdgeInsets kLegalPagePadding = EdgeInsets.fromLTRB(20, 20, 20, 32);

/// Back arrow, logo and a divider: the top of every legal page. The logo is the
/// same size as on the other screens.
class LegalAppBar extends StatelessWidget {
  const LegalAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final logo = Image.asset(
      'assets/images/konnectkashmir.png',
      cacheHeight: 384,
      height: 56,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: cs.onSurface),
                onPressed: () => Navigator.pop(context),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              theme.brightness == Brightness.dark
                  ? ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        -1, 0, 0, 0, 255, //
                        0, -1, 0, 0, 255,
                        0, 0, -1, 0, 255,
                        0, 0, 0, 1, 0,
                      ]),
                      child: logo,
                    )
                  : logo,
            ],
          ),
        ),
        Divider(
          color: cs.onSurface.withValues(alpha: 0.15),
          height: 1,
          thickness: 1,
        ),
      ],
    );
  }
}

/// Title block of a legal page: the title, a "last updated" pill, an optional
/// line of text under it and an optional highlighted note.
class LegalHeader extends StatelessWidget {
  final String title;
  final String? updated;
  final String? subtitle;
  final String? note;
  final String? noteTitle;

  const LegalHeader({
    super.key,
    required this.title,
    this.updated,
    this.subtitle,
    this.note,
    this.noteTitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppText.titleLg,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: cs.onSurface,
            ),
          ),
          if (updated != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.event_note_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    updated!,
                    style: const TextStyle(
                      fontSize: AppText.caption,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: AppText.body,
                height: 1.5,
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (noteTitle != null) ...[
                          Text(
                            noteTitle!,
                            style: TextStyle(
                              fontSize: AppText.body,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          note!,
                          style: TextStyle(
                            fontSize: AppText.secondary,
                            height: 1.5,
                            color: cs.onSurface.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
