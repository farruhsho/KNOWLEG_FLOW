import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/navigation/route_guards.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/auth_provider.dart';
import '../../domain/auth_validation.dart';
import '../widgets/auth_widgets.dart';

/// E-mail / Google sign-in (SEC-005R, AUTH-03, AUTH-04).
///
/// Navigation after a successful sign-in is done by the router's auth guard
/// (login → `?from=` or home); the page only shows progress and errors.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _destination() {
    String? from;
    try {
      from = GoRouterState.of(context).uri.queryParameters[RouteGuards.fromParam];
    } catch (_) {}
    return RouteGuards.isSafeReturnLocation(from) ? from! : RoutePaths.home;
  }

  Future<void> _run(Future<void> Function() action) async {
    final l = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      // Usually the router has already redirected; this covers the rest.
      context.go(_destination());
    } catch (e) {
      final failure = classifyAuthError(e);
      if (mounted) {
        setState(() => _error =
            failure == null ? null : l.shellAuthFailureText(failure));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await _run(() => ref.read(authServiceProvider).signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ));
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    await _run(() => ref.read(authServiceProvider).signInWithGoogle());
  }

  Future<void> _handleForgotPassword() async {
    final l = AppLocalizations.of(context)!;
    final email = await showDialog<String>(
      context: context,
      builder: (context) =>
          _ResetPasswordDialog(initialEmail: _emailController.text.trim()),
    );
    if (email == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(email);
      // Same message whether or not the account exists (no enumeration).
      messenger.showSnackBar(SnackBar(content: Text(l.shellAuthResetSent)));
    } catch (e) {
      final failure = classifyAuthError(e);
      if (failure == AuthFailure.userNotFound) {
        messenger.showSnackBar(SnackBar(content: Text(l.shellAuthResetSent)));
        return;
      }
      if (failure != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.shellAuthFailureText(failure))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final gutter = AppSpacing.gutter(context);
    final googleAvailable = GoogleSignInSupport.isAvailable;

    return Scaffold(
      appBar: AppBar(
        actions: const [LanguageActionButton()],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, AppSpacing.xxl),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthHeader(
                        title: l.shellLoginTitle,
                        subtitle: l.shellLoginSubtitle,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: l.shellAuthEmailLabel,
                          hintText: 'name@example.com',
                          prefixIcon: const Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (v) =>
                            l.shellValidate(AuthValidators.email(v)),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PasswordField(
                        controller: _passwordController,
                        label: l.shellAuthPasswordLabel,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handleLogin(),
                        validator: (v) =>
                            l.shellValidate(AuthValidators.loginPassword(v)),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: _isLoading ? null : _handleForgotPassword,
                          child: Text(l.shellAuthForgotPassword),
                        ),
                      ),
                      if (_error != null) ...[
                        AuthErrorBox(message: _error!),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      FilledButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l.shellLoginButton),
                      ),
                      if (googleAvailable) ...[
                        const SizedBox(height: AppSpacing.xl),
                        const OrDivider(),
                        const SizedBox(height: AppSpacing.xl),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                          label: Text(l.shellAuthContinueWithGoogle),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(l.shellLoginNoAccount),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => context.push(RoutePaths.signup),
                            child: Text(l.shellLoginCreateAccount),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.shellAuthResetTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.shellAuthResetMessage),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _controller,
                autofocus: widget.initialEmail.isEmpty,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l.shellAuthEmailLabel),
                validator: (v) => l.shellValidate(AuthValidators.email(v)),
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.shellCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l.shellAuthResetSend)),
      ],
    );
  }
}
