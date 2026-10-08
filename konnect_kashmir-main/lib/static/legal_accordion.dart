import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Marks the start of a section inside a [LegalBody]. Rendered as a plain
/// heading on its own; [LegalBody] turns it into the header of an accordion card.
class LegalSectionTitle extends StatelessWidget {
  final String text;
  const LegalSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: AppText.heading,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface));
}

/// Drop-in replacement for the long `Column` of a legal page. Everything before
/// the first [LegalSectionTitle] (page title, note...) is shown as-is; each
/// section after it becomes a card that expands on tap. Only one card is open at
/// a time: opening another closes the current one.
class LegalBody extends StatefulWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  const LegalBody({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  State<LegalBody> createState() => _LegalBodyState();
}

class _Section {
  final String title;
  final List<Widget> body;
  _Section(this.title, this.body);
}

class _LegalBodyState extends State<LegalBody> {
  int? _open;

  // "1. Introduction" -> accordion card.  "Applicable Laws" (no number) stays
  // outside the dropdowns as a normal block.
  static final RegExp _numberedTitle = RegExp(r'^\s*\d+\s*\.');
  static bool _isNumbered(String title) => _numberedTitle.hasMatch(title);

  // Spacers between widgets are re-added by the card, so trim the edges.
  static bool _isSpacer(Widget w) => w is SizedBox && w.child == null;

  @override
  Widget build(BuildContext context) {
    final intro = <Widget>[];
    final sections = <_Section>[];

    for (final w in widget.children) {
      if (w is LegalSectionTitle) {
        sections.add(_Section(w.text, <Widget>[]));
      } else if (sections.isEmpty) {
        intro.add(w);
      } else {
        sections.last.body.add(w);
      }
    }
    for (final s in sections) {
      while (s.body.isNotEmpty && _isSpacer(s.body.first)) {
        s.body.removeAt(0);
      }
      while (s.body.isNotEmpty && _isSpacer(s.body.last)) {
        s.body.removeLast();
      }
    }

    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      children: [
        ...intro,
        for (var i = 0; i < sections.length; i++)
          _isNumbered(sections[i].title)
              ? _card(context, i, sections[i])
              : _plain(context, sections[i]),
      ],
    );
  }

  Widget _plain(BuildContext context, _Section s) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.title,
            style: TextStyle(
                fontSize: AppText.heading,
                fontWeight: FontWeight.w600,
                color: cs.onSurface)),
        const SizedBox(height: 12),
        ...s.body,
      ]),
    );
  }

  Widget _card(BuildContext context, int i, _Section s) {
    final cs = Theme.of(context).colorScheme;
    final open = _open == i;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: open
              ? AppColors.primary.withValues(alpha: 0.5)
              : cs.onSurface.withValues(alpha: 0.10),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _open = open ? null : i),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Row(children: [
              Expanded(
                child: Text(s.title,
                    style: TextStyle(
                        fontSize: AppText.heading,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: cs.onSurface)),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 26,
                    color: open
                        ? AppColors.primary
                        : cs.onSurface.withValues(alpha: 0.6)),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeOutCubic,
          crossFadeState:
              open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: s.body),
          ),
        ),
      ]),
    );
  }
}
