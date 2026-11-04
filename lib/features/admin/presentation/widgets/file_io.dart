import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'save_file_web.dart' if (dart.library.io) 'save_file_native.dart' as impl;

typedef PickedFile = ({String name, Uint8List bytes});

/// Picks one file and returns its bytes (works on web, mobile and desktop).
Future<PickedFile?> pickFileBytes({List<String>? extensions, bool images = false}) async {
  final result = await FilePicker.platform.pickFiles(
    type: images ? FileType.image : (extensions == null ? FileType.any : FileType.custom),
    allowedExtensions: images ? null : extensions,
    withData: true,
  );
  final file = result?.files.singleOrNull;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  return (name: file.name, bytes: bytes);
}

/// Saves [bytes] as a user-visible file. Returns `false` when cancelled.
Future<bool> saveFileBytes(String fileName, Uint8List bytes) => impl.saveBytes(fileName, bytes);
