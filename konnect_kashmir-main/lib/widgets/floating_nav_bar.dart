import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One destination of the [FloatingNavBar].
class FloatingNavItem {
  /// The name of the destination. The bar shows no text, so this is what a
  /// screen reader says and what a long press shows as a tooltip.
  final String label;
  final Widget icon;
  final Widget selectedIcon;
  const FloatingNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

/// The app's bottom navigation: a slim, icon-only capsule that floats a little
/// above the bottom edge. It is dark frosted glass with a fine outline and a soft
/// shadow. The selected destination sits in a small round highlight with its
/// (filled) icon in the accent colour; the others stay quiet outline icons.
///
/// Only the capsule is drawn: the space around it is see-through and taps there
/// reach the page beneath. The page runs behind the bar (see [bottomClearance]).
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

  /// The height of the capsule itself (the space around it is extra). Every item
  /// is as tall as this, so each is an easy target.
  static const double barHeight = 56;

  /// The round highlight behind the selected icon, and the icon inside it.
  static const double highlightSize = 42;
  static const double iconSize = 24;

  /// The capsule is compact: it never grows wider than this, even on a tablet.
  static const double _maxWidth = 312;

  /// The air around the capsule (below it comes on top of the system inset).
  static const double _airTop = 4;
  static const double _airBottom = 8;

  /// The capsule itself, for tests.
  static const Key pillKey = ValueKey<String>('nav-pill');
  static const Duration _speed = Duration(milliseconds: 240);

  /// The bottom padding a scrolling page needs so that its last item can be
  /// scrolled clear of the bar.
  ///
  /// The bar floats over the page (the Scaffold has `extendBody`), so the page
  /// is as tall as the screen and reserves no blank strip for the bar. Inside a
  /// [FloatingNavBarScope] this is the bar's whole height (the system inset
  /// included) plus a little [gap]; anywhere else, just the system inset plus
  /// the gap. Only the page's own main list uses it: such a page must not wrap
  /// itself in a bottom `SafeArea`, which would shrink it by the same amount
  /// again.
  static double bottomClearance(BuildContext context, {double gap = 12}) =>
      (_NavBarInset.maybeOf(context) ?? MediaQuery.paddingOf(context).bottom) +
      gap;

  @override
  Widget build(BuildContext context) {
    // With the keyboard open the bar would ride up on top of it and cover the
    // page: it steps aside until the keyboard closes.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final surface = AppColors.solid(cs);
    final radius = BorderRadius.circular(barHeight / 2);

    // The bar sits above the system gesture area / navigation buttons (SafeArea),
    // with some air around it, and never grows wider than a phone's width.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, _airTop, 16, _airBottom),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: DecoratedBox(
              key: pillKey,
              // The soft shadow, outside the glass.
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.34 : 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: DecoratedBox(
                // The fine outline, drawn over the glass.
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: (dark ? Colors.white : cs.onSurface).withValues(
                      alpha: dark ? 0.13 : 0.09,
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: DecoratedBox(
                      // Translucent, a touch lighter at the top like glass
                      // catching the light.
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.alphaBlend(
                              Colors.white.withValues(alpha: dark ? 0.07 : 0.0),
                              surface,
                            ).withValues(alpha: dark ? 0.80 : 0.86),
                            surface.withValues(alpha: dark ? 0.80 : 0.86),
                          ],
                        ),
                      ),
                      // The ink splash of a tap is drawn on this, over the glass.
                      child: Material(
                        type: MaterialType.transparency,
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
              ),
            ),
          ),
        ),
      ),
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
    final muted = cs.onSurface.withValues(alpha: dark ? 0.62 : 0.58);
    final color = selected ? accent : muted;
    // The highlight fades in from the same hue (not from black), so the change
    // is a clean fade.
    final fill = AppColors.primary.withValues(
      alpha: selected ? (dark ? 0.26 : 0.16) : 0,
    );

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
          customBorder: const StadiumBorder(),
          splashColor: accent.withValues(alpha: 0.14),
          highlightColor: accent.withValues(alpha: 0.08),
          child: Center(
            child: SizedBox(
              width: FloatingNavBar.highlightSize,
              height: FloatingNavBar.highlightSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The round highlight grows in behind the icon.
                  AnimatedScale(
                    scale: selected ? 1 : 0.6,
                    duration: speed,
                    curve: Curves.easeOutCubic,
                    child: AnimatedContainer(
                      duration: speed,
                      curve: Curves.easeOutCubic,
                      width: FloatingNavBar.highlightSize,
                      height: FloatingNavBar.highlightSize,
                      decoration: BoxDecoration(
                        color: fill,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // The icon changes colour with it.
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: color),
                    duration: speed,
                    curve: Curves.easeOutCubic,
                    builder: (context, c, child) => IconTheme.merge(
                      data: IconThemeData(
                        color: c,
                        size: FloatingNavBar.iconSize,
                      ),
                      child: child!,
                    ),
                    child: selected ? item.selectedIcon : item.icon,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The body of a Scaffold that has a [FloatingNavBar] and `extendBody: true`.
///
/// With `extendBody` the Scaffold puts the bar's height into
/// `MediaQuery.padding.bottom` for its body. A `ListView` or `GridView` with no
/// padding of its own adds that as its own bottom padding, so every list or grid
/// nested in a page (a grid of services that only wraps its tiles, for one) would
/// end in a blank strip as tall as the bar, between it and what follows.
///
/// This hands the bar's height on in one place instead: the page's own main list
/// reads it with [FloatingNavBar.bottomClearance], and everything inside gets a
/// `MediaQuery` with no bottom padding, as if the bar were not there. Lists and
/// grids added to a page later need no special care.
class FloatingNavBarScope extends StatelessWidget {
  final Widget child;
  const FloatingNavBarScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) => _NavBarInset(
    inset: MediaQuery.paddingOf(context).bottom,
    child: MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: child,
    ),
  );
}

class _NavBarInset extends InheritedWidget {
  final double inset;
  const _NavBarInset({required this.inset, required super.child});

  static double? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_NavBarInset>()?.inset;

  @override
  bool updateShouldNotify(_NavBarInset old) => inset != old.inset;
}
