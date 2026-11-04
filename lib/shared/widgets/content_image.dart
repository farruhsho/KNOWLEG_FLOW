import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// Image for learning content: an http(s) URL or a Firebase Storage path
/// (`lesson_media/...`, `exam_media/...`). Shows a quiet placeholder while
/// loading and on failure instead of a red error box.
class ContentImage extends StatefulWidget {
  final String source;
  final String? semanticLabel;

  const ContentImage({super.key, required this.source, this.semanticLabel});

  @override
  State<ContentImage> createState() => _ContentImageState();
}

class _ContentImageState extends State<ContentImage> {
  late Future<String?> _url;

  @override
  void initState() {
    super.initState();
    _url = _resolve(widget.source);
  }

  @override
  void didUpdateWidget(covariant ContentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _url = _resolve(widget.source);
  }

  static Future<String?> _resolve(String source) async {
    final s = source.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.isEmpty) return null;
    try {
      return await FirebaseStorage.instance.ref(s).getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: context.tokens.surfaceMuted, borderRadius: AppRadii.mdAll),
      child: Icon(Icons.image_outlined, color: context.tokens.textTertiary),
    );
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snap) {
        final url = snap.data;
        if (url == null) return placeholder;
        return ClipRRect(
          borderRadius: AppRadii.mdAll,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            semanticLabel: widget.semanticLabel,
            loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
            errorBuilder: (_, __, ___) => placeholder,
          ),
        );
      },
    );
  }
}
