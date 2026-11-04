import '../routes/route_paths.dart';

/// Pure redirect rules for the app router. They take plain values (path,
/// signed-in flag, admin flag) so they can be unit-tested without Firebase.
///
/// Evaluation order in [resolveRedirect]:
///   1. legacy literals still used by older pages ('/dashboard', …)
///   2. admin gate for /admin/*
///   3. student auth guard
abstract final class RouteGuards {
  /// Query parameter that carries the originally requested location through
  /// the login screen.
  static const fromParam = 'from';

  /// Locations a signed-out user may open.
  static const Set<String> publicPaths = {
    RoutePaths.splash,
    RoutePaths.onboarding,
    RoutePaths.login,
    RoutePaths.signup,
    RoutePaths.adminLogin,
  };

  /// Screens a signed-in user is bounced away from.
  static const Set<String> authOnlyPaths = {
    RoutePaths.login,
    RoutePaths.signup,
  };

  static String _normalize(String path) {
    if (path.isEmpty) return RoutePaths.splash;
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  /// Old string literals that pages still navigate to (NAV-01 / NAV-06).
  /// Returns the replacement location or null.
  static String? legacyRedirect(String rawPath) {
    final path = _normalize(rawPath);
    switch (path) {
      case '/dashboard':
        return RoutePaths.home;
      case '/subjects':
        return RoutePaths.learn;
      case '/lessons/daily':
        return RoutePaths.dailyLesson;
      case '/payments':
        return RoutePaths.store;
    }
    if (path.startsWith('/mock-test/') || path == '/mock-test') {
      return RoutePaths.exams;
    }
    return null;
  }

  static bool isAdminArea(String rawPath) {
    final path = _normalize(rawPath);
    return path == '/admin' || path.startsWith('/admin/');
  }

  /// SEC-003: every /admin/* screen except the admin login requires a
  /// signed-in user whose admin role was verified in this session.
  static String? adminGate(
    String rawPath, {
    required bool signedIn,
    required bool adminVerified,
  }) {
    final path = _normalize(rawPath);
    if (!isAdminArea(path) || path == RoutePaths.adminLogin) return null;
    if (!signedIn || !adminVerified) return RoutePaths.adminLogin;
    return null;
  }

  /// Student auth guard (NAV-04).
  ///
  /// * signed out → only [publicPaths]; anything else goes to login and the
  ///   requested location is kept in `?from=` so login can return there.
  /// * signed in → login/signup go to `from` (if it is a safe in-app
  ///   location) or home.
  static String? authGuard(Uri uri, {required bool signedIn}) {
    final path = _normalize(uri.path);
    if (isAdminArea(path)) return null; // handled by [adminGate]

    if (!signedIn) {
      if (publicPaths.contains(path)) return null;
      final from = uri.toString();
      if (path == RoutePaths.home) return RoutePaths.login;
      return Uri(
        path: RoutePaths.login,
        queryParameters: {fromParam: from},
      ).toString();
    }

    if (authOnlyPaths.contains(path)) {
      final from = uri.queryParameters[fromParam];
      return isSafeReturnLocation(from) ? from : RoutePaths.home;
    }
    return null;
  }

  /// A `from` value is followed only when it is an in-app path that is not
  /// an auth/entry screen (prevents loops and open redirects).
  static bool isSafeReturnLocation(String? location) {
    if (location == null || location.isEmpty) return false;
    if (!location.startsWith('/') || location.startsWith('//')) return false;
    final parsed = Uri.tryParse(location);
    if (parsed == null || parsed.hasScheme || parsed.hasAuthority) return false;
    final path = _normalize(parsed.path);
    if (publicPaths.contains(path)) return false;
    if (isAdminArea(path)) return false;
    return true;
  }

  /// The complete top-level redirect.
  static String? resolveRedirect(
    Uri uri, {
    required bool signedIn,
    required bool adminVerified,
  }) {
    final legacy = legacyRedirect(uri.path);
    if (legacy != null) return legacy;

    final admin = adminGate(
      uri.path,
      signedIn: signedIn,
      adminVerified: adminVerified,
    );
    if (admin != null) return admin;

    return authGuard(uri, signedIn: signedIn);
  }
}
