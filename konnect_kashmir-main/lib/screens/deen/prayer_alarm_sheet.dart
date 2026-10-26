import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../l10n/l10n.dart';
import '../../services/prayer_alarm/prayer_alarm_planner.dart';
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

/// The master switch, one switch per prayer, and what is stopping the alarms
/// (if anything), with the button that fixes it.
class PrayerAlarmSheet extends StatefulWidget {
  final PrayerAlarmService service;
  const PrayerAlarmSheet({super.key, required this.service});

  @override
  State<PrayerAlarmSheet> createState() => _PrayerAlarmSheetState();
}

class _PrayerAlarmSheetState extends State<PrayerAlarmSheet> {
  PrayerAlarmService get _svc => widget.service;
  PrayerAlarmPrefs _prefs = const PrayerAlarmPrefs();
  bool _loaded = false;
  bool _busy = false;

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
    if (mounted) setState(() {});
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

  Future<void> _run(Future<Object?> Function() action) async {
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
    setState(() => _prefs = _prefs.copyWith(enabled: on));
    await _run(() => _svc.setEnabled(on));
  }

  Future<void> _prayer(Prayer p, bool on) async {
    setState(() => _prefs = _prefs.withPrayer(p, on));
    await _run(() => _svc.setPrayer(p, on));
  }

  static const _icons = <Prayer, IconData>{
    Prayer.fajr: Icons.wb_twilight_rounded,
    Prayer.dhuhr: Icons.wb_sunny_rounded,
    Prayer.asr: Icons.brightness_medium_rounded,
    Prayer.maghrib: Icons.nights_stay_rounded,
    Prayer.isha: Icons.dark_mode_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final st = _svc.status.value;
    final names = {
      Prayer.fajr: l.prayerFajr,
      Prayer.dhuhr: l.prayerDhuhr,
      Prayer.asr: l.prayerAsr,
      Prayer.maghrib: l.prayerMaghrib,
      Prayer.isha: l.prayerIsha,
    };
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
          const SizedBox(height: 6),
          Text(
            l.prayerAlarmsSubtitle,
            style: TextStyle(fontSize: AppText.secondary, color: muted),
          ),
          const SizedBox(height: 16),
          _switchRow(
            icon: Icons.notifications_active_rounded,
            label: l.prayerAlarmsMaster,
            value: on,
            onChanged: _loaded && !_busy ? _master : null,
            strong: true,
          ),
          // Under the switch, on or off: the alarms are planned for a limited
          // number of days and need the app to be opened to carry on.
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 32,
              top: 2,
              bottom: 6,
            ),
            child: Text(
              l.prayerAlarmValidDays(_svc.windowDays),
              style: TextStyle(fontSize: AppText.caption, color: muted),
            ),
          ),
          if (on) ...[
            const SizedBox(height: 4),
            for (final p in Prayer.values)
              _switchRow(
                icon: _icons[p]!,
                label: names[p]!,
                value: _prefs.prayers.contains(p),
                onChanged: _loaded && !_busy ? (v) => _prayer(p, v) : null,
              ),
            const SizedBox(height: 8),
            ..._issues(st, l),
            if (st.through != null && st.scheduled > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  l.prayerAlarmSetThrough(
                    DateFormat.yMMMMd(locale).format(st.through!.toLocal()),
                  ),
                  style: TextStyle(fontSize: AppText.caption, color: muted),
                ),
              ),
            const SizedBox(height: 4),
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
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// A short note for each thing that is stopping the alarms, with its fix.
  List<Widget> _issues(PrayerAlarmStatus st, AppLocalizations l) {
    final out = <Widget>[];
    void note(String text, List<Widget> actions) =>
        out.add(_Note(text: text, actions: actions));

    if (st.issues.contains(PrayerAlarmIssue.notificationsBlocked)) {
      note(l.prayerAlarmNotifBlocked, [
        TextButton(
          onPressed: _busy ? null : () => _run(() => _svc.requestPermissions()),
          child: Text(l.prayerAlarmAllowNotifications),
        ),
        TextButton(
          onPressed: _svc.openSystemSettings,
          child: Text(l.prayerAlarmOpenSettings),
        ),
      ]);
    }
    if (st.issues.contains(PrayerAlarmIssue.exactAlarmsOff)) {
      note(l.prayerAlarmExactOff, [
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(() => _svc.requestPermissions(exactAlarms: true)),
          child: Text(l.prayerAlarmAllowExact),
        ),
      ]);
    }
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
  const _Note({required this.text, required this.actions});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5A623).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: const Color(0xFFF5A623).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(fontSize: AppText.secondary, color: cs.onSurface),
          ),
          if (actions.isNotEmpty) Wrap(spacing: 4, children: actions),
          if (actions.isEmpty) const SizedBox(height: 6),
        ],
      ),
    );
  }
}
