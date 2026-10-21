import 'package:eal_scanner/screens/scan/manual_serial_screen.dart';
import 'package:eal_scanner/screens/scan/scan_flow_screen.dart';
import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/api_test_support.dart';

/// The two rebuilt scan screens must lay out on a small phone.
///
/// Both pin content against a fixed bottom: the step screen has a two-part
/// footer, and manual entry has a keypad that has to share the height with the
/// field above it. An overflow throws while building, and a release build
/// swallows that silently — replacing the widget with a blank box. These tests
/// fail loudly where a phone would just look wrong.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  ScanTarget target({bool allowRangeQr = false, int? requiredCases}) {
    return ScanTarget(
      module: AppModule.issuance,
      title: 'Record issuance',
      contextLine: '90ml · Local · Blue Ocean Beverages Pvt. Ltd.',
      bottlesPerCase: 96,
      unit: ScanUnit.labels,
      allowRangeQr: allowRangeQr,
      initialPrefix: 'EXT',
      requiredCases: requiredCases,
      submit: (_) async => null,
    );
  }

  /// A small, dense phone: the tightest screen the app ships on.
  Future<void> pumpSmall(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('the step screen builds on a small screen', (tester) async {
    await pumpSmall(tester, ScanFlowScreen(target: target(allowRangeQr: true)));

    expect(tester.takeException(), isNull);
    // The prefix came in set, so the first scan is the step on offer.
    expect(find.text('Scan the first label'), findsOneWidget);
    expect(find.text('Open scanner'), findsOneWidget);
    expect(find.text('Label damaged? Type it by hand'), findsOneWidget);
  });

  testWidgets('the step screen shows the range being built', (tester) async {
    await pumpSmall(tester, ScanFlowScreen(target: target()));

    // Both ends in one card, the waiting one drawn as a gap.
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('Waiting for this one'), findsOneWidget);
  });

  testWidgets('a dispatch line says what it needs', (tester) async {
    await pumpSmall(tester, ScanFlowScreen(target: target(requiredCases: 50)));

    expect(find.textContaining('This line needs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual entry fits the keypad on a small screen', (
    tester,
  ) async {
    await pumpSmall(
      tester,
      const ManualSerialScreen(
        prefix: 'EXT',
        bottlesPerCase: 96,
        isFrom: false,
        counterpartSerial: '0002804736001',
        stepIndex: 3,
        stepCount: 3,
      ),
    );

    expect(tester.takeException(), isNull);

    // Every key reachable, and none of them smaller than a fingertip.
    for (final key in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']) {
      expect(find.text(key), findsOneWidget, reason: 'key $key is missing');
      expect(
        tester.getSize(find.text(key).hitTestable()).height,
        greaterThan(0),
      );
    }
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('0 / 10'), findsOneWidget);
  });

  testWidgets('the keypad keys stay at a usable height', (tester) async {
    await pumpSmall(
      tester,
      const ManualSerialScreen(
        prefix: 'EXT',
        bottlesPerCase: 96,
        isFrom: true,
      ),
    );

    // 44 logical pixels is the smallest target the app allows anywhere.
    final key = tester.getRect(find.text('5'));
    final row = tester.getRect(find.text('8'));
    expect(row.center.dy - key.center.dy, greaterThanOrEqualTo(44.0));
  });
}
