# Prayer-time beeps

A short beep at Fajr, Dhuhr, Asr, Maghrib and Isha, worked out and kept **on the phone**.
No backend, no push message and no internet are involved when a beep sounds.

Code: `lib/services/prayer_alarm/` (service, planner, scheduler, calendar, background upkeep),
settings screen `lib/screens/deen/prayer_alarm_sheet.dart` (the bell on the Deen prayer card).

## How it works

1. The prayer times for the current and next month come from Aladhan's `/calendar` endpoint, for the
   place and the user's madhhab and calculation method, and are saved on the phone
   (`prayer_cal_*` keys). Older months are removed.
2. The next **10 days** (today is the first) of the switched-on prayers become local notifications
   (`flutter_local_notifications`, `zonedSchedule`). The operating system keeps them and fires them with
   the app closed.
3. Each time the app opens or comes back to the front (at most every 10 minutes), when a prayer setting,
   the language or a switch changes, and when the user taps *Refresh alarms*, the window is moved forward:
   alarms that are already right stay, wrong or old ones are cancelled, missing ones are added.
4. Times are read on the clock of the place Aladhan used (its `meta.timezone`), so daylight saving and
   month and year ends are handled; a time that is earlier than the prayer before it (far-north Isha after
   midnight) is moved to the next morning. Nothing in the past is ever scheduled.

## Notification ids and what is touched

Every prayer alarm has the id `1 500 000 000 + days-since-1970 × 8 + prayer index`, inside the block
`[1 500 000 000, 1 501 000 000)`. Planning twice cannot create duplicates, and only ids in that block are
ever cancelled or counted as ours. Other notifications are never cancelled.

## Capacity

* **iOS** keeps only 64 pending notifications for the whole app. The room for prayer alarms is
  `64 − (other pending notifications) − 14 (reserve)`, never more than the window needs (50 for ten days
  of five prayers). The soonest alarms are the ones kept.
* **Android** has no small limit; at most 100 prayer alarms are planned (the window needs 50).

## Defaults

The master switch is **off** for everyone (nobody is opted in by an update). The five prayer switches are
on, so switching the master on gives all five. Turning it on asks for the notification permission and, if
no place is known yet, for the location.

## If the app is never opened again

The alarms already on the phone keep firing until the last planned one (about ten days after the last time
the app ran). After that **nothing on the phone can add more**:

* **Android:** WorkManager runs a top-up about every 12 hours (the system decides exactly when; it can be
  delayed or skipped by battery savers and some phone makers, and it does not run after a force stop). It
  uses the saved place and the saved prayer times, and downloads next month's if it can.
* **iOS:** there is no dependable background job, so nothing tops the alarms up until the app is opened.

This is deliberate: no backend scheduler is used to hide the limit.

## Android

* Permissions: `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM` (plus the existing notification and
  location ones). The foreground-service permissions that the `workmanager` package adds are removed in
  the manifest (`tools:node="remove"`); the app only runs short periodic jobs.
* Exact alarms (Android 12+) need the user to allow *Alarms & reminders*; the settings sheet offers it.
  Without it the beeps are still scheduled, but the system may deliver them a few minutes late.
* Restart and app update: the plugin's `ScheduledNotificationBootReceiver` puts the alarms back; the next
  app open or background top-up then brings the window up to date.
* Channel `konnect_prayer_v1` (sound `res/raw/prayer_beep.wav`, kept from the resource shrinker by
  `res/raw/keep.xml`). **A channel's sound cannot change once created**: to change the beep, add the file,
  raise the channel id (`konnect_prayer_v2`), put the old id in `kLegacyPrayerChannelIds` (it is deleted on
  the next launch). Users who switched the old channel off will have to switch the new one on.
* Time-zone and clock changes: the alarms are absolute moments, so they stay right while the user stays
  where they are. A new time zone or place is noticed the next time the app runs (app open, or the
  background top-up for the zone offset) and the alarms are planned again.

## iOS

* Sound `ios/Runner/prayer_beep.wav` (registered in the Xcode project as a resource; 0.9 seconds, well
  under the 30 second limit). `AppDelegate.swift` sets the notification-centre delegate so a beep also
  shows and sounds while the app is open.
* There is no reboot receiver; notifications scheduled with the system survive a restart.
* Nothing runs after the app is closed, so the window only moves forward when the app is opened.

## What a beep cannot do

It follows the phone's volume, silent switch, Focus / Do Not Disturb and the notification settings of the
app and the channel. It does not try to override any of them.

## Tests

`flutter test test/prayer_alarm_planner_test.dart test/prayer_calendar_test.dart
test/prayer_alarm_service_test.dart test/prayer_alarm_sheet_test.dart`
