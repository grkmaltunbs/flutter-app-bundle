import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/core/widgets/app_buttons.dart';
import 'package:okey_acar_mi/features/auth/data/fakes/fake_auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/login_bloc.dart';
import 'package:okey_acar_mi/features/auth/presentation/pages/login_page.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// A router-backed harness (`LoginPage` calls `context.canPop()` at build
/// time) over the real demo DI. [platform] drives the iOS-only Apple button.
Widget _harness({TargetPlatform platform = TargetPlatform.android}) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    ],
  );
  return MaterialApp.router(
    theme: AppTheme.light(
      AppAccent.sage,
      TileStyle.classic,
    ).copyWith(platform: platform),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('tr'), Locale('en')],
    routerConfig: router,
    builder: (context, child) => MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
        // LoginView listens to the app-scoped AuthBloc (autofill commit).
        BlocProvider<AuthBloc>(
          create: (_) => getIt<AuthBloc>()..add(const AuthEvent.started()),
        ),
      ],
      child: child!,
    ),
  );
}

void main() {
  setUp(() async => configureDependencies('demo'));
  tearDown(() async => getIt.reset());

  FakeAuthRepository fake() => getIt<AuthRepository>() as FakeAuthRepository;

  group('LoginPage', () {
    testWidgets('mode toggle swaps the title and the submit CTA', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // app_en.arb: sign-in form.
      check(find.text('Welcome back.').evaluate()).length.equals(1);
      check(find.text('Sign in').evaluate()).isNotEmpty();

      final toggle = find.byKey(const ValueKey('login-mode-toggle'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      check(find.text('Make an account.').evaluate()).length.equals(1);
      check(find.text('Create account').evaluate()).length.equals(1);
      check(find.text('Welcome back.').evaluate()).isEmpty();
    });

    testWidgets('submitting empty fields shows both inline field errors', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();

      check(
        find.text('Email address is required.').evaluate(),
      ).length.equals(1);
      check(find.text('Password is required.').evaluate()).length.equals(1);
      check(
        find.byKey(const ValueKey('login-error-banner')).evaluate(),
      ).isEmpty();
    });

    testWidgets('invalid credentials surface the error banner', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'oyuncu@demo.app',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'yanlis-parola',
      );
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();

      check(
        find.byKey(const ValueKey('login-error-banner')).evaluate(),
      ).length.equals(1);
      check(
        find.text('Incorrect email or password.').evaluate(),
      ).length.equals(1);
    });

    testWidgets('the Apple button is present on iOS', (tester) async {
      await tester.pumpWidget(_harness(platform: TargetPlatform.iOS));
      await tester.pumpAndSettle();

      check(
        find.byKey(const ValueKey('login-apple')).evaluate(),
      ).length.equals(1);
    });

    testWidgets('the Apple button is absent on Android', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      check(find.byKey(const ValueKey('login-apple')).evaluate()).isEmpty();
    });

    testWidgets('while in flight every auth action is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(platform: TargetPlatform.iOS));
      await tester.pumpAndSettle();

      // The fake resolves instantly, so the transient in-flight frame is
      // pinned by emitting the state directly.
      tester
          .element(find.byType(LoginView))
          .read<LoginBloc>()
          .emit(const LoginState(inFlight: LoginInFlight.email));
      // First pump delivers the stream emission (microtask → setState);
      // second pump renders the rebuilt frame.
      await tester.pump();
      await tester.pump();

      final submit = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('login-submit')),
      );
      check(submit.loading).isTrue();
      check(submit.onPressed).isNull();
      check(
        tester
            .widget<SecondaryButton>(
              find.byKey(const ValueKey('login-google')),
            )
            .onPressed,
      ).isNull();
      check(
        tester
            .widget<SecondaryButton>(find.byKey(const ValueKey('login-apple')))
            .onPressed,
      ).isNull();
      check(
        tester
            .widget<GhostButton>(find.byKey(const ValueKey('login-guest')))
            .onPressed,
      ).isNull();
      check(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('login-forgot')))
            .onPressed,
      ).isNull();
    });

    testWidgets('the guest escape link is present', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      check(
        find.byKey(const ValueKey('login-guest')).evaluate(),
      ).length.equals(1);
    });

    testWidgets('forgot-password sheet: open → submit → sent → close', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('login-forgot')));
      await tester.pumpAndSettle();
      check(
        find.byKey(const ValueKey('forgot-sheet')).evaluate(),
      ).length.equals(1);

      await tester.enterText(
        find.byKey(const ValueKey('forgot-email')),
        'oyuncu@demo.app',
      );
      await tester.tap(find.byKey(const ValueKey('forgot-submit')));
      await tester.pumpAndSettle();

      check(fake().passwordResetEmailsSentTo).deepEquals(['oyuncu@demo.app']);
      check(
        find.byKey(const ValueKey('forgot-done')).evaluate(),
      ).length.equals(1);

      await tester.tap(find.byKey(const ValueKey('forgot-done')));
      await tester.pumpAndSettle();
      check(find.byKey(const ValueKey('forgot-sheet')).evaluate()).isEmpty();
      check(tester.takeException()).isNull();
    });
  });
}
