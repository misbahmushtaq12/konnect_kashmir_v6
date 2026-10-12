import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import 'app_overlays.dart';

/// Reading text size: a slider with A- / A+. [onChanged] is called with every
/// new value (80% to 180%), so the screen behind updates as the slider moves.
Future<void> showTextSizeSheet(
  BuildContext context, {
  required double value,
  required ValueChanged<double> onChanged,
}) {
  var current = value;
  return showAppSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      void set(double v) {
        current = v.clamp(0.8, 1.8);
        setSheet(() {});
        onChanged(current);
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(ctx.l10n.textSize,
                style: const TextStyle(
                    fontSize: AppText.title, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            IconButton(
                onPressed: () => set(current - 0.1),
                icon: const Icon(Icons.text_decrease_rounded)),
            Expanded(
              child: Slider(
                value: current,
                min: 0.8,
                max: 1.8,
                divisions: 10,
                onChanged: set,
              ),
            ),
            IconButton(
                onPressed: () => set(current + 0.1),
                icon: const Icon(Icons.text_increase_rounded)),
          ]),
        ]),
      );
    }),
  );
}
