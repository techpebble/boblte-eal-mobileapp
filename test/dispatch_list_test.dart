import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/screens/dispatches/dispatch_filter_sheet.dart';
import 'package:eal_scanner/screens/dispatches/dispatchListScreen.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// The dispatch list reads like the other two, with two differences that
/// come from the record: search keeps a row, and a note does not unfold.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  Map<String, dynamic> noteJson({
    String id = 'd1',
    String depot = 'Central Depot',
    String company = 'Blue Ocean Beverages Pvt. Ltd.',
    String market = 'local',
    String status = 'final',
    String vehicle = 'BR 01 GA 4472',
    required int cases,
    required int linked,
    int lines = 2,
  }) {
    return {
      '_id': id,
      'status': status,
      'deliveryTo': {'_id': 'dep$depot', 'name': depot},
      'company': {'_id': 'c1', 'name': company},
      'market': market,
      'totalQuantity': cases,
      'EALIssuedTotalQuantity': linked,
      'vehicleDetails': {
        'vehicleNumber': vehicle,
        'driverName': 'A Driver',
        'driverContact': '9000000000',
      },
      'dateDispatched': '2026-10-21T00:00:00.000Z',
      'items': [
        for (var i = 0; i < lines; i++)
          {
            '_id': 'i$id$i',
            'item': {'_id': 'it$i', 'name': 'Item $i', 'bottlesPerCase': 12},
            'quantityInCases': cases ~/ lines,
            'EALIssuedQuantity': linked ~/ lines,
            'EALLinks': <dynamic>[],
          },
      ],
    };
  }

  late DispatchController controller;

  setUp(() {
    controller = Get.put(DispatchController());
    DioClient().dio.httpClientAdapter = FakeApiRouter({
      'dispatch': {
        'count': 3,
        'data': [
          noteJson(cases: 2600, linked: 2440),
          noteJson(
            id: 'd2',
            depot: 'North Depot',
            cases: 2000,
            linked: 1760,
            vehicle: 'BR 06 KT 1180',
            lines: 3,
          ),
          noteJson(
            id: 'd3',
            depot: 'Riverside Depot',
            market: 'export',
            status: 'draft',
            vehicle: '',
            cases: 1200,
            linked: 0,
            lines: 1,
          ),
        ],
      },
    });
  });

  tearDown(() => Get.reset());

  Future<void> pumpList(WidgetTester tester, {double width = 384}) async {
    tester.view.physicalSize = Size(width * 2, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GetMaterialApp(home: DispatchListScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('it groups by company and market', (tester) async {
    await pumpList(tester);

    expect(controller.dispatches, hasLength(3));
    expect(find.text('3 notes'), findsOneWidget);

    // One heading per company and market, so the same company appears twice.
    expect(find.text('Blue Ocean Beverages Pvt. Ltd.'), findsNWidgets(2));
    expect(find.text('Central Depot'), findsOneWidget);
    expect(find.text('Riverside Depot'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cases lead, and short is the figure beside them', (
    tester,
  ) async {
    await pumpList(tester);

    expect(find.text('2,600'), findsOneWidget);
    expect(find.text('cases'), findsNWidgets(3));

    // 2,600 − 2,440 = 160 outstanding on the first note.
    expect(find.text('160'), findsOneWidget);
    expect(find.text('short'), findsNWidgets(2));

    // Totalled above the companies: 5,800 cases, 1,600 short.
    expect(find.text('ALL COMPANIES'), findsOneWidget);
    expect(find.textContaining('5,800 cases'), findsOneWidget);
    expect(find.textContaining('1,600 short'), findsOneWidget);
  });

  testWidgets('nothing linked yet says so, rather than showing the total', (
    tester,
  ) async {
    await pumpList(tester);

    // Riverside has 1,200 cases and none linked. Printing 1,200 short there
    // would read as the same state as a note that is nearly done.
    expect(find.text('Not started'), findsOneWidget);
  });

  testWidgets('a note does not unfold: its lines are not on this list', (
    tester,
  ) async {
    await pumpList(tester);

    // The lines belong to the note's own screen; listing them here buries
    // the next depot.
    expect(find.text('Item 0'), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));
  });

  testWidgets('search keeps its row, unlike the other two lists', (
    tester,
  ) async {
    await pumpList(tester);

    // A vehicle number is not something to pick from a list of what exists.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Depot, vehicle or driver'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'KT 1180');
    await tester.pumpAndSettle();

    expect(find.text('North Depot'), findsOneWidget);
    expect(find.text('Central Depot'), findsNothing);
  });

  testWidgets('clearing the search empties the box, not just the list', (
    tester,
  ) async {
    await pumpList(tester);

    await tester.enterText(find.byType(TextField), 'nothing matches this');
    await tester.pumpAndSettle();
    expect(find.text('Clear the search'), findsOneWidget);

    await tester.tap(find.text('Clear the search'));
    await tester.pumpAndSettle();

    // The box kept its own text, so this refilled the list and left the
    // words sitting above it, the two disagreeing.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
    expect(find.text('Central Depot'), findsOneWidget);
  });

  testWidgets('a search can be cleared from the box itself', (tester) async {
    await pumpList(tester);

    // No × at all until there is something to clear.
    expect(find.byTooltip('Clear the search'), findsNothing);

    await tester.enterText(find.byType(TextField), 'KT 1180');
    await tester.pumpAndSettle();
    expect(find.text('Central Depot'), findsNothing);

    // Without this, a search that matched something could not be undone:
    // clearing was only offered on the empty state.
    await tester.tap(find.byTooltip('Clear the search'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
    expect(find.text('Central Depot'), findsOneWidget);
  });

  testWidgets('the pills are gone; the filter is behind one button', (
    tester,
  ) async {
    await pumpList(tester);

    expect(find.text('Last 7 days'), findsNothing);
    expect(find.text('Draft'), findsNothing);
    expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(DispatchFilterSheet), findsOneWidget);
    expect(find.text('DEPOT'), findsOneWidget);
    expect(find.text('STAGE'), findsOneWidget);

    // Dispatch's own colour throughout: the sheet was copied from
    // production's and carried teal in it.
    final market = tester.widget<Container>(
      find
          .descendant(
            of: find.ancestor(
              of: find.text('Any'),
              matching: find.byType(InkWell),
            ),
            matching: find.byType(Container),
          )
          .first,
    );
    final box = market.decoration! as BoxDecoration;
    expect(box.color, isNot(AppColors.tealTint));
  });

  testWidgets('the filter narrows by stage, on confirm', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(DispatchFilterSheet),
        matching: find.text('Draft'),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.statusFilter.value, '', reason: 'not applied yet');

    await tester.tap(find.text('Show 1 note'));
    await tester.pumpAndSettle();

    expect(controller.statusFilter.value, 'draft');
    expect(find.text('Riverside Depot'), findsOneWidget);
    expect(find.text('Central Depot'), findsNothing);
  });

  testWidgets('the date control opens the shared range sheet', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.calendar_today_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Dates'), findsOneWidget);
    expect(find.text('Show these dates'), findsOneWidget);
  });

  testWidgets('the filter button sits hard against the right edge', (
    tester,
  ) async {
    for (final width in const [384.0, 1200.0]) {
      await pumpList(tester, width: width);

      final button = tester.getRect(find.byIcon(Icons.filter_list_rounded));
      expect(
        button.right,
        closeTo(width - 18 - 10 - 1.5, 2),
        reason: 'at ${width}px the filter button drifted from the right edge',
      );
    }
  });
}
