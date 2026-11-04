import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/navigation/nav_helpers.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import '../../../settings/domain/app_info.dart';
import '../../domain/auth_validation.dart';
import '../widgets/auth_widgets.dart';

/// E-mail registration. Public sign-ups are always students; admin roles
/// are provisioned server-side only (SEC-004).
class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => _open(LegalLinks.termsOfService);
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => _open(LegalLinks.privacyPolicy);

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _run(Future<void> Function() action, {String? successMessage}) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await action();
      if (successMessage != null) {
        messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      }
      if (!mounted) return;
      context.go(RoutePaths.home);
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

  Future<void> _handleSignup() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final l = AppLocalizations.of(context)!;
    final language = ref.read(contentLanguageProvider);
    await _run(
      () => ref.read(authServiceProvider).signUpWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            name: _nameController.text.trim(),
            preferredLanguage: language,
          ),
      successMessage: l.shellSignupSuccess,
    );
  }

  Future<void> _handleGoogle() async {
    if (_isLoading) return;
    await _run(() => ref.read(authServiceProvider).signInWithGoogle());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final gutter = AppSpacing.gutter(context);
    final linkStyle = TextStyle(
      color: scheme.primary,
      decoration: TextDecoration.underline,
    );

    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(fallback: RoutePaths.login),
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
                        title: l.shellSignupTitle,
                        subtitle: l.shellSignupSubtitle,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        maxLength: 60,
                        decoration: InputDecoration(
                          labelText: l.shellAuthNameLabel,
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          counterText: '',
                        ),
                        validator: (v) => l.shellValidate(AuthValidators.name(v)),
                      ),
                      const SizedBox(height: AppSpacing.lg),
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
                        validator: (v) => l.shellValidate(AuthValidators.email(v)),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PasswordField(
                        controller: _passwordController,
                        label: l.shellAuthPasswordLabel,
                        helperText: l.shellAuthPasswordHint(
                          AuthValidators.minPasswordLength,
                        ),
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (v) =>
                            l.shellValidate(AuthValidators.newPassword(v)),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PasswordField(
                        controller: _confirmPasswordController,
                        label: l.shellAuthConfirmPasswordLabel,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handleSignup(),
                        validator: (v) => l.shellValidate(
                          AuthValidators.confirmPassword(v, _passwordController.text),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text.rich(
                        TextSpan(
                          style: text.bodySmall
                              ?.copyWith(color: context.tokens.textSecondary),
                          children: [
                            TextSpan(text: l.shellSignupLegalPrefix),
                            TextSpan(
                              text: l.shellSettingsTerms,
                              style: linkStyle,
                              recognizer: _termsTap,
                            ),
                            TextSpan(text: l.shellSignupLegalAnd),
                            TextSpan(
                              text: l.shellSettingsPrivacy,
                              style: linkStyle,
                              recognizer: _privacyTap,
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (_error != null) ...[
                        AuthErrorBox(message: _error!),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      FilledButton(
                        onPressed: _isLoading ? null : _handleSignup,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l.shellSignupButton),
                      ),
                      if (GoogleSignInSupport.isAvailable) ...[
                        const SizedBox(height: AppSpacing.xl),
                        const OrDivider(),
                        const SizedBox(height: AppSpacing.xl),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleGoogle,
                          icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                          label: Text(l.shellAuthContinueWithGoogle),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(l.shellSignupHaveAccount),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => safePop(context, fallback: RoutePaths.login),
                            child: Text(l.shellLoginButton),
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
