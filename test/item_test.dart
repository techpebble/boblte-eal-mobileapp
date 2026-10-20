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

  group('display name', () {
    // Full names run to "ORIGINAL CHOICE DELUXE WHISKY 90ML TETRAPAK x 96",
    // so lists and pickers show the short alias where there is one.
    test('the alias is preferred over the full name', () {
      final item = Item.fromJson({...itemResponse(), 'alias': 'OC Deluxe 90'});
      expect(item.alias, 'OC Deluxe 90');
      expect(item.name, 'Test item');
      expect(item.displayName, 'OC Deluxe 90');
    });

    test('older records without an alias fall back to the full name', () {
      final item = Item.fromJson(itemResponse());
      expect(item.alias, isEmpty);
      expect(item.displayName, 'Test item');
    });

    test('a blank alias falls back too', () {
      final item = Item.fromJson({...itemResponse(), 'alias': '   '});
      expect(item.displayName, 'Test item');
    });

    test('the alias is trimmed', () {
      final item = Item.fromJson({...itemResponse(), 'alias': '  OC 90  '});
      expect(item.displayName, 'OC 90');
    });

    // Usage and dispatch records carry a populated item object rather than a
    // full Item, so they resolve the name through this.
    test('a populated item object resolves the same way', () {
      expect(
        Item.displayNameFromJson({'name': 'Test item', 'alias': 'OC 90'}),
        'OC 90',
      );
      expect(Item.displayNameFromJson({'name': 'Test item'}), 'Test item');
      expect(
        Item.displayNameFromJson({'name': 'Test item', 'alias': ''}),
        'Test item',
      );
    });

    test('an unpopulated item reference does not blow up', () {
      expect(Item.displayNameFromJson('64a000000000000000000001'), isEmpty);
      expect(Item.displayNameFromJson(null), isEmpty);
    });
  });
}
