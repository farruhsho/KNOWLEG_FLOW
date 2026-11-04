import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/social_codes.dart';

/// Flat bordered section used by the social pages.
class SocialCard extends StatelessWidget {
  const SocialCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: context.tokens.border),
      ),
      child: child,
    );
  }
}

/// Section heading.
class SocialHeading extends StatelessWidget {
  const SocialHeading(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Secondary text.
class SocialMuted extends StatelessWidget {
  const SocialMuted(this.text, {super.key, this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: textAlign,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.textSecondary),
      );
}

/// Normalises a code while typing: upper case, no spaces/dashes, Cyrillic
/// look-alikes mapped to Latin ([SocialCodes.normalize]).
class SocialCodeInputFormatter extends TextInputFormatter {
  const SocialCodeInputFormatter({this.maxLength = SocialCodes.maxInputLength});

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = SocialCodes.normalize(newValue.text);
    if (text.length > maxLength) text = text.substring(0, maxLength);
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Text field for a code (monospaced look, no autocorrect).
class SocialCodeField extends StatelessWidget {
  const SocialCodeField({
    super.key,
    required this.controller,
    this.errorText,
    this.helperText,
    this.label,
    this.maxLength = SocialCodes.maxInputLength,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? errorText;
  final String? helperText;
  final String? label;
  final int maxLength;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.visiblePassword,
      inputFormatters: [SocialCodeInputFormatter(maxLength: maxLength)],
      onSubmitted: onSubmitted,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 2),
      decoration: InputDecoration(
        labelText: label ?? l.socialCodeFieldLabel,
        errorText: errorText,
        helperText: helperText,
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
    );
  }
}

/// Floating snackbar with plain text.
void showSocialSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

/// Copies [text] and confirms with [message].
Future<void> copyWithSnack(BuildContext context, String text, String message) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showSocialSnack(context, message);
}

/// Yes/no confirmation; [confirmLabel] is the destructive action.
Future<bool> confirmSocialAction(
  BuildContext context, {
  required String message,
  required String confirmLabel,
}) async {
  final l = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.socialCancel)),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Small inline progress for buttons.
class SocialButtonProgress extends StatelessWidget {
  const SocialButtonProgress({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
}

/// Medium date in the current locale without depending on intl date data.
String socialDate(BuildContext context, DateTime? at) {
  if (at == null) return '';
  return MaterialLocalizations.of(context).formatMediumDate(at.toLocal());
}
