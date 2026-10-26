import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'prayer_alarm_service.dart';

const String kPrayerMaintenanceName = 'konnect_prayer_alarm_topup';
const String kPrayerMaintenanceTask = 'prayerAlarmTopUp';

/// Runs in a background isolate started by Android's WorkManager.
///
/// It only tops the alarms up (plans from the saved place and the saved prayer
/// times, downloading next month's if it can). It never relies on being run at a
/// particular time: the alarms themselves are already on the phone and fire
/// without this.
@pragma('vm:entry-point')
void prayerAlarmCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await PrayerAlarmService.instance.refresh(
        reason: 'background',
        foreground: false,
      );
    } catch (e) {
      debugPrint('[PrayerAlarm] background top-up failed: $e');
    }
    // Always "done": a failure is simply tried again at the next run, not retried
    // in a loop.
    return true;
  });
}

/// Android only. WorkManager runs the top-up about every 12 hours (when the
/// system decides, so only roughly), also after a restart, for as long as at
/// least one prayer alarm is switched on.
///
/// iOS has no equivalent that can be relied on, so nothing is registered there:
/// on iOS the window moves forward only when the app is opened.
class AndroidPrayerAlarmMaintenance implements PrayerAlarmMaintenance {
  bool _initialised = false;
  static const _registeredKey = 'prayer_alarm_worker_registered';

  @override
  Future<void> sync({required bool enabled}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final wm = Workmanager();
    final prefs = await SharedPreferences.getInstance();
    if (!enabled) {
      // Nothing to undo for someone who never switched the alarms on.
      if (prefs.getBool(_registeredKey) ?? false) {
        await wm.cancelByUniqueName(kPrayerMaintenanceName);
        await prefs.setBool(_registeredKey, false);
      }
      return;
    }
    if (!_initialised) {
      await wm.initialize(prayerAlarmCallbackDispatcher);
      _initialised = true;
    }
    await wm.registerPeriodicTask(
      kPrayerMaintenanceName,
      kPrayerMaintenanceTask,
      frequency: const Duration(hours: 12),
      // Not at once: the app has just planned the alarms itself, and a second run
      // starting at the same moment would only repeat that work.
      initialDelay: const Duration(hours: 12),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
    await prefs.setBool(_registeredKey, true);
  }
}
