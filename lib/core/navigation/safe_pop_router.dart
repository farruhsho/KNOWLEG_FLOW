import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'route_guards.dart';

/// A [GoRouter] whose [pop] never throws (UI-04 / NAV-02).
///
/// Many feature pages still open drill-downs with `context.go()` and close
/// them with `context.pop()`. After a `go()` the page is the only one in the
/// stack and go_router throws `GoError('There is nothing to pop')`. This
/// router pops when it can and otherwise goes to the logical parent location
/// ([RouteGuards.popFallback]), so every existing back/close button keeps
/// working whichever way the page was opened.
class SafePopGoRouter extends GoRouter {
  SafePopGoRouter._(
    this._config, {
    required super.errorBuilder,
    required super.refreshListenable,
    required super.initialLocation,
    required super.observers,
    required super.debugLogDiagnostics,
    required super.navigatorKey,
  }) : super.routingConfig(routingConfig: _config);

  /// Same arguments as the [GoRouter] default constructor (the subset the
  /// app uses).
  factory SafePopGoRouter({
    required List<RouteBase> routes,
    GoRouterRedirect? redirect,
    GoRouterWidgetBuilder? errorBuilder,
    Listenable? refreshListenable,
    String? initialLocation,
    List<NavigatorObserver>? observers,
    bool debugLogDiagnostics = false,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return SafePopGoRouter._(
      ValueNotifier<RoutingConfig>(
        redirect == null
            ? RoutingConfig(routes: routes)
            : RoutingConfig(routes: routes, redirect: redirect),
      ),
      errorBuilder: errorBuilder,
      refreshListenable: refreshListenable,
      initialLocation: initialLocation,
      observers: observers,
      debugLogDiagnostics: debugLogDiagnostics,
      navigatorKey: navigatorKey,
    );
  }

  final ValueNotifier<RoutingConfig> _config;

  /// Path of the page currently on top.
  String get currentPath {
    try {
      return routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return '/';
    }
  }

  @override
  void pop<T extends Object?>([T? result]) {
    if (canPop()) {
      try {
        super.pop<T>(result);
        return;
      } on GoError catch (e) {
        debugPrint('pop() fell back to go(): $e');
      }
    }
    go(RouteGuards.popFallback(currentPath));
  }

  @override
  void dispose() {
    super.dispose();
    _config.dispose();
  }
}
