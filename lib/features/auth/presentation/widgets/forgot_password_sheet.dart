import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:okey_acar_mi/core/extensions/context_extensions.dart';
import 'package:okey_acar_mi/core/theme/app_typography.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/core/widgets/app_text_field.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/login_bloc.dart';
import 'package:okey_acar_mi/features/auth/presentation/widgets/auth_failure_l10n.dart';

/// Opens the password-reset bottom sheet, sharing the page's [bloc].
///
/// [initialEmail] pre-fills the field with the login form's email. On
/// dismiss the bloc's inline state (errors, reset receipt) is cleared so the
/// login form returns to idle.
Future<void> showForgotPasswordSheet(
  BuildContext context, {
  required LoginBloc bloc,
  required String initialEmail,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: ForgotPasswordSheet(initialEmail: initialEmail),
    ),
  ).whenComplete(() => bloc.add(const LoginEvent.fieldsEdited()));
}

/// The password-reset sheet body (assumes a [LoginBloc] above it).
class ForgotPasswordSheet extends StatefulWidget {
  /// Creates a [ForgotPasswordSheet] pre-filled with [initialEmail].
  const ForgotPasswordSheet({required this.initialEmail, super.key});

  /// The email the login form held when the sheet opened.
  final String initialEmail;

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail,
  );

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The keyboard must not cover the field: pad by the view insets.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('forgot-sheet'),
        padding: EdgeInsets.fromLTRB(28, 24, 28, 24 + bottomInset),
        child: BlocBuilder<LoginBloc, LoginState>(
          buildWhen: (a, b) =>
              a.inFlight != b.inFlight ||
              a.emailError != b.emailError ||
              a.failure != b.failure ||
              a.resetEmailSent != b.resetEmailSent,
          builder: (context, state) => state.resetEmailSent
              ? const _ResetSentBody()
              : _ResetFormBody(emailController: _emailController, state: state),
        ),
      ),
    );
  }
}

class _ResetFormBody extends StatelessWidget {
  const _ResetFormBody({required this.emailController, required this.state});

  final TextEditingController emailController;
  final LoginState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final bloc = context.read<LoginBloc>();
    final busy = state.inFlight != LoginInFlight.none;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.forgotTitle,
          style: AppTypography.serifStyle(fontSize: 32, color: palette.ink),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.forgotBody,
          style: context.textTheme.bodyMedium?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 20),
        AppTextField(
          key: const ValueKey('forgot-email'),
          controller: emailController,
          hintText: l10n.loginEmailHint,
          errorText: switch (state.emailError) {
            null => null,
            EmailFieldError.empty => l10n.authErrorEmailEmpty,
            EmailFieldError.invalid => l10n.authErrorEmailInvalid,
            EmailFieldError.alreadyInUse => l10n.authErrorEmailInUse,
          },
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onChanged: (_) => bloc.add(const LoginEvent.fieldsEdited()),
        ),
        if (state.failure != null) ...[
          const SizedBox(height: 12),
          Text(
            failureText(l10n, state.failure!),
            style: context.textTheme.bodySmall?.copyWith(color: palette.bad),
          ),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          key: const ValueKey('forgot-submit'),
          label: l10n.forgotSubmit,
          fullWidth: true,
          loading: state.inFlight == LoginInFlight.reset,
          onPressed: busy
              ? null
              : () => bloc.add(
                  LoginEvent.passwordResetRequested(
                    email: emailController.text.trim(),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ResetSentBody extends StatelessWidget {
  const _ResetSentBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, size: 36, color: palette.good),
        const SizedBox(height: 12),
        Text(
          l10n.forgotSentTitle,
          style: AppTypography.serifStyle(fontSize: 32, color: palette.ink),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.forgotSentBody,
          style: context.textTheme.bodyMedium?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 20),
        SecondaryButton(
          key: const ValueKey('forgot-done'),
          label: l10n.forgotClose,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
