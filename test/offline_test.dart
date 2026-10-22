import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/screens/dispatches/dispatchListScreen.dart';
import 'package:eal_scanner/screens/issuance/issuanceListScreen.dart';
import 'package:eal_scanner/screens/usages/usagesListScreen.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// The server is never reachable here, so every list fails the way it does
/// when the plant network drops.
class DeadNetworkAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'Network is unreachable',
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  tearDown(() => Get.reset());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    DioClient().dio.httpClientAdapter = DeadNetworkAdapter();
    await tester.pumpWidget(GetMaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  for (final (name, build) in [
    (
      'issuance',
      () {
        Get.put(Issuancecontroller());
        return const IssuanceListScreen();
      },
    ),
    (
      'production',
      () {
        Get.put(UsageController());
        return const UsagesListScreen();
      },
    ),
    (
      'dispatch',
      () {
        Get.put(DispatchController());
        return const DispatchListScreen();
      },
    ),
  ]) {
    testWidgets('$name says the network is down, not that the server erred', (
      tester,
    ) async {
      await pump(tester, build());

      // The same state on all three, so the app says one thing once.
      expect(find.byType(OfflineState), findsOneWidget);
      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      // Not the red banner a refusal or a rejected range gets.
      expect(find.byType(NoticeBanner), findsNothing);
      expect(find.textContaining('Could not load'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name does not paint the whole screen one colour', (
      tester,
    ) async {
      await pump(tester, build());

      // The banner stretched to every pixel it was offered, so a two-line
      // message filled the screen.
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final panel = tester.getRect(find.byIcon(Icons.wifi_off_rounded));
      expect(panel.height, lessThan(size.height / 3));
    });
  }
}
