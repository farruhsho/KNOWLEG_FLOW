import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/admin_auth_service.dart';
import '../../data/admin_firebase.dart';
import '../widgets/admin_widgets.dart';

/// Admin sign-in (CMS-29): email + password, then the role is resolved from
/// the custom claim (`getIdTokenResult(true).claims['role']`) with the legacy
/// `users/{uid}.role == 'admin'` fallback. No OAuth / biometric / "remember
/// me" stubs; forgot-password really sends the reset email.
class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  /// Account Firebase Auth kept from a previous session (cold start).
  User? _existing;

  @override
  void initState() {
    super.initState();
    _existing = ref.read(adminAuthProvider).currentUser;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    final l = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      context.go(RoutePaths.adminDashboard);
    } on NotAnAdminException {
      if (!mounted) return;
      setState(() => _error = l.adminLoginErrNotAdmin);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = adminErrorMessage(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(() => ref.read(adminAuthServiceProvider).signIn(_email.text, _password.text));
  }

  Future<void> _continueExisting() async {
    final user = _existing;
    if (user == null) return;
    await _run(() => ref.read(adminAuthServiceProvider).verify(user));
  }

  Future<void> _useAnotherAccount() async {
    await ref.read(adminAuthServiceProvider).signOut();
    if (mounted) setState(() => _existing = null);
  }

  Future<void> _forgotPassword() async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.adminLoginResetTitle),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: InputDecoration(labelText: l.adminLoginEmail),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.adminCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l.adminLoginResetSend),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty || !mounted) return;
    try {
      await ref.read(adminAuthServiceProvider).sendPasswordReset(email);
    } on FirebaseAuthException catch (e) {
      // Do not reveal whether the account exists; only surface real failures.
      if (e.code != 'user-not-found' && e.code != 'invalid-email') {
        if (mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
        return;
      }
    } catch (e) {
      if (mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
      return;
    }
    if (mounted) showAdminSnack(context, l.adminLoginResetSent);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.gutter(context)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AdminCard(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.admin_panel_settings_outlined, size: 40, color: scheme.primary),
                    const SizedBox(height: AppSpacing.md),
                    Text(l.adminLoginTitle,
                        style: text.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l.adminLoginSubtitle,
                      style: text.bodyMedium?.copyWith(color: context.tokens.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    if (_existing != null) ..._existingAccount(l) else ..._form(l),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: context.tokens.dangerContainer,
                          borderRadius: AppRadii.smAll,
                        ),
                        child: Text(_error!, style: TextStyle(color: context.tokens.danger)),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    TextButton(
                      onPressed: _busy ? null : () => context.go(RoutePaths.splash),
                      child: Text(l.adminLoginBackToApp),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _existingAccount(AppLocalizations l) => [
        Text(l.adminLoginSignedInAs(_existing!.email ?? _existing!.uid),
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _busy ? null : _continueExisting,
          child: _busy ? const _ButtonSpinner() : Text(l.adminLoginContinue),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: _busy ? null : _useAnotherAccount,
          child: Text(l.adminLoginOtherAccount),
        ),
      ];

  List<Widget> _form(AppLocalizations l) => [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l.adminLoginEmail,
                    prefixIcon: const Icon(Icons.alternate_email),
                  ),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? l.adminLoginEmailInvalid : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _busy ? null : _signIn(),
                  decoration: InputDecoration(
                    labelText: l.adminLoginPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? l.adminLoginShowPassword : l.adminLoginHidePassword,
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? l.adminLoginPasswordRequired : null,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : _forgotPassword,
            child: Text(l.adminLoginForgot),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: _busy ? null : _signIn,
          child: _busy ? const _ButtonSpinner() : Text(l.adminLoginSubmit),
        ),
      ];
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
}
