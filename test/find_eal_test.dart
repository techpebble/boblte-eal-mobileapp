import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eal_scanner/controllers/findEalController.dart';
import 'package:eal_scanner/screens/find_eal_screen.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// Tracing one label: the screen reached from home, where the question is
/// not "what happened today" but "where has this one been".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  tearDown(() => Get.reset());

  /// The find endpoint answers 404 for a serial it cannot place, which is
  /// an answer rather than a failure, so the adapter has to be able to
  /// send one.
  final found = {
    'respondData': {
      'serial': 2401,
      'prefix': 'AAA',
      'issuance': [
        {
          'id': 'i1',
          'dateIssued': '2026-10-20T00:00:00.000Z',
          'serialFrom': 1,
          'serialTo': 9600,
          'issuedQuantity': 9600,
          'balanceQuantity': 1200,
          'company': {'name': 'Blue Ocean Beverages Pvt. Ltd.'},
          'createdBy': {'fullName': 'Priya Nair'},
          'createdAt': '2026-10-20T08:12:00.000Z',
          'market': 'local',
          'pack': {'name': '180ml', 'bottlesPerCase': 48},
          'prefix': 'AAA',
        },
      ],
      'usage': [
        {
          'id': 'u1',
          'dateUsed': '2026-10-22T00:00:00.000Z',
          'serialFrom': 1,
          'serialTo': 4800,
          'usedQuantityInCases': 100,
          'balanceQuantityInCases': 30,
          'createdBy': {'fullName': 'Demo User'},
          'createdAt': '2026-10-22T09:14:00.000Z',
          'item': {'name': 'Old Monk Gold Reserve 180ml'},
        },
      ],
      'ealDispatches': [
        {
          'id': 'd1',
          'dispatchId': 'n1',
          'dateDispatched': '2026-10-22T00:00:00.000Z',
          'serialFrom': 1,
          'serialTo': 1440,
          'usedQuantityInCases': 30,
          'createdBy': {'fullName': 'Demo User'},
          'createdAt': '2026-10-23T11:48:00.000Z',
        },
      ],
      'dispatches': [
        {
          '_id': 'n1',
          'status': 'final',
          'deliveryTo': {'name': 'KSBCL Depot - Attibele'},
          'company': {'name': 'Blue Ocean Beverages Pvt. Ltd.'},
        },
      ],
    },
  };

  void serve(Object body, {int status = 200}) {
    DioClient().dio.httpClientAdapter = _FixedAdapter(body, status);
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GetMaterialApp(home: FindEalScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('it says what to do before anything is looked up', (
    tester,
  ) async {
    serve(found);
    await pump(tester);

    expect(find.text('Type the number, or scan the label'), findsOneWidget);

    // Nothing to send yet, so the button is dead rather than inviting.
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Find this label'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a label reads as its three stages, in order', (tester) async {
    serve(found);
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'AAA0000002401');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Find this label'));
    await tester.pumpAndSettle();

    // The stage, and its own date beside it rather than inside the title.
    expect(find.text('Issued'), findsOneWidget);
    expect(find.text('Applied'), findsOneWidget);
    expect(find.text('Dispatched'), findsOneWidget);
    expect(find.text('20 Oct 2026'), findsOneWidget);
    expect(find.text('22 Oct 2026'), findsNWidgets(2));

    // Each stage carries what it is: the item it was stuck on, and the
    // depot it went to.
    expect(find.text('Old Monk Gold Reserve 180ml'), findsOneWidget);
    expect(find.text('KSBCL Depot - Attibele'), findsOneWidget);
    expect(find.textContaining('30 cases linked'), findsOneWidget);
  });

  testWidgets('each stage says who recorded it, and when', (tester) async {
    serve(found);
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'AAA0000002401');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Find this label'));
    await tester.pumpAndSettle();

    // Entered the same day as the record's own date: the time alone.
    expect(find.text('Priya Nair · entered 08:12'), findsOneWidget);
    expect(find.text('Demo User · entered 09:14'), findsOneWidget);

    // Linked the day after the note's date, so the footnote carries its
    // own date too — a gap worth seeing.
    expect(find.text('Demo User · linked 23 Oct, 11:48'), findsOneWidget);
  });

  testWidgets('the dispatch stage is shown, not described in passing', (
    tester,
  ) async {
    serve(found);
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'AAA0000002401');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Find this label'));
    await tester.pumpAndSettle();

    // Linked is not the same as gone, so the note's own stage is on the
    // row, in the pill the dispatch list uses.
    expect(find.text('Final · 2/5'), findsOneWidget);
    expect(find.textContaining('note is Final'), findsNothing);
  });

  testWidgets('the issuance figures name what they count', (tester) async {
    serve(found);
    await pump(tester);

    await tester.enterText(find.byType(TextField), '2401');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Find this label'));
    await tester.pumpAndSettle();

    // They belong to the issuance, not to the label: "9,600 issued ·
    // 1,200 unused" read as though this label had never been used.
    expect(
      find.text('9,600 labels in this issuance · 1,200 of them still unused'),
      findsOneWidget,
    );
  });

  testWidgets('every issuance that carries the number is shown', (
    tester,
  ) async {
    // A serial is unique within a book, not across them: on this server
    // 2000 sits in a 180ml book and a 1000ml one. Drawing only the first
    // put "9,000 issued · 9,000 unused" beside a run that had taken its
    // labels from the other.
    final body = found['respondData'] as Map<String, dynamic>;
    final twoBooks = {
      'respondData': {
        ...body,
        'issuance': [
          ...(body['issuance'] as List),
          {
            'id': 'i2',
            'dateIssued': '2026-10-17T00:00:00.000Z',
            'serialFrom': 1,
            'serialTo': 288000,
            'issuedQuantity': 288000,
            'balanceQuantity': 278400,
            'company': {'name': 'Blue Ocean Beverages Pvt. Ltd.'},
            'createdBy': {'fullName': 'Priya Nair'},
            'createdAt': '2026-10-17T07:40:00.000Z',
            'market': 'local',
            'pack': {'name': '1000ml', 'bottlesPerCase': 9},
            'prefix': 'AAA',
          },
        ],
      },
    };
    serve(twoBooks);
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'AAA0000002401');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Find this label'));
    await tester.pumpAndSettle();

    expect(find.text('Issued'), findsNWidgets(2));
    expect(find.text('2 issuances carry this number'), findsOneWidget);

    // Each one says which pack it is for, so they can be told apart.
    expect(find.text('180ml · 48 per case'), findsOneWidget);
    expect(find.text('1000ml · 9 per case'), findsOneWidget);
  });

  testWidgets('a label that has gone no further keeps its rows', (
    tester,
  ) async {
    final issuedOnly = {
      'respondData': {
        ...(found['respondData'] as Map<String, dynamic>),
        'usage': <dynamic>[],
        'ealDispatches': <dynamic>[],
        'dispatches': <dynamic>[],
      },
    };
    serve(issuedOnly);
    await pump(tester);

    await tester.enterText(find.byType(TextField), '2401');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Find this label'));
    await tester.pumpAndSettle();

    // Not a gap to interpret: the rows stay and say what has not happened.
    expect(find.text('Not applied yet'), findsOneWidget);
    expect(find.text('Not dispatched yet'), findsOneWidget);
    expect(find.text('Still in finished stock.'), findsOneWidget);
  });

  testWidgets('a number the server cannot place is a state, not an error', (
    tester,
  ) async {
    serve({'error': 'EAL issuance not found'}, status: 404);
    await pump(tester);

    await tester.enterText(find.byType(TextField), '999999');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Find this label'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing issued with this number'), findsOneWidget);
    expect(find.textContaining('another company'), findsOneWidget);
    expect(find.text('That did not work'), findsNothing);
  });

  test('the query has to carry digits before anything is sent', () {
    final controller = FindEalController();

    expect(controller.canSearch, isFalse);
    controller.query.value = 'AAA';
    expect(controller.canSearch, isFalse);
    controller.query.value = 'AAA0000002401';
    expect(controller.canSearch, isTrue);
  });
}

/// Answers every request with one body and one status.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.body, this.status);

  final Object body;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
