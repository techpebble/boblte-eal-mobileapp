import 'package:eal_scanner/main.dart';
import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/screens/usages/EALStickerScreen.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  tearDown(() => Get.reset());

  testWidgets('signed-out users see the EAL login screen', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('EAL Track'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsOneWidget);

    // Fields carry visible labels now, not placeholder-only hints.
    expect(find.text('Email or mobile'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production picker refreshes items before showing them', (
    tester,
  ) async {
    final controller = Get.put(UsageController());
    DioClient().dio.httpClientAdapter = FakeApiAdapter({
      'count': 1,
      'data': [itemResponse(isActive: true)],
    });
    await tester.pumpWidget(const GetMaterialApp(home: EALStickerScreen()));
    await tester.pumpAndSettle();
    expect(controller.items, hasLength(1));

    // Simulate the item being deactivated while the production screen is open.
    final refreshedApi = FakeApiAdapter({'count': 0, 'data': []});
    DioClient().dio.httpClientAdapter = refreshedApi;
    await tester.tap(find.text('Choose item'));
    await tester.pumpAndSettle();

    expect(refreshedApi.requests, hasLength(1));
    expect(find.text('No active items found.'), findsOneWidget);
    expect(find.text('Test item'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
