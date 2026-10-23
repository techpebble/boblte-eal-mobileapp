import 'package:eal_scanner/controllers/dashboardController.dart';
import 'package:eal_scanner/screens/homeScreen.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// Home is the screen the app opens on, so what it offers is what the app
/// is understood to be for.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  tearDown(() => Get.reset());

  Future<void> pump(WidgetTester tester) async {
    DioClient().dio.httpClientAdapter = FakeApiRouter({
      'dashboard': {'kpis': {}, 'period': {}, 'recentMovement': <dynamic>[]},
    });

    Get.put(DashboardController());

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GetMaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('the band carries the brand, and no clock', (tester) async {
    await pump(tester);

    expect(find.text('EAL Track'), findsOneWidget);
    expect(find.text('Excise label control'), findsOneWidget);

    // The pill reported when the figures were last fetched; the page pulls
    // down to refresh, as every list does.
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('the one action is finding a label, not scanning one', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Find EAL'), findsOneWidget);
    expect(
      find.text('Where a label was issued, used and sent'),
      findsOneWidget,
    );

    // Recording is reached from the module that owns it.
    expect(find.text('Scan labels'), findsNothing);
    expect(find.text('What are you scanning?'), findsNothing);
  });
}
