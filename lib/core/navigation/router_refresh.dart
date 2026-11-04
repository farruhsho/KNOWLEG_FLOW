import 'dart:async';

import 'package:flutter/foundation.dart';

/// Turns a stream (e.g. `FirebaseAuth.authStateChanges()`) into a
/// [Listenable] that GoRouter can use as `refreshListenable`.
class StreamListenable extends ChangeNotifier {
  StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen(
      (_) => notifyListeners(),
      onError: (Object _) => notifyListeners(),
    );
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
