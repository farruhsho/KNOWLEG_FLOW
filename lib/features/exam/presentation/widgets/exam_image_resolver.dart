import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Turns a question's image reference into a downloadable URL. Plain
/// http(s) URLs pass through; Storage paths (`exam_media/{questionId}/…`)
/// are resolved with Firebase Storage. Overridable in tests.
typedef ExamImageUrlResolver = Future<String?> Function(String reference);

final examImageUrlResolverProvider = Provider<ExamImageUrlResolver>((ref) {
  return (reference) async {
    if (reference.startsWith('http://') || reference.startsWith('https://')) {
      return reference;
    }
    final path = reference.startsWith('gs://')
        ? reference
        : reference.replaceFirst(RegExp('^/+'), '');
    final storageRef = path.startsWith('gs://')
        ? FirebaseStorage.instance.refFromURL(path)
        : FirebaseStorage.instance.ref(path);
    return storageRef.getDownloadURL();
  };
});

final examImageUrlProvider =
    FutureProvider.family<String?, String>((ref, reference) {
  return ref.watch(examImageUrlResolverProvider)(reference);
});
