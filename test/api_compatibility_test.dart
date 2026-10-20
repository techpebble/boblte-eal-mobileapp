import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/services/authService.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/api_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  test(
    'the same API client uses the current session on every request',
    () async {
      final dio = DioClient().dio;
      final adapter = FakeApiAdapter({'data': []});
      dio.httpClientAdapter = adapter;

      await dio.get('items');
      expect(adapter.requests.last.headers['Authorization'], isNull);

      await AuthService.saveLoginSession({'token': 'first-user', 'user': {}});
      await dio.get('items');
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer first-user',
      );

      await AuthService.clearSession();
      await AuthService.saveLoginSession({'token': 'second-user', 'user': {}});
      await dio.get('items');
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer second-user',
      );

      await AuthService.clearSession();
      await dio.get('items');
      expect(adapter.requests.last.headers['Authorization'], isNull);
    },
  );

  test(
    'production loads populated items and excludes inactive entries',
    () async {
      final adapter = FakeApiAdapter({
        'count': 3,
        'data': [
          itemResponse(isActive: true),
          {...itemResponse(isActive: false), '_id': 'inactive-item'},
          {...itemResponse(populated: false), '_id': 'legacy-item'},
        ],
      });
      DioClient().dio.httpClientAdapter = adapter;
      final controller = UsageController();

      expect(await controller.fetchItems(), isTrue);
      expect(adapter.requests.single.uri.path, '/api/v1/items');
      expect(adapter.requests.single.queryParameters['isActive'], 'true');
      expect(controller.items.map((item) => item.id), [
        '64a000000000000000000001',
        'legacy-item',
      ]);
      expect(controller.items.first.company, '64a000000000000000000002');
      expect(controller.items.first.pack, '64a000000000000000000003');
      expect(controller.isLoading.value, isFalse);

      // A later refresh must remove items that have been deactivated.
      DioClient().dio.httpClientAdapter = FakeApiAdapter({
        'count': 0,
        'data': [],
      });
      expect(await controller.fetchItems(), isTrue);
      expect(controller.items, isEmpty);
    },
  );
}
