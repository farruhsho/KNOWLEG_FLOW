import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// Honest elapsed-time chip (counts up from [startedAt]). Only this small
/// widget rebuilds every second — never the whole page.
class ElapsedTimer extends StatefulWidget {
  final DateTime startedAt;
  final String? semanticsLabel;

  const ElapsedTimer({super.key, required this.startedAt, this.semanticsLabel});

  static String format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  State<ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<ElapsedTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    final text = ElapsedTimer.format(elapsed.isNegative ? Duration.zero : elapsed);
    final theme = Theme.of(context);
    return Semantics(
      label: widget.semanticsLabel,
      value: text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: context.tokens.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 16, color: context.tokens.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
