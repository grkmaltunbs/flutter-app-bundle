import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okey_acar_mi/core/di/injection.dart';
import 'package:okey_acar_mi/core/theme/app_accent.dart';
import 'package:okey_acar_mi/core/theme/app_theme.dart';
import 'package:okey_acar_mi/core/theme/tile_style.dart';
import 'package:okey_acar_mi/features/auth/data/fakes/fake_auth_repository.dart';
import 'package:okey_acar_mi/features/auth/domain/repositories/auth_repository.dart';
import 'package:okey_acar_mi/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:okey_acar_mi/features/auth/presentation/widgets/account_section.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

/// Pumps the [AccountSection] above the real (demo-DI) [AuthBloc], started so
/// the session restore runs against the fake's current mode.
Widget _harness() {
  return MaterialApp(
    theme: AppTheme.light(AppAccent.sage, TileStyle.classic),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('tr'), Locale('en')],
    home: MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
        BlocProvider<AuthBloc>(
          create: (_) => getIt<AuthBloc>()..add(const AuthEvent.started()),
        ),
      ],
      child: const Scaffold(
        body: SingleChildScrollView(child: AccountSection()),
      ),
    ),
  );
}

void main() {
  setUp(() async => configureDependencies('demo'));
  tearDown(() async => getIt.reset());

  FakeAuthRepository fake() => getIt<AuthRepository>() as FakeAuthRepository;

  group('AccountSection', () {
    testWidgets('guest: shows the sign-up CTA and no account actions', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      check(
        find.byKey(const ValueKey('settings-signup')).evaluate(),
      ).length.equals(1);
      check(
        find.byKey(const ValueKey('settings-signout')).evaluate(),
      ).isEmpty();
      check(
        find.byKey(const ValueKey('settings-delete-account')).evaluate(),
      ).isEmpty();
    });

    testWidgets('signed-in verified: shows the account, sign-out, delete — '
        'and no unverified pill', (tester) async {
      fake().mode = FakeAuthMode.seededSignedIn;
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      check(find.text('Demo Oyuncu').evaluate()).length.equals(1);
      check(find.text('oyuncu@demo.app').evaluate()).length.equals(1);
      check(
        find.byKey(const ValueKey('settings-signout')).evaluate(),
      ).length.equals(1);
      check(
        find.byKey(const ValueKey('settings-delete-account')).evaluate(),
      ).length.equals(1);
      check(find.byKey(const ValueKey('settings-signup')).evaluate()).isEmpty();
      // No unverified pill or resend action for a verified account.
      check(find.text('EMAIL NOT VERIFIED').evaluate()).isEmpty();
      check(
        find.byKey(const ValueKey('settings-resend-verification')).evaluate(),
      ).isEmpty();
    });

    testWidgets('unverified: shows the pill; resend flips to "sent" and '
        'records the email', (tester) async {
      fake().mode = FakeAuthMode.seededUnverified;
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      check(find.text('EMAIL NOT VERIFIED').evaluate()).length.equals(1);
      final resend = find.byKey(const ValueKey('settings-resend-verification'));
      check(resend.evaluate()).length.equals(1);
      check(find.text('Resend').evaluate()).length.equals(1);

      await tester.tap(resend);
      await tester.pumpAndSettle();

      check(find.text('Sent').evaluate()).length.equals(1);
      check(find.text('Resend').evaluate()).isEmpty();
      check(tester.widget<TextButton>(resend).onPressed).isNull();
      check(fake().verificationEmailsSentTo).deepEquals(['yeni@demo.app']);
    });

    testWidgets('sign-out flips the section back to the guest variant', (
      tester,
    ) async {
      fake().mode = FakeAuthMode.seededSignedIn;
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('settings-signout')));
      await tester.pumpAndSettle();

      check(
        find.byKey(const ValueKey('settings-signup')).evaluate(),
      ).length.equals(1);
      check(
        find.byKey(const ValueKey('settings-signout')).evaluate(),
      ).isEmpty();
      check(fake().currentUser).isNull();
      check(tester.takeException()).isNull();
    });
  });
}
