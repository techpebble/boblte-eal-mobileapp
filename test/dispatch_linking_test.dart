import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/screens/dispatches/DispatchDetailScreen.dart';
import 'package:eal_scanner/screens/dispatches/EALDetailScreen.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// Labels may only be changed while a note is Final.
///
/// A draft's lines can still change, so labels would be against numbers
/// that no longer hold; once it is loaded the quantities have been checked
/// against the lorry. The server refuses the rest, and these pin that the
/// app never offers what it would refuse.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  tearDown(() => Get.reset());

  Map<String, dynamic> note(String status) => {
    '_id': 'd1',
    'status': status,
    'deliveryTo': {'_id': 'dep', 'name': 'Central Depot'},
    'company': {'_id': 'c1', 'name': 'Blue Ocean'},
    'market': 'local',
    'totalQuantity': 100,
    'EALIssuedTotalQuantity': 40,
    'vehicleDetails': {
      'vehicleNumber': 'BR 01 GA 4472',
      'driverName': 'A Driver',
      'driverContact': '9000000000',
    },
    'dateDispatched': '2026-10-21T00:00:00.000Z',
    'items': [
      {
        '_id': 'line1',
        'item': {'_id': 'it1', 'name': 'OC Deluxe 750ml', 'bottlesPerCase': 12},
        'quantityInCases': 100,
        'EALIssuedQuantity': 40,
        'EALLinks': <dynamic>[],
      },
    ],
  };

  Future<void> pump(WidgetTester tester, String status, Widget screen) async {
    Get.put(DispatchController());
    DioClient().dio.httpClientAdapter = FakeApiRouter({
      'dispatch': {
        'count': 1,
        'data': [note(status)],
      },
    });
    Get.find<DispatchController>().fetchDispatches();

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(GetMaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  group('the line screen', () {
    const screen = EALDetailScreen(dispatchId: 'd1', dispatchItemId: 'line1');

    testWidgets('offers the scan while the note is final', (tester) async {
      await pump(tester, 'final', screen);

      expect(find.textContaining('Scan the missing'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);

      // Where it can be linked, the banner says how much to link.
      expect(find.textContaining('more labels to balance'), findsOneWidget);
    });

    testWidgets('on a draft it says why instead', (tester) async {
      await pump(tester, 'draft', screen);

      expect(find.textContaining('Scan the missing'), findsNothing);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.textContaining('still a draft'), findsOneWidget);
      expect(find.textContaining('marked Final'), findsOneWidget);

      // And nothing above the lock tells them to link anyway. The screen
      // said "Link 2,400 more labels" two inches above "labels can be
      // linked once it is marked Final".
      expect(find.textContaining('Link 2,880 more labels'), findsNothing);
      expect(
        find.textContaining('once this line can be linked'),
        findsOneWidget,
      );
    });

    testWidgets('once loaded, the labels are settled', (tester) async {
      await pump(tester, 'loaded', screen);

      expect(find.textContaining('Scan the missing'), findsNothing);
      expect(find.textContaining('already been Loaded'), findsOneWidget);
    });
  });

  group('the note screen', () {
    const screen = DispatchDetailScreen(dispatchId: 'd1');

    testWidgets('a final note is asked to link what is missing', (
      tester,
    ) async {
      await pump(tester, 'final', screen);

      expect(find.textContaining('Link the missing'), findsOneWidget);
    });

    testWidgets('a draft is not sent to a screen that can only say no', (
      tester,
    ) async {
      await pump(tester, 'draft', screen);

      expect(find.textContaining('Link the missing'), findsNothing);
      expect(find.text('Review the lines'), findsOneWidget);

      // And the notice at the top says what to do next, which on a draft is
      // not "link labels".
      expect(find.textContaining('Mark it Final'), findsOneWidget);
    });

    testWidgets('one edit control, not two', (tester) async {
      await pump(tester, 'final', screen);

      // It was in the app bar and the footer, both opening one sheet.
      expect(find.text('Edit'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });
  });
}
