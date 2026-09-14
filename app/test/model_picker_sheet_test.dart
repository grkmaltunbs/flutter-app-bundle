import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_kit/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_app/src/theme.dart';
import 'package:kit_app/src/widgets/model_picker_sheet.dart';

void main() {
  test('confirmation is explicit even while the same model is pending', () {
    expect(
      modelConfirmationLabel(ModelConfirmation.unknown, null),
      'Not yet confirmed by the server',
    );
    expect(
      modelConfirmationLabel(ModelConfirmation.pending, 'alpha'),
      'Waiting for the next turn to confirm\nLast server confirmed: alpha',
    );
    expect(
      modelConfirmationLabel(ModelConfirmation.confirmed, 'actual'),
      'Server confirmed: actual',
    );
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 780),
    const Size(440, 956),
    const Size(768, 1024),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0, 3.12]) {
      testWidgets('picker $size at ${scale}x wraps and awaits selection', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final pending = Completer<void>();
        String? chosen;
        const model =
            'gpt-model-with-a-long-server-reported-identifier-2026-09-14';
        await tester.pumpWidget(
          MaterialApp(
            theme: kitTheme(scale == 2 ? KitTokens.dark : KitTokens.light),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: ModelPickerSheet(
                  selected: model,
                  models: const [model, 'alternate'],
                  confirmation: ModelConfirmation.pending,
                  confirmedModel: model,
                  onSelect: (_) => pending.future,
                  onSelected: (value) => chosen = value,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final choice = find.byKey(const ValueKey('model-choice-alternate'));
        await tester.scrollUntilVisible(choice, 250);
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(choice).height, greaterThanOrEqualTo(48));
        await tester.tap(choice);
        await tester.pump();
        expect(chosen, isNull);
        pending.complete();
        await tester.pump();
        expect(chosen, 'alternate');
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('unverified catalog is honest and errors keep picker open', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kitTheme(KitTokens.light),
        home: Scaffold(
          body: ModelPickerSheet(
            selected: 'default',
            models: const [],
            confirmation: ModelConfirmation.unknown,
            confirmedModel: null,
            onSelect: (_) async => throw StateError('host offline'),
            onSelected: (_) => fail('failed selection must not close'),
          ),
        ),
      ),
    );
    expect(find.textContaining('have not been verified'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('model-choice-default')));
    await tester.pump();
    expect(find.textContaining('host offline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
