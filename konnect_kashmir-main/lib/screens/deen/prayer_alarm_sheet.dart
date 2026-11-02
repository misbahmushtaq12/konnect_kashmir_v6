import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/app_analytics.dart';
import '../../services/prayer_alarm/prayer_alarm_prefs.dart';
import '../../services/prayer_alarm/prayer_alarm_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_overlays.dart';

/// Opens the prayer-alarm settings. Completes with whether the alarms are on.
Future<bool> showPrayerAlarmSheet(
  BuildContext context, {
  PrayerAlarmService? service,
}) async {
  final svc = service ?? PrayerAlarmService.instance;
  await showAppSheet<void>(
    context: context,
    builder: (_) => PrayerAlarmSheet(service: svc),
  );
  return (await svc.prefs()).enabled;
}

/// The one switch for all five prayers, and what is stopping the alarms (if
/// anything), with the button that fixes it.
class PrayerAlarmSheet extends StatefulWidget {
  final PrayerAlarmService service;
  const PrayerAlarmSheet({super.key, required this.service});

  @override
  State<PrayerAlarmSheet> createState() => _PrayerAlarmSheetState();
}

class _PrayerAlarmSheetState extends State<PrayerAlarmSheet> {
  PrayerAlarmService get _svc => widget.service;
  bool get _android => Theme.of(context).platform == TargetPlatform.android;
  PrayerAlarmPrefs _prefs = const PrayerAlarmPrefs();
  bool _loaded = false;
  bool _busy = false;

  /// The beep was just turned on for real: shows the confirmation (until the sheet
  /// is closed or the beep is turned off).
  bool _confirmed = false;

  /// The permission the user was taken to the system screen for and came back
  /// without giving: only then does the note say it is still needed.
  PrayerAlarmPermission? _declinedOn;

  @override
  void initState() {
    super.initState();
    _svc.status.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    _svc.status.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      if (_svc.status.value.justEnabled) _confirmed = true;
    });
    // The beep can be switched on while the sheet is open (the user came back
    // from the system settings with the permission): show the switch as it is.
    _svc.prefs().then((p) {
      if (mounted && p.enabled != _prefs.enabled) setState(() => _prefs = p);
    });
  }

  Future<void> _load() async {
    final p = await _svc.prefs();
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _loaded = true;
    });
    // Show what is true right now (the permission may have changed in Settings).
    if (p.enabled) _run(() => _svc.refresh(reason: 'sheet opened'));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _master(bool on) async {
    if (!on) {
      setState(() {
        _prefs = _prefs.copyWith(enabled: false);
        _confirmed = false;
      });
      await _run(() => _svc.setEnabled(false));
      AppAnalytics.instance.prayerAlarm(enabled: false);
      return;
    }
    // The switch only turns on when the beep really can ring, so it is not shown
    // as on until then. Each missing permission is explained, and the user is
    // taken to the system screen for it: first notifications, then (Android)
    // exact alarms. Never more than those two, and never the same one twice.
    await _run(() async {
      var st = await _svc.setEnabled(true);
      for (var i = 0; i < 2; i++) {
        final need = st.missingPermission;
        if (need == null || !mounted) break;
        if (!await _explain(need)) {
          await _svc.cancelPendingEnable();
          break;
        }
        st = await _openScreenFor(need);
        if (st.missingPermission == need) break; // back without giving it
      }
    });
    final p = await _svc.prefs();
    if (p.enabled) AppAnalytics.instance.prayerAlarm(enabled: true);
    if (mounted) setState(() => _prefs = p);
  }

  /// Says why [need] is needed and asks whether to go and give it.
  Future<bool> _explain(PrayerAlarmPermission need) {
    final l = context.l10n;
    return switch (need) {
      PrayerAlarmPermission.notifications => showAppConfirm(
        context,
        title: l.prayerAlarmNotifDialogTitle,
        // Android also has the "Prayer alarms" category to switch on; iPhone has
        // Notifications and Sounds.
        message: _android
            ? l.prayerAlarmNotifDialogBodyAndroid
            : l.prayerAlarmNotifDialogBody,
        confirmLabel: l.prayerAlarmOpenSettings,
      ),
      PrayerAlarmPermission.exactAlarms => showAppConfirm(
        context,
        title: l.prayerAlarmExactDialogTitle,
        message: l.prayerAlarmExactDialogBody,
        confirmLabel: l.prayerAlarmGrantPermission,
      ),
    };
  }

  /// Takes the user to the system screen for [need] and returns when they are
  /// back; remembers whether they came back without giving it.
  Future<PrayerAlarmStatus> _openScreenFor(PrayerAlarmPermission need) async {
    final st = switch (need) {
      PrayerAlarmPermission.notifications =>
        await _svc.openNotificationSettings(),
      PrayerAlarmPermission.exactAlarms => await _svc.openExactAlarmSettings(),
    };
    if (mounted) {
      setState(() => _declinedOn = st.missingPermission == need ? need : null);
    }
    return st;
  }

  /// The note under the switch for the permission that stops the beep, with the
  /// button that fixes it. When the beep is on, it is one that was taken back
  /// (the beep resumes by itself once it is back); when it is off, it is the one
  /// that was asked for and not given.
  Widget? _permissionNote(PrayerAlarmStatus st, bool on, AppLocalizations l) {
    PrayerAlarmPermission? need;
    if (on) {
      if (st.issues.contains(PrayerAlarmIssue.notificationsBlocked)) {
        need = PrayerAlarmPermission.notifications;
      } else if (st.issues.contains(PrayerAlarmIssue.exactAlarmsOff)) {
        need = PrayerAlarmPermission.exactAlarms;
      }
    } else if (_declinedOn != null && st.missingPermission == _declinedOn) {
      need = _declinedOn;
    }
    if (need == null) return null;
    final missing = need;
    final notifications = missing == PrayerAlarmPermission.notifications;
    return _Note(
      text: notifications
          ? (_android
                ? l.prayerAlarmNotifBlockedAndroid
                : l.prayerAlarmNotifBlocked)
          : (on ? l.prayerAlarmExactOff : l.prayerAlarmExactStillNeeded),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => _run(() => _openScreenFor(missing)),
          child: Text(
            notifications
                ? l.prayerAlarmOpenSettings
                : (on ? l.prayerAlarmAllowExact : l.prayerAlarmGrantPermission),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final st = _svc.status.value;
    final muted = cs.onSurface.withValues(alpha: 0.65);
    final on = _prefs.enabled;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.prayerAlarms,
            style: const TextStyle(
              fontSize: AppText.title,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _switchRow(
            icon: Icons.notifications_active_rounded,
            label: l.prayerAlarmsMaster,
            value: on,
            onChanged: _loaded && !_busy ? _master : null,
            strong: true,
            warning: on && st.hasWarning,
            warningTooltip: st.needsPermission
                ? l.prayerAlarmWarningTooltip
                : l.prayerAlarmNotSetTooltip,
          ),
          // Right under the switch: the permission that stops the beep, with its button.
          if (_permissionNote(st, on, l) case final note?) note,
          // And why the alarms could not be set (no place, no prayer times, ...).
          if (on) ..._issues(st, l),
          // Only when the alarms really were set and nothing is wrong.
          if (on && _confirmed && st.issues.isEmpty && st.scheduled > 0)
            _Note(
              text: l.prayerAlarmEnabledConfirm,
              actions: const [],
              color: AppColors.success,
              icon: Icons.check_circle_rounded,
            ),
          // (How long the alarms last is not written here: the last two days' alarms
          // themselves ask the user to open the app, see planReminders.)
          if (on) ...[
            const SizedBox(height: 8),
            Text(
              l.prayerAlarmFooter,
              style: TextStyle(fontSize: AppText.caption, color: muted),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => _svc.refresh(reason: 'manual', askLocation: true),
                      ),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l.prayerAlarmRefresh),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.doneLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool strong = false,
    bool warning = false,
    String? warningTooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppText.body,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          if (warning)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: Tooltip(
                message: warningTooltip ?? '',
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 22,
                  color: AppColors.warning,
                ),
              ),
            ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// A short note for each other thing that is stopping the alarms, with its fix.
  List<Widget> _issues(PrayerAlarmStatus st, AppLocalizations l) {
    final out = <Widget>[];
    void note(String text, List<Widget> actions) =>
        out.add(_Note(text: text, actions: actions));

    if (st.issues.contains(PrayerAlarmIssue.noLocation)) {
      note(l.prayerAlarmNoLocation, [
        TextButton(
          onPressed: _svc.openSystemSettings,
          child: Text(l.prayerAlarmOpenSettings),
        ),
      ]);
    }
    if (st.issues.contains(PrayerAlarmIssue.noTimes)) {
      note(l.prayerAlarmNoTimes, const []);
    }
    if (st.issues.contains(PrayerAlarmIssue.noRoom)) {
      note(l.prayerAlarmNoRoom, const []);
    }
    if (st.issues.contains(PrayerAlarmIssue.failed)) {
      note(l.prayerAlarmFailed, const []);
    }
    return out;
  }
}

class _Note extends StatelessWidget {
  final String text;
  final List<Widget> actions;
  final Color color;
  final IconData? icon;
  const _Note({
    required this.text,
    required this.actions,
    this.color = const Color(0xFFF5A623),
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: AppText.secondary,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) Wrap(spacing: 4, children: actions),
          if (actions.isEmpty) const SizedBox(height: 6),
        ],
      ),
    );
  }
}
