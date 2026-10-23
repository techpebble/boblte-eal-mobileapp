import 'package:eal_scanner/branding.dart';
import 'package:eal_scanner/config/api_config.dart';
import 'package:eal_scanner/controllers/dashboardController.dart';
import 'package:eal_scanner/screens/about_screen.dart';
import 'package:eal_scanner/screens/accountScreen.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:eal_scanner/services/settingsService.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// The account page carries what this person can change, and the About
/// page carries what the app is.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  tearDown(() => Get.reset());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    Get.put(DashboardController());
    DioClient().dio.httpClientAdapter = FakeApiRouter({});

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(GetMaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  test('both scanning preferences start off', () {
    // Nothing happens at the first scan that was not asked for, and a
    // fresh install behaves the same way on every phone.
    expect(SettingsService.torchByDefault, isFalse);
    expect(SettingsService.scanFeedback, isFalse);
  });

  testWidgets('scanning carries two switches, and no prefix to keep right', (
    tester,
  ) async {
    await pump(tester, const AccountScreen());

    expect(find.text('Torch on by default'), findsOneWidget);
    expect(find.text('Beep and vibrate on scan'), findsOneWidget);

    // The wizard asks for the prefix as its first step, with the label in
    // the hand.
    expect(find.text('Default serial prefix'), findsNothing);
  });

  testWidgets('connection answers one question, without the address', (
    tester,
  ) async {
    await pump(tester, const AccountScreen());

    expect(find.text('CONNECTION'), findsOneWidget);
    expect(find.text('Server'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);

    // Neither the host nor a clock: the page pulls down to refresh.
    expect(find.textContaining(ApiConfig.label), findsNothing);
    expect(find.text('Refresh overview'), findsNothing);
  });

  testWidgets('about is a page, not a row of small print', (tester) async {
    await pump(tester, const AccountScreen());

    expect(find.text('About ${AppBrand.name}'), findsOneWidget);
    expect(find.text('Open-source licences'), findsNothing);

    // Below the fold on a phone, which is where it belongs.
    await tester.ensureVisible(find.text('About ${AppBrand.name}'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About ${AppBrand.name}'));
    await tester.pumpAndSettle();

    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text('Open-source licences'), findsOneWidget);
    expect(find.text('Version ${AppBrand.version}'), findsOneWidget);
  });

  testWidgets('a live build names no server on the about page', (tester) async {
    // Tests run without the dart-define, so this is the build that ships.
    expect(ApiConfig.isProduction, isTrue);

    await pump(tester, const AboutScreen());

    expect(find.text('Test server'), findsNothing);
    expect(find.textContaining(ApiConfig.label), findsNothing);
  });
}
