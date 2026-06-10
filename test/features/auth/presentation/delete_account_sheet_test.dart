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
import 'package:okey_acar_mi/features/auth/presentation/widgets/delete_account_sheet.dart';
import 'package:okey_acar_mi/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:okey_acar_mi/l10n/app_localizations.dart';

const ValueKey<String> _openKey = ValueKey('open-delete-sheet');

/// A host page whose button opens the real [showDeleteAccountSheet] entry
/// point, with the demo-DI [AuthBloc] above it (the sheet re-provides it).
Widget _host() {
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
      child: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: _openKey,
              onPressed: () => showDeleteAccountSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(_openKey));
  await tester.pumpAndSettle();
  check(
    find.byKey(const ValueKey('delete-sheet')).evaluate(),
  ).length.equals(1);
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('delete-confirm')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async => configureDependencies('demo'));
  tearDown(() async => getIt.reset());

  FakeAuthRepository fake() => getIt<AuthRepository>() as FakeAuthRepository;

  group('DeleteAccountSheet', () {
    testWidgets('password user: confirm → password re-auth → done', (
      tester,
    ) async {
      fake().mode = FakeAuthMode.seededSignedIn;
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      await _openSheet(tester);
      await _confirm(tester);

      // A password-provider account re-authenticates with its password.
      check(
        find.byKey(const ValueKey('delete-password')).evaluate(),
      ).length.equals(1);
      check(
        find.byKey(const ValueKey('delete-reauth-provider')).evaluate(),
      ).isEmpty();

      await tester.enterText(
        find.byKey(const ValueKey('delete-password')),
        'okey1234',
      );
      await tester.tap(find.byKey(const ValueKey('delete-reauth-submit')));
      await tester.pumpAndSettle();

      check(
        find.byKey(const ValueKey('delete-done')).evaluate(),
      ).length.equals(1);
      check(fake().currentUser).isNull();
      check(tester.takeException()).isNull();
    });

    testWidgets('a wrong password flags the field and keeps the account', (
      tester,
    ) async {
      fake().mode = FakeAuthMode.seededSignedIn;
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      await _openSheet(tester);
      await _confirm(tester);

      await tester.enterText(
        find.byKey(const ValueKey('delete-password')),
        'yanlis-parola',
      );
      await tester.tap(find.byKey(const ValueKey('delete-reauth-submit')));
      await tester.pumpAndSettle();

      // app_en.arb: authErrorInvalidCredentials.
      check(
        find.text('Incorrect email or password.').evaluate(),
      ).length.equals(1);
      check(
        find.byKey(const ValueKey('delete-reauth-submit')).evaluate(),
      ).length.equals(1);
      check(fake().currentUser).isNotNull();
    });

    testWidgets('google user: gets the provider re-auth button, which '
        'completes the deletion', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      await fake().signInWithGoogle();
      await tester.pumpAndSettle();

      await _openSheet(tester);
      await _confirm(tester);

      check(
        find.byKey(const ValueKey('delete-reauth-provider')).evaluate(),
      ).length.equals(1);
      check(find.byKey(const ValueKey('delete-password')).evaluate()).isEmpty();

      await tester.tap(find.byKey(const ValueKey('delete-reauth-provider')));
      await tester.pumpAndSettle();

      check(
        find.byKey(const ValueKey('delete-done')).evaluate(),
      ).length.equals(1);
      check(fake().currentUser).isNull();
      check(tester.takeException()).isNull();
    });
  });
}
