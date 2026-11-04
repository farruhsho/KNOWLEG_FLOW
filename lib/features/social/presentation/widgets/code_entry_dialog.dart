import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/social_codes.dart';
import '../social_messages.dart';
import 'social_widgets.dart';

/// Dialog with one code field that calls [submit] and shows the server's
/// answer inline. Returns what [submit] returned, or null when cancelled.
///
/// [validate] runs first on the normalised code and returns an error text
/// for an obviously malformed code (no server call is made then).
Future<T?> showCodeEntryDialog<T>(
  BuildContext context, {
  required String title,
  required String actionLabel,
  required SocialAction action,
  required Future<T> Function(String code) submit,
  String? Function(String code)? validate,
  String? hint,
  int maxLength = SocialCodes.maxInputLength,
  String? initialCode,
  Key? fieldKey,
  Key? actionKey,
}) {
  return showDialog<T>(
    context: context,
    builder: (_) => _CodeEntryDialog<T>(
      title: title,
      actionLabel: actionLabel,
      action: action,
      submit: submit,
      validate: validate,
      hint: hint,
      maxLength: maxLength,
      initialCode: initialCode,
      fieldKey: fieldKey,
      actionKey: actionKey,
    ),
  );
}

class _CodeEntryDialog<T> extends StatefulWidget {
  const _CodeEntryDialog({
    required this.title,
    required this.actionLabel,
    required this.action,
    required this.submit,
    this.validate,
    this.hint,
    this.maxLength = SocialCodes.maxInputLength,
    this.initialCode,
    this.fieldKey,
    this.actionKey,
  });

  final String title;
  final String actionLabel;
  final SocialAction action;
  final Future<T> Function(String code) submit;
  final String? Function(String code)? validate;
  final String? hint;
  final int maxLength;
  final String? initialCode;
  final Key? fieldKey;
  final Key? actionKey;

  @override
  State<_CodeEntryDialog<T>> createState() => _CodeEntryDialogState<T>();
}

class _CodeEntryDialogState<T> extends State<_CodeEntryDialog<T>> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialCode ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l = AppLocalizations.of(context)!;
    final code = SocialCodes.normalize(_controller.text);
    final invalid = widget.validate?.call(code);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.submit(code);
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l.socialErrorMessage(e, widget.action);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.hint != null) ...[
            SocialMuted(widget.hint!),
            const SizedBox(height: AppSpacing.md),
          ],
          SocialCodeField(
            key: widget.fieldKey,
            controller: _controller,
            maxLength: widget.maxLength,
            errorText: _error,
            enabled: !_busy,
            autofocus: true,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.socialCancel),
        ),
        FilledButton(
          key: widget.actionKey,
          onPressed: _busy ? null : _submit,
          child: _busy ? const SocialButtonProgress() : Text(widget.actionLabel),
        ),
      ],
    );
  }
}
