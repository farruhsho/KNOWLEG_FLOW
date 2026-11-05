import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../design/tokens.dart';

/// App logo + name, shared by the boot splash and [SplashPage] so the hand
/// over between them is seamless.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: AppRadii.xlAll,
          ),
          child: Icon(Icons.school_rounded, size: 48, color: scheme.onPrimary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'ORT Master KG',
          style: text.headlineMedium,
          textAlign: TextAlign.center,
        ),
        if (l != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.shellTagline,
            style: text.bodyMedium?.copyWith(color: context.tokens.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Shown while Firebase initializes. A progress indicator appears only if
/// start-up takes noticeably long, so fast starts do not flash a spinner.
class BootSplashScreen extends StatelessWidget {
  const BootSplashScreen({super.key});

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
              _DelayedProgress(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DelayedProgress extends StatefulWidget {
  const _DelayedProgress();

  @override
  State<_DelayedProgress> createState() => _DelayedProgressState();
}

class _DelayedProgressState extends State<_DelayedProgress> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: AppMotion.of(context, AppMotion.normal),
        child: const CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }
}

/// Firebase could not start (no network on first launch, bad config, …).
class BootErrorScreen extends StatelessWidget {
  const BootErrorScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.gutter(context)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: context.tokens.textTertiary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l.shellBootErrorTitle,
                  style: text.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l.shellBootErrorMessage,
                  style:
                      text.bodyMedium?.copyWith(color: context.tokens.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l.shellRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
