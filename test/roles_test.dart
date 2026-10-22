import 'package:dio/dio.dart';
import 'package:dio/dio.dart' as dio show Response;
import 'package:eal_scanner/controllers/dashboardController.dart';
import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/controllers/loginController.dart';
import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/services/authService.dart';
import 'package:eal_scanner/screens/issuance/issuanceListScreen.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:eal_scanner/utils/api_error.dart';
import 'package:eal_scanner/widgets/ui/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'support/api_test_support.dart';

/// What the app offers has to match what the server will allow.
///
/// The server is the authority — it re-reads the role on every request — so
/// nothing here grants access. These pin the other half: a screen or a
/// button is not offered to a role the server would refuse, and a role the
/// app cannot read hides nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // One store for the file: GetStorage caches by container name, so a fresh
  // one per test hands back the first instance with its directory deleted.
  late GetStorage storage;

  setUpAll(() async {
    storage = await initializeTestStorage();
  });

  tearDown(() async => storage.remove('auth_user'));

  /// The user as the server sends it: role populated, so a record.
  Future<void> signedInAs(
    String roleName,
    List<String> permissions, {
    bool isSystem = false,
  }) async {
    await storage.write('auth_user', {
      'fullName': 'Thomas Louis',
      'email': 'thomas@blueoceanbeverages.com',
      'role': {
        '_id': '64a000000000000000000009',
        'name': roleName,
        'isSystem': isSystem,
        'permissions': permissions,
      },
    });
  }

  group('the role as the server sends it', () {
    test('its name reads, rather than the whole record', () async {
      await signedInAs('Field Operator', ['issuance:view']);

      // Read straight off the map this was the id, the permission list and
      // all, printed at the operator on the account screen.
      expect(AuthService.roleName, 'Field Operator');
    });

    test('a session saved when a role was a word still reads', () async {
      await storage.write('auth_user', {'role': 'admin'});

      expect(AuthService.roleName, 'admin');
      expect(
        AuthService.knowsRole,
        isFalse,
        reason: 'there is no permission list in it',
      );
    });

    test('what it may do is read from the list', () async {
      await signedInAs('Storekeeper', [
        'dashboard:view',
        'issuance:view',
        'issuance:create',
        'finished:view',
      ]);

      expect(AuthService.can('issuance:create'), isTrue);
      expect(AuthService.can('usage:create'), isFalse);

      // Any one of several is enough, as on the route itself.
      expect(AuthService.canAny(['usage:view', 'finished:view']), isTrue);
      expect(AuthService.canAny(['dispatch:view']), isFalse);
    });

    test('the unrestricted role may do everything', () async {
      await signedInAs('Administrator', [], isSystem: true);

      // It carries every key on the server, but the server lets it through
      // on isSystem alone, so an empty list here must not lock it out.
      expect(AuthService.can('dispatch:link'), isTrue);
      expect(AuthService.can('anything:at:all'), isTrue);
    });

    test('a role the app cannot read hides nothing', () async {
      await storage.write('auth_user', {'role': 'admin'});

      // Hiding the whole app from a session whose shape we cannot read
      // would be worse than offering a screen that then says no — and the
      // server still refuses on its own either way.
      expect(AuthService.can('dispatch:link'), isTrue);
      expect(AuthService.can('issuance:create'), isTrue);
    });

    test('no session at all hides nothing either', () async {
      await storage.remove('auth_user');

      expect(AuthService.can('issuance:create'), isTrue);
      expect(AuthService.roleName, '');
    });
  });

  group('the tabs a role is offered', () {
    Future<List<String>> tabsFor(WidgetTester tester) async {
      Get.put(Issuancecontroller());
      Get.put(UsageController());
      Get.put(DispatchController());
      Get.put(DashboardController());
      Get.put(LoginController());
      addTearDown(Get.reset);

      DioClient().dio.httpClientAdapter = FakeApiRouter(const {});

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.8125;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const GetMaterialApp(home: AppShell()));
      await tester.pumpAndSettle();

      return [
        for (final label in const [
          'Home',
          'Issuance',
          'Production',
          'Dispatch',
          'Account',
        ])
          if (find.text(label).evaluate().isNotEmpty) label,
      ];
    }

    testWidgets('a storekeeper is not shown dispatch', (tester) async {
      await signedInAs('Storekeeper', [
        'dashboard:view',
        'issuance:view',
        'issuance:create',
        'issuance:delete',
        'stock:view',
        'finished:view',
        'eal:trace',
        'masterdata:view',
      ]);

      // finished:view is enough for the production list, which is why that
      // tab stays even though they cannot record on it.
      expect(await tabsFor(tester), [
        'Home',
        'Issuance',
        'Production',
        'Account',
      ]);
    });

    testWidgets('a dispatch role is not shown issuance', (tester) async {
      await signedInAs('Dispatch', [
        'dashboard:view',
        'dispatch:view',
        'dispatch:create',
        'dispatch:edit',
        'dispatch:delete',
        'dispatch:link',
        'dispatch:status',
        'finished:view',
        'eal:trace',
        'masterdata:view',
      ]);

      expect(await tabsFor(tester), [
        'Home',
        'Production',
        'Dispatch',
        'Account',
      ]);
    });

    testWidgets('the field operator is shown all of them', (tester) async {
      await signedInAs('Field Operator', [
        'dashboard:view',
        'issuance:view',
        'issuance:create',
        'issuance:delete',
        'usage:view',
        'usage:create',
        'dispatch:view',
        'dispatch:link',
        'dispatch:status',
        'masterdata:view',
      ]);

      expect(await tabsFor(tester), [
        'Home',
        'Issuance',
        'Production',
        'Dispatch',
        'Account',
      ]);
    });

    testWidgets('a role without the dashboard opens on the next tab', (
      tester,
    ) async {
      // Nothing in the five built-in roles can reach this, so it is pinned
      // here: a custom role made without dashboard:view.
      await signedInAs('ZZ Test — no dashboard', [
        'issuance:view',
        'issuance:create',
        'usage:view',
        'usage:create',
        'dispatch:view',
        'dispatch:link',
        'dispatch:status',
        'masterdata:view',
      ]);

      expect(await tabsFor(tester), [
        'Issuance',
        'Production',
        'Dispatch',
        'Account',
      ]);

      // And the first tab is the one it lands on, rather than an empty slot
      // where Home used to be.
      expect(find.text('EAL issuance'), findsOneWidget);
    });

    testWidgets('so is a session whose role the app cannot read', (
      tester,
    ) async {
      await storage.write('auth_user', {'role': 'admin'});

      expect(await tabsFor(tester), hasLength(5));
    });
  });

  group('the record button', () {
    Future<void> pumpIssuance(WidgetTester tester) async {
      Get.put(Issuancecontroller());
      addTearDown(Get.reset);
      DioClient().dio.httpClientAdapter = FakeApiRouter(const {});

      await tester.pumpWidget(const GetMaterialApp(home: IssuanceListScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('is there for a role that may record', (tester) async {
      await signedInAs('Field Operator', ['issuance:view', 'issuance:create']);
      await pumpIssuance(tester);

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('is gone for a role that may only read', (tester) async {
      await signedInAs('Dispatch', ['stock:view']);
      await pumpIssuance(tester);

      // The server would refuse the record after a whole range had been
      // scanned, which is the worst moment to find out.
      expect(find.byType(FloatingActionButton), findsNothing);

      // And the empty state does not offer it either.
      expect(find.text('Record a new issuance'), findsNothing);
    });
  });

  group('which failures end the session', () {
    DioException failure(int status, Object? body) {
      final options = RequestOptions(path: '/eal_usage');
      return DioException(
        requestOptions: options,
        response: dio.Response(
          requestOptions: options,
          statusCode: status,
          data: body,
        ),
      );
    }

    test('a token the server will not take', () {
      expect(
        endsTheSession(
          failure(401, {'message': 'Not authorised, token failed'}),
        ),
        isTrue,
      );
    });

    test('an account that has been switched off', () {
      expect(
        endsTheSession(
          failure(403, {'message': 'This account has been switched off'}),
        ),
        isTrue,
      );
    });

    test('one action refused does not sign anyone out', () {
      // The server names the permission it wanted, which is what tells this
      // apart from the sign-in guard refusing the whole session.
      expect(
        endsTheSession(
          failure(403, {
            'message':
                'Storekeeper is not allowed to record labels applied. '
                'Ask an administrator.',
            'required': ['usage:create'],
            'role': 'Storekeeper',
          }),
        ),
        isFalse,
      );
    });

    test('an ordinary rejection is not a session ending', () {
      expect(
        endsTheSession(failure(400, {'message': 'Overlapping range'})),
        isFalse,
      );
      expect(endsTheSession(failure(500, null)), isFalse);
    });
  });

  group('what a refusal says', () {
    test('the server\'s own sentence, not Dio\'s status line', () {
      final options = RequestOptions(path: '/eal_usage');
      final refusal = DioException(
        requestOptions: options,
        message: 'The request returned an invalid status code of 403.',
        response: dio.Response(
          requestOptions: options,
          statusCode: 403,
          data: {
            'message':
                'Storekeeper is not allowed to record labels applied. '
                'Ask an administrator.',
            'required': ['usage:create'],
          },
        ),
      );

      expect(
        readableDioError(refusal, 'fallback'),
        startsWith('Storekeeper is not allowed'),
      );
    });

    test('a plain error never shows its own toString', () {
      expect(
        readableError(StateError('bad'), 'Could not load that list.'),
        'Could not load that list.',
      );
    });
  });
}
