import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Text that is cut after [maxLines]. When it really is cut, a "See more" link
/// shows the whole text, and "See less" folds it again.
class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  const ExpandableText(this.text,
      {super.key, required this.style, this.maxLines = 2});

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: widget.maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: box.maxWidth);
      final cut = painter.didExceedMaxLines;

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.text,
            maxLines: _open ? null : widget.maxLines,
            overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
            style: widget.style),
        if (cut || _open)
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(_open ? context.l10n.seeLess : context.l10n.seeMore,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: AppText.secondary,
                      fontWeight: FontWeight.w700)),
            ),
          ),
      ]);
    });
  }
}
