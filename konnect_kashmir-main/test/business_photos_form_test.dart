import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konnect_kashmir/l10n/l10n.dart';
import 'package:konnect_kashmir/providers/auth_provider.dart';
import 'package:konnect_kashmir/screens/vendor_screen.dart';
import 'package:konnect_kashmir/services/business_photos/business_photo_service.dart';
import 'package:konnect_kashmir/services/business_photos/business_photos_controller.dart';
import 'package:konnect_kashmir/services/business_photos/photo_picker.dart';
import 'package:konnect_kashmir/services/business_photos/photo_processor.dart';
import 'package:konnect_kashmir/widgets/business_photos_section.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_photo_backend.dart';
import 'support/fake_photo_images.dart';

/// Holds a photo back until [release] is called, so a test can look at the form
/// while photos are being prepared.
class _SlowProcessor implements PhotoProcessor {
  final Completer<void> gate = Completer<void>();
  final FakePhotoProcessor inner = FakePhotoProcessor();

  @override
  Future<ProcessedPhoto> process({
    required String fileName,
    required Uint8List bytes,
  }) async {
    await gate.future;
    return inner.process(fileName: fileName, bytes: bytes);
  }

  void release() => gate.complete();
}

Widget _app(Widget home) => ChangeNotifierProvider(
  create: (_) => AuthProvider(),
  child: MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  ),
);

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

PickedPhoto _pick(String name) =>
    PickedPhoto(name: name, length: 4096, read: () async => Uint8List(4096));

void main() {
  late FakePhotoBackend backend;
  late BusinessPhotoService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BusinessPhotoService.clearCache();
    backend = FakePhotoBackend();
    service = BusinessPhotoService(backend: backend, newId: () => 'id1');
  });

  BusinessPhotosController controller({
    String? vendorId,
    PhotoProcessor? processor,
    List<PickedPhoto> pick = const [],
  }) => BusinessPhotosController(
    vendorId: vendorId,
    service: service,
    processor: processor ?? FakePhotoProcessor(),
    picker: (_) async => pick,
  );

  testWidgets('List Your Business: the photos section sits after the '
      'description and before the contact details', (tester) async {
    await FakePhotoImages.install(tester);
    _tallScreen(tester);
    await tester.pumpWidget(
      _app(ListBusinessScreen(photosController: controller())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('List Your Business'), findsOneWidget);
    expect(find.text('Business Photos'), findsOneWidget);
    expect(find.text('Optional'), findsOneWidget);
    expect(
      find.text('Add up to 20 photos to showcase your business'),
      findsOneWidget,
    );
    expect(find.text('Photos (0/20)'), findsOneWidget);
    expect(find.text('Add photos'), findsOneWidget);

    final description = tester.getTopLeft(
      find.text('Business Description (optional)'),
    );
    final photos = tester.getTopLeft(find.text('Business Photos'));
    final contact = tester.getTopLeft(find.text('Contact Info'));
    expect(photos.dy, greaterThan(description.dy));
    expect(photos.dy, lessThan(contact.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit Business has the same section, with the photos it has', (
    tester,
  ) async {
    await FakePhotoImages.install(tester);
    _tallScreen(tester);
    for (var i = 0; i < 3; i++) {
      backend.seed('v1', sortOrder: i, file: 'p$i.webp');
    }
    final c = controller(vendorId: 'v1');
    await c.load();
    await tester.pumpWidget(
      _app(
        ListBusinessScreen(
          existingVendor: const {'id': 'v1', 'business_name': 'Test Shop'},
          photosController: c,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Edit Business'), findsOneWidget);
    expect(find.byType(BusinessPhotosSection), findsOneWidget);
    expect(find.text('Photos (3/20)'), findsOneWidget);
    expect(find.byTooltip('Delete photo'), findsNWidgets(3));
    expect(find.text('Save changes'), findsOneWidget);
    expect(
      find.text('Your photos are uploaded when you submit.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Submit waits while photos are being prepared', (tester) async {
    await FakePhotoImages.install(tester);
    _tallScreen(tester);
    final slow = _SlowProcessor();
    final c = controller(processor: slow, pick: [_pick('a.jpg')]);
    await tester.pumpWidget(_app(ListBusinessScreen(photosController: c)));
    await tester.pump(const Duration(milliseconds: 100));

    ElevatedButton submit() => tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Submit'),
    );
    expect(submit().onPressed, isNotNull);

    await tester.tap(find.text('Add photos'));
    await tester.pump();
    expect(c.busy, isTrue);
    expect(submit().onPressed, isNull);

    slow.release();
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.busy, isFalse);
    expect(submit().onPressed, isNotNull);
    expect(find.text('Photos (1/20)'), findsOneWidget);
  });

  testWidgets('the form still works as before around the photos', (
    tester,
  ) async {
    await FakePhotoImages.install(tester);
    _tallScreen(tester);
    await tester.pumpWidget(
      _app(ListBusinessScreen(photosController: controller())),
    );
    await tester.pump(const Duration(milliseconds: 100));
    for (final text in [
      'Business Name *',
      'Business Phone Number *',
      'Use my current location',
      'Home Service Available',
      'Accept Online Payment',
      'Your listing will be reviewed within 24-48 hours',
      'Cancel',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });
}
