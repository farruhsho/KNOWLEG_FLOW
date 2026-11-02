import 'package:cloud_firestore/cloud_firestore.dart';

/// Why loading learning data failed, so the UI can show a human message
/// with a retry instead of fabricated content (FB-15, CMS-09).
enum DataFailure { offline, permissionDenied, notFound, unknown }

class DataException implements Exception {
  final DataFailure failure;
  final Object? cause;
  const DataException(this.failure, [this.cause]);

  factory DataException.from(Object error) {
    if (error is DataException) return error;
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
        case 'deadline-exceeded':
          return DataException(DataFailure.offline, error);
        case 'permission-denied':
        case 'unauthenticated':
          return DataException(DataFailure.permissionDenied, error);
        case 'not-found':
          return DataException(DataFailure.notFound, error);
      }
    }
    return DataException(DataFailure.unknown, error);
  }

  @override
  String toString() => 'DataException($failure, $cause)';
}
