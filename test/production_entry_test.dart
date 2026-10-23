import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/screens/usages/EALStickerScreen.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// Recording a run is a run of ranges, one after another, so the footer
/// carries the scan rather than a way out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  tearDown(() => Get.reset());

  Future<void> pump(WidgetTester tester) async {
    Get.put(UsageController());
    DioClient().dio.httpClientAdapter = FakeApiRouter({});

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(GetMaterialApp(home: EALStickerScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('the footer scans; leaving is the close in the header', (
    tester,
  ) async {
    await pump(tester);

    // Nothing recorded yet, so it reads as the first scan.
    expect(find.widgetWithText(ElevatedButton, 'Scan a range'), findsOneWidget);

    // Done had nothing to do: every range is written to the server as it
    // is scanned.
    expect(find.text('Done'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Close'), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('the scan waits until an item is chosen', (tester) async {
    await pump(tester);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Scan a range'),
    );

    // A range has to attach to an item: the pack size is what turns it
    // into cases.
    expect(button.onPressed, isNull);
    expect(find.text('Choose item'), findsOneWidget);
  });
}
