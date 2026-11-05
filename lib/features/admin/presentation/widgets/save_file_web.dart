import 'dart:typed_data';

import 'package:universal_html/html.dart' as html;

/// Web save: browser download of an object URL.
Future<bool> saveBytes(String fileName, Uint8List bytes) async {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
  html.AnchorElement(href: url)
    ..download = fileName
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}
