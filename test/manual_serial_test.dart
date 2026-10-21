import 'package:eal_scanner/screens/scan/manual_serial_screen.dart';
import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A typed serial is recorded exactly as entered.
///
/// A *scanned* code names the last bottle of its case, so the first scan is
/// counted back a full case. Someone typing is reading the serial they want
/// recorded, so the same adjustment would store a number they never saw.
/// These two rules are easy to confuse, so both are pinned here.
void main() {
  Future<void> typeSerial(
    WidgetTester tester, {
    required bool isFrom,
    required String digits,
    required String counterpart,
    int bottlesPerCase = 12,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManualSerialScreen(
          prefix: 'ML1',
          bottlesPerCase: bottlesPerCase,
          isFrom: isFrom,
          counterpartSerial: counterpart,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Digits come from the keypad built into the screen, not the system
    // keyboard, so each one is a tap.
    for (final digit in digits.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('a typed first serial is not counted back a case', (
    tester,
  ) async {
    // Typing 12001 against a last serial of 13920 gives 1,920 labels.
    // Counting back a case would start the run at 11990 and give 1,931.
    await typeSerial(
      tester,
      isFrom: true,
      digits: '12001',
      counterpart: '0000013920',
    );

    expect(find.text('1,920'), findsOneWidget);
    expect(find.text('1,931'), findsNothing);
    expect(find.text('160'), findsOneWidget, reason: '1,920 / 12 per case');
  });

  testWidgets('a typed last serial is used as entered', (tester) async {
    await typeSerial(
      tester,
      isFrom: false,
      digits: '13920',
      counterpart: '0000012001',
    );

    expect(find.text('1,920'), findsOneWidget);
    expect(find.text('160'), findsOneWidget);
  });

  testWidgets('the case size does not shift a typed serial', (tester) async {
    // A 48-per-case item would move the start by 47 if the scan rule were
    // applied here. The label count must not change.
    await typeSerial(
      tester,
      isFrom: true,
      digits: '12001',
      counterpart: '0000013920',
      bottlesPerCase: 48,
    );

    expect(find.text('1,920'), findsOneWidget);
    expect(find.text('40'), findsOneWidget, reason: '1,920 / 48 per case');
  });

  test('a scanned code is still counted back a case', () {
    // The scanner path is unchanged: the code names the last bottle of its
    // case, so the run starts a full case earlier.
    expect(EalQrCodec.firstSerialOfCase(12012, 12), '0000012001');
    expect(EalQrCodec.firstSerialOfCase(13920, 48), '0000013873');
  });

  bool submitEnabled(WidgetTester tester) {
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Use this serial'),
    );
    return button.onPressed != null;
  }

  testWidgets('a whole number of cases can be accepted', (tester) async {
    await typeSerial(
      tester,
      isFrom: true,
      digits: '12001',
      counterpart: '0000013920',
    );

    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('a part case cannot be accepted', (tester) async {
    // 12001 to 13921 is 1,921 labels: one over 160 whole cases of 12.
    await typeSerial(
      tester,
      isFrom: true,
      digits: '12001',
      counterpart: '0000013921',
    );

    expect(submitEnabled(tester), isFalse);
    expect(find.text('Not a whole number of cases'), findsOneWidget);
  });

  testWidgets('the other end is checked the same way', (tester) async {
    await typeSerial(
      tester,
      isFrom: false,
      digits: '13921',
      counterpart: '0000012001',
    );

    expect(submitEnabled(tester), isFalse);
  });
}
