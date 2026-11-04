import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'save_file_web.dart' if (dart.library.io) 'save_file_native.dart' as impl;

typedef PickedFile = ({String name, Uint8List bytes});

/// Raster formats storage.rules accepts (`FileType.image` would also offer
/// SVG, which the rules refuse — AUTH-ADM-08).
const List<String> kPickableImageExtensions = ['png', 'jpg', 'jpeg', 'webp', 'gif'];

/// Picks one file and returns its bytes (works on web, mobile and desktop).
/// `images: true` limits the picker to [kPickableImageExtensions].
Future<PickedFile?> pickFileBytes({List<String>? extensions, bool images = false}) async {
  final allowed = images ? kPickableImageExtensions : extensions;
  final result = await FilePicker.platform.pickFiles(
    type: allowed == null ? FileType.any : FileType.custom,
    allowedExtensions: allowed,
    withData: true,
  );
  final file = result?.files.singleOrNull;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  return (name: file.name, bytes: bytes);
}

/// Saves [bytes] as a user-visible file. Returns `false` when cancelled.
Future<bool> saveFileBytes(String fileName, Uint8List bytes) => impl.saveBytes(fileName, bytes);
