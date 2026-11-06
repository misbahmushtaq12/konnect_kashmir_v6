import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/notifications/inbox_service.dart';
import '../theme/app_theme.dart';
import '../widgets/error_retry.dart';
import 'main_shell.dart';

/// The user's notifications, newest first. Tapping one marks it read; "Mark all as
/// read" clears the bell.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<InboxController>().load();
    });
  }

  void _tap(AppNotification n) {
    final inbox = context.read<InboxController>();
    inbox.markRead(n);
    // A message about a photo is about the owner's business: take them there.
    if (n.kind.isPhoto && MainShell.isShowing) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      MainShell.tabRequest.value = MainShell.tabMyBusiness;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final inbox = context.watch<InboxController>();
    return Scaffold(
      appBar: AppBar(title: Text(l.notificationsTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          // On a tablet or a wide window the list keeps a readable width.
          constraints: const BoxConstraints(maxWidth: 680),
          child: _body(context, inbox),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, InboxController inbox) {
    final l = context.l10n;
    if (inbox.items.isEmpty) {
      if (inbox.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (inbox.loadFailed) {
        return ErrorRetry(offline: true, onRetry: inbox.load);
      }
      return RefreshIndicator(
        onRefresh: inbox.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 56,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.noNotificationsYet,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: AppText.heading,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.noNotificationsBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppText.body,
                      height: 1.4,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: inbox.load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: inbox.items.length + (inbox.unread > 0 ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          // The first row is "Mark all as read" (its text may wrap, so it fits any
          // language and text size).
          if (inbox.unread > 0 && index == 0) {
            return Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: inbox.markAllRead,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: AppColors.primary,
                ),
                child: Text(l.markAllRead, textAlign: TextAlign.center),
              ),
            );
          }
          final i = inbox.unread > 0 ? index - 1 : index;
          final n = inbox.items[i];
          return _Tile(
            key: ValueKey<String>('notification-${n.id}'),
            notification: n,
            onTap: () => _tap(n),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _Tile({super.key, required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final n = notification;
    final (icon, color) = switch (n.kind) {
      InboxKind.photoPending => (
        Icons.hourglass_top_rounded,
        AppColors.warning,
      ),
      InboxKind.photoApproved => (
        Icons.check_circle_rounded,
        AppColors.success,
      ),
      InboxKind.photoRejected => (Icons.error_rounded, AppColors.danger),
      InboxKind.other => (Icons.notifications_rounded, AppColors.primary),
    };
    final unread = !n.isRead;

    return Semantics(
      button: true,
      container: true,
      label: '${n.title}. ${n.body}',
      child: ExcludeSemantics(
        child: Material(
          color: unread
              ? AppColors.primary.withValues(alpha: dark ? 0.14 : 0.08)
              : cs.onSurface.withValues(alpha: dark ? 0.05 : 0.035),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.16),
                      ),
                      child: Icon(icon, size: 22, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            style: TextStyle(
                              fontSize: AppText.body,
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          if (n.body.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              n.body,
                              style: TextStyle(
                                fontSize: AppText.secondary,
                                height: 1.35,
                                color: cs.onSurface.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            timeAgo(context.l10n, n.createdAt),
                            style: TextStyle(
                              fontSize: AppText.caption,
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          key: const ValueKey<String>('unread-dot'),
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
