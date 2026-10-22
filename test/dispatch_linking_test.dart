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

    testWidgets('a line that is covered offers no more scanning', (
      tester,
    ) async {
      // The server allows no more than the cases ordered, so the button
      // that used to read "Link another range" here could only come back
      // refused.
      Get.put(DispatchController());
      final covered = note('final');
      covered['EALIssuedTotalQuantity'] = 100;
      covered['items'][0]['EALIssuedQuantity'] = 100;
      covered['items'][0]['EALLinks'] = [
        {
          '_id': 'l1',
          'prefix': 'DLK',
          'serialFrom': 1,
          'serialTo': 1200,
          'quantityInCases': 100,
        },
      ];
      DioClient().dio.httpClientAdapter = FakeApiRouter({
        'dispatch': {
          'count': 1,
          'data': [covered],
        },
      });
      Get.find<DispatchController>().fetchDispatches();

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.8125;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        GetMaterialApp(
          home: KeyedSubtree(key: UniqueKey(), child: screen),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Link another range'), findsNothing);
      expect(find.textContaining('Scan the missing'), findsNothing);

      // Not the lock either: this line is not refused, it is finished. The
      // banner says so, and the footer bar is gone rather than repeating it.
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
      expect(find.text('Fully labelled'), findsOneWidget);

      // The third figure says what is left, not "0 complete".
      expect(find.text('short'), findsOneWidget);
      expect(find.text('complete'), findsNothing);
      expect(find.byType(BottomAppBar), findsNothing);
      expect(
        find.textContaining('Unlinking returns those labels'),
        findsOneWidget,
      );
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

    testWidgets('the footer does not choose a line to scan', (tester) async {
      await pump(tester, 'final', screen);

      // It used to jump to the first short line. Which line is being
      // scanned is the operator's to say — on a note with three short
      // lines that guess was usually wrong.
      expect(find.textContaining('Link the missing'), findsNothing);
      expect(find.text('Review the lines'), findsNothing);

      // The lines are the way in, and they look like it.
      expect(
        find.text('Open the line you are scanning to link its labels.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('a draft says what has to happen first', (tester) async {
      await pump(tester, 'draft', screen);

      expect(find.textContaining('Mark it Final'), findsOneWidget);

      // And no invitation to open a line for scanning, since it cannot be
      // scanned yet.
      expect(
        find.textContaining('Open the line you are scanning'),
        findsNothing,
      );
    });

    testWidgets('the footer carries what belongs to the whole note', (
      tester,
    ) async {
      await pump(tester, 'final', screen);

      // One control, and it says what it does. It was "Edit" in the app bar
      // and a bare pencil in the footer, both opening one sheet.
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Vehicle, driver and stage'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('a line card counts its ranges and does not print one', (
      tester,
    ) async {
      // It used to print the first range beside the count, so a line linked
      // across two ranges read as if all of it sat in the first - here, 5
      // cases of the 40 linked.
      Get.put(DispatchController());
      final linked = note('final');
      linked['items'][0]['EALLinks'] = [
        {
          '_id': 'l1',
          'prefix': 'DLK',
          'serialFrom': 6001,
          'serialTo': 6060,
          'quantityInCases': 5,
        },
        {
          '_id': 'l2',
          'prefix': 'DLK',
          'serialFrom': 9001,
          'serialTo': 9420,
          'quantityInCases': 35,
        },
      ];
      DioClient().dio.httpClientAdapter = FakeApiRouter({
        'dispatch': {
          'count': 1,
          'data': [linked],
        },
      });
      Get.find<DispatchController>().fetchDispatches();

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.8125;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        GetMaterialApp(
          home: KeyedSubtree(key: UniqueKey(), child: screen),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 ranges linked'), findsOneWidget);
      expect(find.textContaining('6001'), findsNothing);
      expect(find.textContaining('9001'), findsNothing);
    });

    testWidgets('a long company name is not cut off after one line', (
      tester,
    ) async {
      await pump(tester, 'final', screen);

      final name = tester.widget<Text>(find.text('Blue Ocean'));
      expect(name.maxLines, 2);
    });
  });
}
