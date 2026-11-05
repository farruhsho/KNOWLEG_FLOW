import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Turns a question's image reference into a downloadable URL. Plain
/// http(s) URLs pass through; Storage paths (`exam_media/{questionId}/…`,
/// what the exam callables send as `imagePath`) are resolved with Firebase
/// Storage. Overridable in tests.
typedef ExamImageUrlResolver = Future<String?> Function(String reference);

/// Looks up the download URL of a Storage path (or `gs://` URL).
typedef StorageDownloadUrl = Future<String> Function(String path);

Future<String> _firebaseDownloadUrl(String path) {
  final ref = path.startsWith('gs://')
      ? FirebaseStorage.instance.refFromURL(path)
      : FirebaseStorage.instance.ref(path);
  return ref.getDownloadURL();
}

/// [ExamImageUrlResolver] that memoizes download URLs per Storage path for
/// the lifetime of the app (contract D3), so paging back and forth through
/// a section does not repeat Storage lookups. Failed lookups are not cached:
/// the next call (e.g. "tap to retry") asks Storage again.
class CachingExamImageUrlResolver {
  final StorageDownloadUrl _downloadUrl;
  final Map<String, Future<String?>> _cache = {};

  CachingExamImageUrlResolver([StorageDownloadUrl? downloadUrl])
      : _downloadUrl = downloadUrl ?? _firebaseDownloadUrl;

  /// Number of cached references (diagnostics / tests).
  int get cachedCount => _cache.length;

  Future<String?> call(String reference) {
    final ref = reference.trim();
    if (ref.isEmpty) return Future.value(null);
    if (ref.startsWith('http://') || ref.startsWith('https://')) {
      return Future.value(ref);
    }
    final path = ref.startsWith('gs://') ? ref : ref.replaceFirst(RegExp('^/+'), '');
    final cached = _cache[path];
    if (cached != null) return cached;
    final future = _downloadUrl(path).then<String?>((u) => u);
    _cache[path] = future;
    future.then<void>((_) {}, onError: (Object _) {
      // Only drop this attempt (a newer retry may already be cached).
      if (identical(_cache[path], future)) _cache.remove(path);
    });
    return future;
  }
}

final examImageUrlResolverProvider = Provider<ExamImageUrlResolver>(
    (ref) => CachingExamImageUrlResolver().call);

/// Download URL of one image reference. Auto-disposed: the URL itself stays
/// in the resolver's cache, and an error is retried when the image is shown
/// again (or on tap, see `ExamImage`).
final examImageUrlProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, reference) {
  return ref.watch(examImageUrlResolverProvider)(reference);
});
