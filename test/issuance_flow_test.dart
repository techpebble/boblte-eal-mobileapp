import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/screens/issuance/EALStickerScreen.dart';
import 'package:eal_scanner/screens/issuance/sticker_details_screen.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// One issuance is one purchase holding several sets of stickers.
///
/// The date and company belong to the whole purchase and are chosen once. The
/// pack size and market belong to each set, so they are chosen again for every
/// range — which is what lets one purchase carry different pack sizes. These
/// tests pin that split, and the order the screens enforce.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  setUp(() {
    Get.put(Issuancecontroller());
    DioClient().dio.httpClientAdapter = FakeApiRouter({
      'companies': {'count': 1, 'data': [companyResponse()]},
      'packs': {
        'count': 2,
        'data': [
          packResponse(),
          packResponse(
            id: '64a000000000000000000004',
            name: '180ml',
            bottlesPerCase: 48,
          ),
        ],
      },
    });
  });

  tearDown(() => Get.reset());

  Future<void> pumpIssuance(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GetMaterialApp(home: EALStickerScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('the issuance screen asks only for the date and company', (
    tester,
  ) async {
    await pumpIssuance(tester);

    expect(find.text('Date issued'), findsOneWidget);
    expect(find.text('Company'), findsOneWidget);

    // These now belong to each set of stickers, not to the whole issuance.
    expect(find.text('Pack size'), findsNothing);
    expect(find.text('Market'), findsNothing);

    expect(find.text('STICKERS ADDED'), findsOneWidget);
    expect(find.text('Add details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('details cannot be added before a company is chosen', (
    tester,
  ) async {
    await pumpIssuance(tester);

    expect(find.text('Pick the company first'), findsOneWidget);

    // Tapping does nothing while no company is set.
    await tester.tap(find.text('Add details'));
    await tester.pumpAndSettle();
    expect(find.byType(StickerDetailsScreen), findsNothing);

    await tester.tap(find.text('Company'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Ocean Beverages Pvt. Ltd.').last);
    await tester.pumpAndSettle();

    expect(find.text('Pick the company first'), findsNothing);
  });

  testWidgets('adding details asks for the market and pack size', (
    tester,
  ) async {
    await pumpIssuance(tester);

    await tester.tap(find.text('Company'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Ocean Beverages Pvt. Ltd.').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add details'));
    await tester.pumpAndSettle();

    expect(find.byType(StickerDetailsScreen), findsOneWidget);
    expect(find.text('Pack size'), findsOneWidget);
    expect(find.text('Market'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);

    // The company and date carry through, so there is no doubt what this
    // set of stickers belongs to.
    expect(
      find.textContaining('Blue Ocean Beverages Pvt. Ltd.'),
      findsOneWidget,
    );

    // Scanning waits on the pack size, which sets the case arithmetic.
    final before = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue to scan'),
    );
    expect(before.onPressed, isNull);
    expect(find.text('Choose a pack size first'), findsOneWidget);
  });

  testWidgets('choosing a pack size opens the way to the scan', (
    tester,
  ) async {
    await pumpIssuance(tester);

    await tester.tap(find.text('Company'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Ocean Beverages Pvt. Ltd.').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add details'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pack size'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('180ml').last);
    await tester.pumpAndSettle();

    expect(find.text('180ml · 48 per case'), findsOneWidget);

    final after = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue to scan'),
    );
    expect(after.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
