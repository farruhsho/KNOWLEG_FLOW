import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/exam_session.dart';
import 'exam_common.dart';

/// Self-contained countdown to [deadline] (device clock, already corrected
/// for server skew). Only this widget rebuilds every second — never the page.
class ExamCountdown extends StatefulWidget {
  final DateTime deadline;
  final ExamClock clock;
  final TextStyle? style;
  final bool showIcon;
  final bool compact;

  /// Wraps the `mm:ss` text, e.g. «Раздел закончится через 09:59».
  final String Function(String time)? labelBuilder;

  const ExamCountdown({
    super.key,
    required this.deadline,
    required this.clock,
    this.style,
    this.showIcon = true,
    this.compact = false,
    this.labelBuilder,
  });

  @override
  State<ExamCountdown> createState() => _ExamCountdownState();
}

class _ExamCountdownState extends State<ExamCountdown> {
  Timer? _timer;
  late Duration _left;

  @override
  void initState() {
    super.initState();
    _left = _compute();
    _schedule();
  }

  @override
  void didUpdateWidget(ExamCountdown old) {
    super.didUpdateWidget(old);
    if (old.deadline != widget.deadline) {
      _left = _compute();
      _schedule();
    }
  }

  Duration _compute() {
    final d = widget.deadline.difference(widget.clock());
    return d.isNegative ? Duration.zero : d;
  }

  void _schedule() {
    _timer?.cancel();
    if (_left == Duration.zero) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _compute();
      if (next.inSeconds != _left.inSeconds) setState(() => _left = next);
      if (next == Duration.zero) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final critical = _left <= const Duration(minutes: 1);
    final warning = _left <= const Duration(minutes: 5);
    final fg = critical
        ? tokens.danger
        : warning
            ? tokens.warning
            : scheme.onSurface;
    final base = widget.style ?? Theme.of(context).textTheme.titleMedium!;
    final formatted = formatExamDuration(_left);
    final label = widget.labelBuilder?.call(formatted);
    final text = Text(
      label ?? formatted,
      maxLines: label == null ? 1 : 2,
      softWrap: label != null,
      overflow: label == null ? TextOverflow.fade : TextOverflow.ellipsis,
      style: base.copyWith(
        color: fg,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return Semantics(
      label: context.l10n.examTimeLeftLabel,
      value: formatExamDuration(_left),
      liveRegion: critical,
      child: ExcludeSemantics(
        child: widget.compact || !widget.showIcon
            ? text
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: fg),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(child: text),
                ],
              ),
      ),
    );
  }
}
