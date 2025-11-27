import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

/// Network connectivity service
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  bool _isOnline = true;
  final _controller = StreamController<bool>.broadcast();

  /// Stream of connectivity status
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Current connectivity status
  bool get isOnline => _isOnline;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);

    // Listen to connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);
      
      if (wasOnline != _isOnline) {
        _controller.add(_isOnline);
      }
    });
  }

  /// Check if device has internet connection
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Get connection type
  Future<String> getConnectionType() async {
    final result = await _connectivity.checkConnectivity();
    
    if (result.contains(ConnectivityResult.wifi)) {
      return 'WiFi';
    } else if (result.contains(ConnectivityResult.mobile)) {
      return 'Mobile Data';
    } else if (result.contains(ConnectivityResult.ethernet)) {
      return 'Ethernet';
    } else {
      return 'Offline';
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
