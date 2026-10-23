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

    // Each title carries its date in the same line, so match on the word.
    expect(find.textContaining('Issued · '), findsOneWidget);
    expect(find.textContaining('Applied · '), findsOneWidget);
    expect(find.textContaining('Dispatched · '), findsOneWidget);

    // Each stage carries what it is: the item it was stuck on, and the
    // depot it went to.
    expect(find.text('Old Monk Gold Reserve 180ml'), findsOneWidget);
    expect(find.text('KSBCL Depot - Attibele'), findsOneWidget);
    expect(find.textContaining('30 cases linked'), findsOneWidget);
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
