import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/services/prayer_alarm/prayer_alarm_scheduler.dart';

AndroidNotificationChannel _channel({
  Importance importance = Importance.high,
  bool playSound = true,
}) => AndroidNotificationChannel(
  kPrayerChannelId,
  'Prayer alarms',
  importance: importance,
  playSound: playSound,
);

void main() {
  group('the Prayer alarms category in the phone\'s notification settings', () {
    test('a category that does not exist yet is fine: it is made right', () {
      expect(prayerChannelCanSound(null), isTrue);
    });

    test('as made by the app, it can sound', () {
      expect(prayerChannelCanSound(_channel()), isTrue);
      expect(
        prayerChannelCanSound(_channel(importance: Importance.defaultImportance)),
        isTrue,
        reason: 'no pop-up, but the sound still plays',
      );
    });

    test('switched off by the user: it cannot', () {
      expect(prayerChannelCanSound(_channel(importance: Importance.none)), isFalse);
    });

    test('made silent (low or minimum importance): it cannot', () {
      expect(prayerChannelCanSound(_channel(importance: Importance.low)), isFalse);
      expect(prayerChannelCanSound(_channel(importance: Importance.min)), isFalse);
    });

    test('its sound taken away: it cannot', () {
      expect(prayerChannelCanSound(_channel(playSound: false)), isFalse);
    });
  });
}
