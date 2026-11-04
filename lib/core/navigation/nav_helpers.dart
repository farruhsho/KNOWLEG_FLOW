import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes/route_paths.dart';

/// Safe back navigation (NAV-02 / UI-04): pops when there is something to
/// pop, otherwise goes to [fallback] instead of throwing
/// `GoError('There is nothing to pop')`.
void safePop(BuildContext context, {String fallback = RoutePaths.home}) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
  } else {
    router.go(fallback);
  }
}

extension SafeNavigationX on BuildContext {
  /// See [safePop].
  void popOrGo({String fallback = RoutePaths.home}) =>
      safePop(this, fallback: fallback);
}

/// Wraps full-screen pages that live on the root navigator. When such a page
/// was opened with `go()` it is the only page in the stack; Android back
/// would then close the app. This guard sends the user to [fallback] (home)
/// instead.
class RootBackGuard extends StatelessWidget {
  const RootBackGuard({
    super.key,
    required this.child,
    this.fallback = RoutePaths.home,
  });

  final Widget child;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        GoRouter.of(context).go(fallback);
      },
      child: child,
    );
  }
}

/// A back button that never throws: pops, or goes to [fallback].
class SafeBackButton extends StatelessWidget {
  const SafeBackButton({super.key, this.fallback = RoutePaths.home});

  final String fallback;

  @override
  Widget build(BuildContext context) {
    return BackButton(onPressed: () => safePop(context, fallback: fallback));
  }
}
