import 'package:eal_scanner/config/api_config.dart';
import 'package:eal_scanner/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// The sign-in screen is the one screen every operator sees, and the only
/// one strangers see. It should carry what they need and nothing else.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  tearDown(() => Get.reset());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GetMaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('a live build names no server', (tester) async {
    // Tests run without the dart-define, so this is the build that ships.
    expect(ApiConfig.isProduction, isTrue);

    await pump(tester);

    expect(find.textContaining('Signing in to'), findsNothing);
    expect(find.textContaining(ApiConfig.label), findsNothing);
    expect(find.byIcon(Icons.dns_outlined), findsNothing);
  });

  testWidgets('both fields say what goes in them', (tester) async {
    await pump(tester);

    // Labels above, and a hint inside: the password field had the label
    // alone, so an empty box sat under it saying nothing.
    expect(find.text('Email or mobile'), findsOneWidget);
    expect(find.text('you@plant.co'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Your password'), findsOneWidget);
  });

  testWidgets('the password is hidden until it is asked for', (tester) async {
    await pump(tester);

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Your password'),
    );
    expect(field.obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    final shown = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Your password'),
    );
    expect(shown.obscureText, isFalse);
  });
}
