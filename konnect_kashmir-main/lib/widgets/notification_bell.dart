import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../screens/notifications_screen.dart';
import '../services/notifications/inbox_service.dart';
import '../theme/app_theme.dart';

/// The bell in the header: with the number of unread notifications on it, and a
/// tap that opens the list. It is not drawn at all while the user is signed out
/// or the server has no notifications.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with WidgetsBindingObserver {
  /// The notifications of this app, or null on a screen that has none (the bell
  /// then draws nothing, instead of failing).
  InboxController? _inbox({bool listen = false}) {
    try {
      return Provider.of<InboxController>(context, listen: listen);
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ask once the screen is up; the controller does not ask more than every 20 s.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inbox()?.refreshUnread();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _inbox()?.refreshUnread();
    }
  }

  Future<void> _open() async {
    final inbox = _inbox();
    if (inbox == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
    inbox.refreshUnread(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final inbox = _inbox(listen: true);
    if (inbox == null || !inbox.visible) return const SizedBox.shrink();
    final l = context.l10n;
    final unread = inbox.unread;
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: unread > 0
          ? '${l.notificationsTitle}, ${l.notificationsUnread(unread)}'
          : l.notificationsTitle,
      excludeSemantics: true,
      child: Tooltip(
        message: l.notificationsTitle,
        excludeFromSemantics: true,
        child: InkResponse(
          onTap: _open,
          radius: 24,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(
                  unread > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  size: 26,
                  color: unread > 0
                      ? AppColors.primary
                      : cs.onSurface.withValues(alpha: 0.75),
                ),
                if (unread > 0)
                  PositionedDirectional(
                    top: 3,
                    end: 1,
                    child: _CountBadge(unread),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge(this.count);

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: AppColors.baseBg(Theme.of(context)),
          width: 1.5,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          height: 1.1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
