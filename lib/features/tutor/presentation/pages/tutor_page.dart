import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/tutor_controller.dart';
import '../../domain/tutor_models.dart';
import '../tutor_messages.dart';
import '../widgets/tutor_markdown.dart';

/// AI tutor chat (RoutePaths.tutor). Accepts optional route `extra`
/// `{questionId, attemptId, mode, prefill}` — see [TutorArgs].
class TutorPage extends ConsumerStatefulWidget {
  const TutorPage({super.key, this.args = TutorArgs.empty});

  final TutorArgs args;

  @override
  ConsumerState<TutorPage> createState() => _TutorPageState();
}

class _TutorPageState extends ConsumerState<TutorPage> {
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args.prefill != null) _input.text = args.prefill!;
    if (!args.isEmpty) {
      // Provider state cannot change while the tree is building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(tutorChatProvider.notifier).applyArgs(args);
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String get _language => tutorLanguageFor(Localizations.localeOf(context).languageCode);

  void _send() {
    final s = ref.read(tutorChatProvider);
    final text = _input.text;
    if (text.trim().isEmpty || s.sending || s.blockingFailure != null) return;
    _input.clear();
    ref.read(tutorChatProvider.notifier).send(text, language: _language);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(tutorChatProvider);
    final notifier = ref.read(tutorChatProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tutorTitle),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              tooltip: l10n.tutorClear,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: state.sending ? null : notifier.clear,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _ModeBar(selected: state.mode, onSelected: notifier.setMode),
            if (state.hasContext)
              _ContextChip(
                label: state.questionId != null ? l10n.tutorContextQuestion : l10n.tutorContextAttempt,
                onRemove: notifier.clearContext,
              ),
            Expanded(
              child: state.messages.isEmpty && !state.sending
                  ? const _EmptyState()
                  : _MessageList(
                      state: state,
                      onRetry: (id) => notifier.retry(id, language: _language),
                    ),
            ),
            if (state.blockingFailure != null) _BlockingBanner(failure: state.blockingFailure!),
            _Composer(
              controller: _input,
              hint: l10n.tutorModeHint(state.mode),
              enabled: state.blockingFailure == null,
              sending: state.sending,
              remainingToday: state.remainingToday,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeBar extends StatelessWidget {
  const _ModeBar({required this.selected, required this.onSelected});

  final TutorMode selected;
  final ValueChanged<TutorMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final g = AppSpacing.gutter(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(g, AppSpacing.xs, g, AppSpacing.sm),
      child: Row(
        children: [
          for (final m in TutorMode.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(l10n.tutorModeLabel(m)),
                selected: m == selected,
                onSelected: (_) => onSelected(m),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final g = AppSpacing.gutter(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(g, 0, g, AppSpacing.sm),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: InputChip(
          avatar: const Icon(Icons.attach_file, size: 18),
          label: Text(label),
          onDeleted: onRemove,
          deleteButtonTooltipMessage: l10n.tutorContextRemove,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final g = AppSpacing.gutter(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(g, AppSpacing.xxl, g, AppSpacing.lg),
      children: [
        Icon(Icons.psychology_alt_outlined, size: 40, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.tutorEmptyTitle, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.tutorEmptyBody, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xl),
        const _Disclaimer(),
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: context.tokens.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(l10n.tutorDisclaimer, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.state, required this.onRetry});

  final TutorChatState state;
  final ValueChanged<String> onRetry;

  @override
  Widget build(BuildContext context) {
    final g = AppSpacing.gutter(context);
    final msgs = state.messages;
    // Reversed list keeps the newest message anchored at the bottom.
    final extra = state.sending ? 1 : 0;
    final count = msgs.length + extra + 1; // +1 disclaimer at the top
    return ListView.builder(
      reverse: true,
      padding: EdgeInsets.fromLTRB(g, AppSpacing.sm, g, AppSpacing.sm),
      itemCount: count,
      itemBuilder: (context, i) {
        if (state.sending && i == 0) return const _ThinkingBubble();
        final idx = msgs.length - 1 - (i - extra);
        if (idx < 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: _Disclaimer(),
          );
        }
        final m = msgs[idx];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: m.role == TutorRole.user
              ? _UserBubble(
                  message: m,
                  canRetry: !state.sending && state.blockingFailure == null,
                  onRetry: () => onRetry(m.id),
                )
              : _AssistantBubble(message: m),
        );
      },
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message, required this.canRetry, required this.onRetry});

  final TutorMessage message;
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxW = MediaQuery.sizeOf(context).width * 0.85;
    final failure = message.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Semantics(
            label: l10n.tutorYou,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: AppRadii.lgAll,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: SelectableText(
                  message.text,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ),
            ),
          ),
        ),
        if (failure != null)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xs,
                children: [
                  Icon(Icons.error_outline, size: 16, color: context.tokens.danger),
                  Text(
                    l10n.tutorFailureMessage(failure),
                    style: theme.textTheme.bodySmall?.copyWith(color: context.tokens.danger),
                  ),
                  if (canRetry && !failure.blocksInput)
                    TextButton(onPressed: onRetry, child: Text(l10n.tutorRetry)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.message});

  final TutorMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.92),
        child: Semantics(
          label: l10n.tutorAssistant,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: AppRadii.lgAll,
              border: Border.all(color: context.tokens.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SelectionArea(child: TutorMarkdown(message.text)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          liveRegion: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: Text(l10n.tutorThinking, style: theme.textTheme.bodySmall)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockingBanner extends StatelessWidget {
  const _BlockingBanner({required this.failure});

  final TutorFailure failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final g = AppSpacing.gutter(context);
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(g, 0, g, AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.warningContainer, borderRadius: AppRadii.mdAll),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hourglass_empty, size: 20, color: t.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(l10n.tutorFailureMessage(failure),
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hint,
    required this.enabled,
    required this.sending,
    required this.remainingToday,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final bool sending;
  final int? remainingToday;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final g = AppSpacing.gutter(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: context.tokens.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(g, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (remainingToday != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(l10n.tutorRemainingToday(remainingToday!), style: theme.textTheme.bodySmall),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: TutorRequest.maxMessageChars,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: hint,
                      hintMaxLines: 2,
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final canSend = enabled && !sending && value.text.trim().isNotEmpty;
                    return IconButton.filled(
                      tooltip: l10n.tutorSend,
                      onPressed: canSend ? onSend : null,
                      icon: const Icon(Icons.send_rounded),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
