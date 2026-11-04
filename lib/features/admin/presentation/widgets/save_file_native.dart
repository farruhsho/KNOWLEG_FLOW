import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Native save: Android/iOS write [bytes] through the system picker; desktop
/// pickers only return a path, so the file is written here.
Future<bool> saveBytes(String fileName, Uint8List bytes) async {
  final path = await FilePicker.platform.saveFile(fileName: fileName, bytes: bytes);
  if (path == null) return false;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
  return true;
}
