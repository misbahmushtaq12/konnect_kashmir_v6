import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// A photo the owner chose in the gallery. The bytes are read only when needed,
/// after the size has been checked.
class PickedPhoto {
  final String name;
  final int length;
  final Future<Uint8List> Function() read;

  const PickedPhoto({
    required this.name,
    required this.length,
    required this.read,
  });

  /// A photo that is already in memory (for tests).
  PickedPhoto.bytes(this.name, Uint8List bytes)
    : length = bytes.length,
      read = (() async => bytes);
}

/// Opens the gallery so the owner can choose up to [limit] photos. An empty list
/// means nothing was chosen.
typedef PhotoPicker = Future<List<PickedPhoto>> Function(int limit);

/// The phone's own photo picker (on Android 13 and later it needs no permission;
/// on iPhone it is the system picker).
Future<List<PickedPhoto>> pickPhotosFromGallery(int limit) async {
  final picker = ImagePicker();
  // Several at once need a limit of at least 2.
  final List<XFile> files = limit >= 2
      ? await picker.pickMultiImage(limit: limit, requestFullMetadata: false)
      : [
          if (await picker.pickImage(
                source: ImageSource.gallery,
                requestFullMetadata: false,
              )
              case final XFile one)
            one,
        ];
  return [
    for (final f in files)
      PickedPhoto(name: f.name, length: await f.length(), read: f.readAsBytes),
  ];
}
