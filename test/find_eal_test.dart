import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eal_scanner/controllers/findEalController.dart';
import 'package:eal_scanner/screens/find_eal_book_screen.dart';
import 'package:eal_scanner/screens/find_eal_screen.dart';
import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// Tracing one label.
///
/// A serial does not name a label on its own: a prefix is reused across
/// packs and the ranges under it overlap. The server settles that where it
/// can — one book holding the serial and it traces that one, several and
/// it asks which — and these pin the app to both halves of that answer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  tearDown(() => Get.reset());

  /// One book held the serial, so the server traced it with the search.
  final traced = {
    'serial': 2401,
    'prefix': 'AAA',
    'state': 'linked',
    'candidates': <dynamic>[],
    'issuance': {
      'id': 'i1',
      'prefix': 'AAA',
      'dateIssued': '2026-10-20T00:00:00.000Z',
      'serialFrom': 1,
      'serialTo': 9600,
      'issuedQuantity': 9600,
      'balanceQuantity': 1200,
      'company': {'name': 'Blue Ocean Beverages Pvt. Ltd.'},
      'createdBy': {'fullName': 'Priya Nair'},
      'createdAt': '2026-10-20T08:12:00.000Z',
      'market': 'local',
      'pack': {'_id': 'p180', 'name': '180ml', 'bottlesPerCase': 48},
    },
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
        'note': {
          '_id': 'n1',
          'status': 'final',
          'deliveryTo': {'name': 'KSBCL Depot - Attibele'},
        },
      },
    ],
  };

  Map<String, dynamic> book(
    String id,
    String pack,
    int perCase,
    int to,
    int unused,
  ) => {
    'id': id,
    'prefix': 'AAA',
    'dateIssued': '2026-10-21T00:00:00.000Z',
    'serialFrom': 1,
    'serialTo': to,
    'issuedQuantity': to,
    'balanceQuantity': unused,
    'company': {'name': 'Blue Ocean Beverages Pvt. Ltd.'},
    'market': 'local',
    'pack': {'_id': 'p$pack', 'name': pack, 'bottlesPerCase': perCase},
  };

  /// What the server sends when only the person holding the bottle can say
  /// which book it came out of.
  final asksWhich = {
    'serial': 2000,
    'prefix': null,
    'needsChoice': true,
    'candidates': [
      book('i1', '180ml', 48, 96000, 86400),
      book('i2', '1000ml', 9, 9000, 9000),
    ],
  };

  late _FixedAdapter adapter;

  void serve(Object body, {int status = 200}) {
    adapter = _FixedAdapter(body, status);
    DioClient().dio.httpClientAdapter = adapter;
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GetMaterialApp(home: FindEalScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> look(WidgetTester tester, String number) async {
    await tester.enterText(find.byType(TextField), number);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Find this label'));
    await tester.pumpAndSettle();
  }

  testWidgets('it says what to do before anything is looked up', (
    tester,
  ) async {
    serve(traced);
    await pump(tester);

    expect(find.text('Type the number, or scan the label'), findsOneWidget);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Find this label'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('one book is traced with the search, in one request', (
    tester,
  ) async {
    serve(traced);
    await pump(tester);
    await look(tester, 'AAA0000002401');

    expect(find.byType(FindEalBookScreen), findsOneWidget);
    expect(find.text('Issued'), findsOneWidget);
    expect(find.text('Applied'), findsOneWidget);
    expect(find.text('Dispatched'), findsOneWidget);

    // Nothing to choose between, so nothing was asked twice.
    expect(adapter.queries, hasLength(1));
    expect(adapter.queries.last.containsKey('issuanceId'), isFalse);
  });

  testWidgets('two books are listed, and neither is read until picked', (
    tester,
  ) async {
    serve(asksWhich);
    await pump(tester);
    await look(tester, '2000');

    expect(find.text('2 books carry this number'), findsOneWidget);
    expect(find.text('180ml · 48 per case'), findsOneWidget);
    expect(find.text('1000ml · 9 per case'), findsOneWidget);
    expect(find.byType(FindEalBookScreen), findsNothing);

    serve(traced);
    await tester.tap(find.text('1000ml · 9 per case'));
    await tester.pumpAndSettle();

    expect(find.byType(FindEalBookScreen), findsOneWidget);

    // The choice goes back as the issuance itself: two books of one pack
    // size can hold the same serial.
    expect(adapter.queries.last['issuanceId'], 'i2');
  });

  testWidgets('each stage says who recorded it, and when', (tester) async {
    serve(traced);
    await pump(tester);
    await look(tester, 'AAA0000002401');

    // Entered on the record's own date: the time alone.
    expect(find.text('Priya Nair · entered 08:12'), findsOneWidget);
    expect(find.text('Demo User · entered 09:14'), findsOneWidget);

    // Linked the day after the note's date, so the footnote carries it.
    expect(find.text('Demo User · linked 23 Oct, 11:48'), findsOneWidget);
  });

  testWidgets('the dispatch stage is shown, not described in passing', (
    tester,
  ) async {
    serve(traced);
    await pump(tester);
    await look(tester, 'AAA0000002401');

    expect(find.text('Final · 2/5'), findsOneWidget);
    expect(find.textContaining('note is Final'), findsNothing);
  });

  testWidgets('the figures name the book they count', (tester) async {
    serve(traced);
    await pump(tester);
    await look(tester, '2401');

    expect(
      find.text('9,600 labels in this book · 1,200 of them still unused'),
      findsOneWidget,
    );
  });

  testWidgets('a label that has gone no further keeps its rows', (
    tester,
  ) async {
    serve({...traced, 'usage': <dynamic>[], 'ealDispatches': <dynamic>[]});
    await pump(tester);
    await look(tester, '2401');

    expect(find.text('Not applied yet'), findsOneWidget);
    expect(find.text('Not dispatched yet'), findsOneWidget);
    expect(find.text('Still in finished stock.'), findsOneWidget);
  });

  testWidgets('a serial no book holds is a state, not an error', (
    tester,
  ) async {
    serve({'error': 'No issuance of AAA holds serial 999999.'}, status: 404);
    await pump(tester);
    await look(tester, 'AAA999999');

    expect(find.text('Nothing issued with this number'), findsOneWidget);
    expect(find.text('That did not work'), findsNothing);
  });

  testWidgets('a refusal says what came back, not just that it failed', (
    tester,
  ) async {
    serve(const <String, dynamic>{}, status: 403);
    await pump(tester);
    await look(tester, '2401');

    expect(find.textContaining('answered 403'), findsOneWidget);
  });

  testWidgets('an answer it cannot read says so', (tester) async {
    // 200, but not the shape this app knows. This is what a changed
    // server looks like from here, and "could not look that label up"
    // named neither side of it.
    serve({'usage': 'not a list'});
    await pump(tester);
    await look(tester, '2401');

    expect(find.textContaining('could not be read'), findsOneWidget);
  });

  test('the query has to carry digits before anything is sent', () {
    final controller = FindEalController();

    expect(controller.canSearch, isFalse);
    controller.query.value = 'AAA';
    expect(controller.canSearch, isFalse);
    controller.query.value = 'AAA0000002401';
    expect(controller.canSearch, isTrue);
  });

  test('a scanned label gives its prefix as well as its serial', () {
    const payload = 'AAA|0000002401|0000002354|0000002401|48|1';

    // Dropping the prefix made every scan ask which book, when the label
    // in the hand had already said.
    expect(EalQrCodec.prefixOf(payload), 'AAA');
    expect(EalQrCodec.pad(EalQrCodec.readSingle(payload)!), '0000002401');

    // A carton barcode gives neither, so it is not searched for.
    expect(EalQrCodec.readSingle('8901234567890'), isNull);
    expect(EalQrCodec.prefixOf('8901234567890'), isNull);
  });
}

/// Answers every request with one body and one status, and keeps what it
/// was asked, so a test can show which book the choice named.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.body, this.status);

  final Object body;
  final int status;
  final List<Map<String, dynamic>> queries = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    queries.add(Map<String, dynamic>.from(options.queryParameters));

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
