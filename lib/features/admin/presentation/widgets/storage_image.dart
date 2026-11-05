import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../application/admin_providers.dart';
import '../../domain/lesson_doc.dart' show isHttpUrl;

/// Thumbnail for a Storage path (or plain URL) with loading and error states.
class StorageImage extends ConsumerStatefulWidget {
  const StorageImage(this.pathOrUrl, {super.key, this.size = 96});
  final String pathOrUrl;
  final double size;

  @override
  ConsumerState<StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends ConsumerState<StorageImage> {
  late Future<String> _url = _resolve();

  Future<String> _resolve() => isHttpUrl(widget.pathOrUrl)
      ? Future.value(widget.pathOrUrl)
      : ref.read(mediaRepoProvider).downloadUrl(widget.pathOrUrl);

  @override
  void didUpdateWidget(covariant StorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pathOrUrl != widget.pathOrUrl) _url = _resolve();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: context.tokens.surfaceMuted, borderRadius: AppRadii.smAll),
      alignment: Alignment.center,
    );
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snap) {
        if (snap.hasError) {
          return Stack(alignment: Alignment.center, children: [
            placeholder,
            Icon(Icons.broken_image_outlined, color: context.tokens.textTertiary),
          ]);
        }
        if (!snap.hasData) {
          return Stack(alignment: Alignment.center, children: [
            placeholder,
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ]);
        }
        return ClipRRect(
          borderRadius: AppRadii.smAll,
          child: Image.network(
            snap.data!,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Stack(alignment: Alignment.center, children: [
              placeholder,
              Icon(Icons.broken_image_outlined, color: context.tokens.textTertiary),
            ]),
          ),
        );
      },
    );
  }
}
