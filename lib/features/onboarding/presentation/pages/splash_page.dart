import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/navigation/boot_screens.dart';
import '../../../../core/network/firebase_service.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/onboarding_provider.dart';

/// Decides where a cold start goes. No artificial delay (BOOT-01): it waits
/// only for Firebase Auth to restore the session (with a timeout).
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<User?> _restoredUser() async {
    final auth = FirebaseService.auth;
    final current = auth.currentUser;
    if (current != null) return current;
    try {
      return await auth
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 4));
    } on TimeoutException {
      return auth.currentUser;
    }
  }

  Future<void> _route() async {
    User? user;
    try {
      user = await _restoredUser();
    } catch (e, s) {
      FirebaseService.recordNonFatal(e, s, reason: 'splash_auth_restore');
    }
    if (!mounted) return;

    if (user != null) {
      // Existing session: make sure the profile exists and pending
      // onboarding answers are saved — both in the background.
      final authService = ref.read(authServiceProvider);
      final onboarding = ref.read(onboardingServiceProvider);
      unawaited(authService.ensureProfile(user));
      unawaited(onboarding.flushPendingAnswers(user.uid));
      context.go(RoutePaths.home);
      return;
    }

    final onboardingDone = ref.read(onboardingServiceProvider).isCompleted;
    context.go(onboardingDone ? RoutePaths.login : RoutePaths.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandMark(),
              SizedBox(height: AppSpacing.huge),
              SizedBox(width: 24, height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
