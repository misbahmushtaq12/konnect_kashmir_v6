import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One destination of the [FloatingNavBar].
class FloatingNavItem {
  /// The name of the destination: shown under the icon while it is selected, and
  /// read out / shown as a tooltip for every item.
  final String label;
  final Widget icon;
  final Widget selectedIcon;
  const FloatingNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

/// The app's bottom navigation: a rounded bar that floats a little above the
/// bottom edge, with the destinations as icons. The selected one sits in a soft
/// mint highlight with its name under the icon; the others stay quiet.
///
/// It only draws the bar and reports taps: which tab is open, and what tapping
/// does, stay with the screen that owns it (see MainShell).
class FloatingNavBar extends StatelessWidget {
  final List<FloatingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// The height of the bar itself (the space around it is extra).
  static const double barHeight = 64;
  static const double _maxWidth = 440;

  /// The page above the bar fades out over this height, so it does not end in a
  /// hard cut just above the floating bar.
  static const double fadeHeight = 20;

  /// The bar itself (the rounded box), for tests.
  static const Key pillKey = ValueKey<String>('nav-pill');
  static const Duration _speed = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final surface = AppColors.solid(cs);

    // The bar sits above the system gesture area / navigation buttons (SafeArea),
    // with some air around it, and never grows wider than a phone's width.
    final bar = SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: DecoratedBox(
              key: pillKey,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(barHeight / 2),
                border: Border.all(
                  color: (dark ? Colors.white : cs.onSurface).withValues(
                    alpha: dark ? 0.10 : 0.08,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.38 : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                // A touch lighter at the top, like glass catching the light.
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: dark ? 0.06 : 0.0),
                      surface,
                    ),
                    surface,
                  ],
                ),
              ),
              child: SizedBox(
                height: barHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _Slot(
                            key: ValueKey<String>('nav-$i'),
                            item: items[i],
                            selected: i == selectedIndex,
                            onTap: () => onSelected(i),
                            speed: _speed,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final page = AppColors.baseBg(theme);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Over the bottom of the page, which ends here.
        Positioned(
          left: 0,
          right: 0,
          top: -fadeHeight,
          height: fadeHeight,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    page.withValues(alpha: 0),
                    page.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),
        ),
        bar,
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  final FloatingNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final Duration speed;
  const _Slot({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    required this.speed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final accent = dark ? AppColors.primaryLight : AppColors.primaryDark;
    final muted = cs.onSurface.withValues(alpha: dark ? 0.58 : 0.55);
    final color = selected ? accent : muted;

    return Semantics(
      label: item.label,
      button: true,
      selected: selected,
      child: Tooltip(
        message: item.label,
        // The name is already read out by the item itself.
        excludeFromSemantics: true,
        // A tap must switch tabs at once; the name appears on a long press.
        triggerMode: TooltipTriggerMode.longPress,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FloatingNavBar.barHeight / 2),
          child: Center(
            child: LayoutBuilder(
              builder: (context, c) {
                // The highlight is a little narrower than its slot, and at most
                // as wide as a name needs.
                final width = selected
                    ? math.min(math.max(c.maxWidth - 6, 48.0), 84.0)
                    : 48.0;
                return AnimatedContainer(
                  duration: speed,
                  curve: Curves.easeOutCubic,
                  width: width,
                  height: 50,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(
                            alpha: dark ? 0.20 : 0.14,
                          )
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconTheme.merge(
                        data: IconThemeData(color: color, size: 24),
                        child: selected ? item.selectedIcon : item.icon,
                      ),
                      // The name grows in under the selected icon and folds away
                      // from the one that was left.
                      AnimatedSize(
                        duration: speed,
                        curve: Curves.easeOutCubic,
                        child: selected
                            ? Padding(
                                padding: const EdgeInsets.only(top: 1),
                                // (The item itself already says its name.)
                                child: ExcludeSemantics(
                                  child: _Label(item.label, color),
                                ),
                              )
                            : const SizedBox(width: 0, height: 0),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final Color color;
  const _Label(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    // Big system text must not push the name out of the bar.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: color,
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
