import 'package:eal_scanner/models/items.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/api_test_support.dart';

void main() {
  test('populated references retain IDs for production submissions', () {
    final item = Item.fromJson(itemResponse(isActive: true));
    expect(item.company, '64a000000000000000000002');
    expect(item.pack, '64a000000000000000000003');
    expect(item.bottlesPerCase, 12);
    expect(item.isActive, isTrue);
  });

  test('legacy ID references and missing status remain supported', () {
    final item = Item.fromJson(itemResponse(populated: false));
    expect(item.company, '64a000000000000000000002');
    expect(item.pack, '64a000000000000000000003');
    expect(item.isActive, isTrue);
  });

  test('explicit inactive status is preserved', () {
    expect(Item.fromJson(itemResponse(isActive: false)).isActive, isFalse);
  });

  test('missing references fail clearly instead of submitting invalid IDs', () {
    for (final field in ['company', 'pack']) {
      expect(
        () => Item.fromJson({...itemResponse(), field: null}),
        throwsFormatException,
      );
    }
  });
}
