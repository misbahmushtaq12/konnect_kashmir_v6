import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/screens/ad_watch_dialog.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void main() {
  testWidgets('the ad video has no YouTube progress line and cannot be touched',
      (tester) async {
    // A phone held upright (the ad is portrait-only).
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: AdWatchDialog(ad: const {
        'url': 'https://youtu.be/XFjYIXqWX-4?si=Cx2uAQnI2FBRrkU4',
        'title': 'An ad',
        'credits_reward': 2,
      }),
    ));
    await tester.pump();
    // The web view behind the player does not exist in tests; ignore that error.
    tester.takeException();

    final player = tester.widget<YoutubePlayer>(find.byType(YoutubePlayer));

    // The red line YouTube draws at the bottom of the video is off.
    expect(player.showVideoProgressIndicator, isFalse);
    // No YouTube controls, no seeking by touch, no fullscreen button.
    expect(player.controller.flags.hideControls, isTrue);
    expect(player.controller.flags.disableDragSeek, isTrue);
    expect(player.controller.flags.showLiveFullscreenButton, isFalse);

    // Touches do not reach the video: an IgnorePointer that really ignores sits
    // above it.
    expect(
      find.ancestor(
        of: find.byType(YoutubePlayer),
        matching: find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring),
      ),
      findsOneWidget,
    );

    // The close button is outside that area and still works.
    expect(find.byIcon(Icons.close), findsOneWidget);
    final closeInsideLock = find.descendant(
      of: find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring),
      matching: find.byIcon(Icons.close),
    );
    expect(closeInsideLock, findsNothing);
  });
}
