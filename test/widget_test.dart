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

  testWidgets('the item picker lists active items with no toggle to undo it', (
    tester,
  ) async {
    Get.put(UsageController());
    DioClient().dio.httpClientAdapter = FakeApiAdapter({
      'count': 1,
      'data': [itemResponse(isActive: true)],
    });

    await tester.pumpWidget(const GetMaterialApp(home: EALStickerScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose item'));
    await tester.pumpAndSettle();

    expect(find.text('Test item'), findsOneWidget);

    // The list is fetched active-only, so a switch over it could only ever
    // turn off a filter that nothing needs.
    expect(find.text('Active only'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Active items only.'), findsOneWidget);
  });

  testWidgets('the request asks the server for active items only', (
    tester,
  ) async {
    Get.put(UsageController());
    final api = FakeApiAdapter({
      'count': 1,
      'data': [itemResponse(isActive: true)],
    });
    DioClient().dio.httpClientAdapter = api;

    await tester.pumpWidget(const GetMaterialApp(home: EALStickerScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose item'));
    await tester.pumpAndSettle();

    final itemRequests =
        api.requests.where((r) => r.path.contains('items')).toList();
    expect(itemRequests, isNotEmpty);
    expect(itemRequests.last.queryParameters['isActive'], 'true');
  });
}
