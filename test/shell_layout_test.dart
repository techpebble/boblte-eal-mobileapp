import 'package:eal_scanner/controllers/dashboardController.dart';
import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/controllers/loginController.dart';
import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:eal_scanner/widgets/ui/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// The shell and its five tabs must build without throwing.
///
/// A release build silently swallows a widget that throws while building: it
/// is replaced by a blank box and the layout collapses around it. That is how
/// an `Obx` whose closure read no observable reached a real phone, leaving the
/// tab bar stranded in the middle of an otherwise empty screen. These tests
/// fail loudly where a release build would say nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  setUp(() {
    Get.put(DashboardController());
    Get.put(Issuancecontroller());
    Get.put(UsageController());
    Get.put(DispatchController());
    Get.put(LoginController());
    DioClient().dio.httpClientAdapter = FakeApiAdapter({
      'count': 0,
      'data': [],
    });
  });

  tearDown(() => Get.reset());

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GetMaterialApp(home: AppShell()));
    await tester.pumpAndSettle();
  }

  testWidgets('the shell builds without throwing', (tester) async {
    await pumpShell(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tab bar sits at the bottom of the screen', (tester) async {
    await pumpShell(tester);

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;

    // A collapsed layout strands the bar around the middle. It belongs in the
    // bottom quarter of the screen.
    final tabLabel = tester.getRect(find.text('Home').first);
    expect(
      tabLabel.center.dy,
      greaterThan(screen.height * 0.75),
      reason:
          'the tab bar should sit at the bottom, not float mid-screen. '
          'Found it at ${tabLabel.center.dy} of ${screen.height}.',
    );
  });

  testWidgets('every tab builds without throwing', (tester) async {
    await pumpShell(tester);

    for (final tab in ['Issuance', 'Production', 'Dispatch', 'Account']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'the $tab tab threw while building',
      );
    }
  });
}
