import 'package:eal_scanner/screens/scan/scan_success_screen.dart';
import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/theme/app_theme.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The confirmation shown once a range is on the server.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final target = ScanTarget(
    module: AppModule.issuance,
    title: 'Record issuance',
    contextLine: '90ml · Local · Blue Ocean Beverages Pvt. Ltd.',
    bottlesPerCase: 96,
    unit: ScanUnit.labels,
    submit: (_) async => null,
  );

  const draft = ScanDraft(
    prefix: 'EXT',
    serialFrom: '2804736001',
    serialTo: '2804832000',
  );

  Future<double> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ScanSuccessScreen(
          target: target,
          draft: draft,
          labels: 96000,
          cases: 1000,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.view.physicalSize.height / tester.view.devicePixelRatio;
  }

  testWidgets('the bar holding only the close button takes the page colour', (
    tester,
  ) async {
    await pump(tester);

    // White, it reads as an empty header band above a grey screen — a
    // section of its own holding nothing.
    final bar = tester.widget<AppBar>(find.byType(AppBar));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(bar.backgroundColor, scaffold.backgroundColor);
    expect(bar.backgroundColor, isNot(AppColors.surface));
  });

  testWidgets('the two actions sit at the bottom, not under the receipt', (
    tester,
  ) async {
    final height = await pump(tester);

    // Floating mid-screen they left the lower half of the phone empty, and
    // a thumb reaches the bottom more easily besides.
    final done = tester.getRect(find.widgetWithText(ElevatedButton, 'Done'));
    expect(done.bottom, greaterThan(height - 110));

    final another = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Record another range'),
    );
    expect(another.bottom, lessThan(done.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('it says what was recorded, and the range it came from', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('96,000 labels recorded'), findsOneWidget);
    expect(find.text('1,000 cases'), findsOneWidget);
    expect(find.textContaining('Saved'), findsOneWidget);
  });
}
