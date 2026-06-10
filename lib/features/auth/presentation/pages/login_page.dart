import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/router/app_router.dart';
import 'package:okey_acar_mi/core/theme/app_radii.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/app_text_field.dart';
import 'package:okey_acar_mi/core/widgets/circle_icon_button.dart';
import 'package:okey_acar_mi/core/widgets/eyebrow.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/login_bloc.dart';
import 'package:okey_acar_mi/features/auth/presentation/widgets/auth_failure_l10n.dart';
import 'package:okey_acar_mi/features/auth/presentation/widgets/forgot_password_sheet.dart';

/// Login / sign-up screen: email + password form, provider buttons, guest
/// escape, and the sign-in ⇄ sign-up mode switch.
///
/// Never navigates on success — the router's auth redirect moves
/// authenticated users to Home (D8).
class LoginPage extends StatelessWidget {
  /// Creates a [LoginPage].
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LoginBloc>(
      create: (_) => getIt<LoginBloc>(),
      child: const LoginView(),
    );
  }
}

/// The login form view (assumes a [LoginBloc] is provided above it).
class LoginView extends StatefulWidget {
  /// Creates a [LoginView].
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // On successful sign-in, commit the autofill context so password
    // managers offer to save the entered credentials.
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) =>
          prev is! AuthAuthenticated && curr is AuthAuthenticated,
      listener: (_, _) => TextInput.finishAutofillContext(),
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _LoginHeader(),
                const SizedBox(height: 24),
                AutofillGroup(
                  child: _EmailPasswordForm(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    emailFocus: _emailFocus,
                    passwordFocus: _passwordFocus,
                  ),
                ),
                const SizedBox(height: 20),
                const _OAuthDivider(),
                const SizedBox(height: 20),
                const _OAuthButtons(),
                const SizedBox(height: 12),
                const _ModeSwitchFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final canPop = context.canPop();

    return BlocSelector<LoginBloc, LoginState, LoginMode>(
      selector: (state) => state.mode,
      builder: (context, mode) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleIconButton(
                  key: const ValueKey('login-back'),
                  icon: canPop ? Icons.arrow_back : Icons.home_outlined,
                  // Without a back stack the button shows a home icon and
                  // goes to the start screen — announce that, not "back".
                  semanticLabel: canPop ? l10n.commonBack : l10n.commonGoStart,
                  onPressed: () =>
                      canPop ? context.pop() : context.go(AppRoutes.splash),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Eyebrow(l10n.loginEyebrow),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                mode == LoginMode.signIn
                    ? l10n.loginTitleSignIn
                    : l10n.loginTitleSignUp,
                style: AppTypography.serifStyle(
                  fontSize: 42,
                  color: palette.ink,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.loginSubtitle,
              style: context.textTheme.bodyMedium?.copyWith(
                color: palette.muted,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmailPasswordForm extends StatelessWidget {
  const _EmailPasswordForm({
    required this.emailController,
    required this.passwordController,
    required this.emailFocus,
    required this.passwordFocus,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;

  void _submit(BuildContext context) {
    context.read<LoginBloc>().add(
      LoginEvent.emailSubmitted(
        email: emailController.text.trim(),
        password: passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<LoginBloc, LoginState>(
      // > 3 fields on LoginState: rebuild only on what this form reads.
      buildWhen: (a, b) =>
          a.mode != b.mode ||
          a.inFlight != b.inFlight ||
          a.emailError != b.emailError ||
          a.passwordError != b.passwordError ||
          a.failure != b.failure,
      builder: (context, state) {
        final bloc = context.read<LoginBloc>();
        final busy = state.inFlight != LoginInFlight.none;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              key: const ValueKey('login-email'),
              controller: emailController,
              focusNode: emailFocus,
              hintText: l10n.loginEmailHint,
              errorText: switch (state.emailError) {
                null => null,
                EmailFieldError.empty => l10n.authErrorEmailEmpty,
                EmailFieldError.invalid => l10n.authErrorEmailInvalid,
                EmailFieldError.alreadyInUse => l10n.authErrorEmailInUse,
              },
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) => bloc.add(const LoginEvent.fieldsEdited()),
              onSubmitted: (_) => passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
            AppTextField(
              key: const ValueKey('login-password'),
              controller: passwordController,
              focusNode: passwordFocus,
              hintText: l10n.loginPasswordHint,
              errorText: switch (state.passwordError) {
                null => null,
                PasswordFieldError.empty => l10n.authErrorPasswordEmpty,
                PasswordFieldError.tooShort => l10n.authErrorPasswordTooShort,
              },
              obscurable: true,
              visibilityToggleKey: const ValueKey(
                'login-password-visibility',
              ),
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onChanged: (_) => bloc.add(const LoginEvent.fieldsEdited()),
              onSubmitted: (_) {
                if (!busy) _submit(context);
              },
            ),
            if (state.mode == LoginMode.signIn)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const ValueKey('login-forgot'),
                  onPressed: busy
                      ? null
                      : () => showForgotPasswordSheet(
                          context,
                          bloc: bloc,
                          initialEmail: emailController.text.trim(),
                        ),
                  child: Text(l10n.loginForgot),
                ),
              )
            else
              const SizedBox(height: 8),
            if (state.failure != null) ...[
              const SizedBox(height: 4),
              _FailureBanner(
                key: const ValueKey('login-error-banner'),
                message: failureText(l10n, state.failure!),
              ),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 8),
            PrimaryButton(
              key: const ValueKey('login-submit'),
              label: state.mode == LoginMode.signIn
                  ? l10n.loginSubmitSignIn
                  : l10n.loginSubmitSignUp,
              fullWidth: true,
              loading: state.inFlight == LoginInFlight.email,
              onPressed: busy ? null : () => _submit(context),
            ),
          ],
        );
      },
    );
  }
}

/// A bad-tinted inline error card.
class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Live region: screen readers announce the failure when it appears.
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: palette.bad.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: palette.bad),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                // Ink (not bad) text: the bad-on-bad-tint pairing fails
                // WCAG contrast; the icon + tint carry the error styling.
                style: context.textTheme.bodySmall?.copyWith(
                  color: palette.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OAuthDivider extends StatelessWidget {
  const _OAuthDivider();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: palette.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Eyebrow(context.l10n.loginDividerOr),
        ),
        Expanded(child: Container(height: 1, color: palette.line)),
      ],
    );
  }
}

class _OAuthButtons extends StatelessWidget {
  const _OAuthButtons();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Apple Sign-In is iOS-only in v1 (D9).
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;

    return BlocSelector<LoginBloc, LoginState, LoginInFlight>(
      selector: (state) => state.inFlight,
      builder: (context, inFlight) {
        final bloc = context.read<LoginBloc>();
        final busy = inFlight != LoginInFlight.none;

        return Column(
          children: [
            SecondaryButton(
              key: const ValueKey('login-google'),
              label: l10n.loginGoogle,
              fullWidth: true,
              loading: inFlight == LoginInFlight.google,
              onPressed: busy
                  ? null
                  : () => bloc.add(const LoginEvent.googleRequested()),
            ),
            if (isIos) ...[
              const SizedBox(height: 10),
              SecondaryButton(
                key: const ValueKey('login-apple'),
                label: l10n.loginApple,
                fullWidth: true,
                loading: inFlight == LoginInFlight.apple,
                onPressed: busy
                    ? null
                    : () => bloc.add(const LoginEvent.appleRequested()),
              ),
            ],
            const SizedBox(height: 10),
            GhostButton(
              key: const ValueKey('login-guest'),
              label: l10n.loginGuest,
              fullWidth: true,
              onPressed: busy ? null : () => context.go(AppRoutes.home),
            ),
          ],
        );
      },
    );
  }
}

class _ModeSwitchFooter extends StatelessWidget {
  const _ModeSwitchFooter();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return BlocSelector<LoginBloc, LoginState, (LoginMode, bool)>(
      selector: (state) => (state.mode, state.inFlight != LoginInFlight.none),
      builder: (context, selection) {
        final (mode, busy) = selection;
        final signIn = mode == LoginMode.signIn;
        return Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              Text(
                signIn ? l10n.loginNoAccount : l10n.loginHaveAccount,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: palette.muted,
                ),
              ),
              TextButton(
                key: const ValueKey('login-mode-toggle'),
                onPressed: busy
                    ? null
                    : () => context.read<LoginBloc>().add(
                        const LoginEvent.modeToggled(),
                      ),
                child: Text(
                  signIn
                      ? l10n.loginModeToggleToSignUp
                      : l10n.loginModeToggleToSignIn,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
