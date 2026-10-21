import 'package:eal_scanner/models/usage.dart';
import 'package:eal_scanner/models/usage_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

/// Production groups by company and market, then item, and counts in cases.
void main() {
  UsageModel entry({
    String company = 'Blue Ocean Beverages Pvt. Ltd.',
    String item = 'OC Deluxe 750ml',
    String market = 'local',
    required int cases,
    required int perCase,
    int hour = 9,
  }) {
    return UsageModel(
      id: '$item$cases$hour',
      companyName: company,
      itemName: item,
      packName: 'pack',
      dateUsed: DateTime(2026, 10, 21, hour),
      usedQuantity: cases * perCase,
      usedQuantityInCases: cases,
      balanceQuantity: 0,
      balanceQuantityInCases: 0,
      market: market,
      prefix: 'ML',
      serialFrom: '1',
      serialTo: '2',
      usedSerialRanges: [],
    );
  }

  test('an item adds up its entries, in the order they were made', () {
    final groups = groupUsages([
      entry(cases: 966, perCase: 12, hour: 11),
      entry(cases: 200, perCase: 12, hour: 9),
    ]);

    final item = groups.single.items.single;
    expect(item.rows.first.usedQuantityInCases, 200, reason: '09:00 first');
    expect(item.cases, 1166);
    expect(item.labels, 13992);
    expect(groups.single.entryCount, 2);
  });

  test('bottles per case comes from the two quantities on the record', () {
    final groups = groupUsages([entry(cases: 200, perCase: 12)]);
    expect(groups.single.items.single.bottlesPerCase, 12);
  });

  test('a case figure that does not divide evenly shows no per-case', () {
    final odd = UsageModel(
      id: 'odd',
      companyName: 'Blue Ocean',
      itemName: 'Odd 500ml',
      packName: 'pack',
      dateUsed: DateTime(2026, 10, 21),
      usedQuantity: 100,
      usedQuantityInCases: 7,
      balanceQuantity: 0,
      balanceQuantityInCases: 0,
      market: 'local',
      prefix: 'ML',
      serialFrom: '1',
      serialTo: '2',
      usedSerialRanges: [],
    );

    expect(groupUsages([odd]).single.items.single.bottlesPerCase, isNull);
  });

  test('markets split, and the group totals both units', () {
    final groups = groupUsages([
      entry(cases: 200, perCase: 12),
      entry(item: 'Old Monk 375ml', cases: 73, perCase: 24),
      entry(item: 'OC Reserve 180ml', market: 'export', cases: 50, perCase: 48),
    ]);

    expect(groups, hasLength(2));
    expect(groups.first.market, 'local');
    expect(groups.first.cases, 273);
    expect(groups.first.labels, 200 * 12 + 73 * 24);
    expect(groups.last.market, 'export');
    expect(groups.last.cases, 50);
  });

  test('items sort by the size in their name', () {
    final groups = groupUsages([
      entry(item: '750ml Deluxe', cases: 1, perCase: 12),
      entry(item: '180ml Reserve', cases: 1, perCase: 48),
      entry(item: 'Assorted case', cases: 1, perCase: 6),
    ]);

    expect(
      groups.single.items.map((i) => i.itemName),
      ['180ml Reserve', '750ml Deluxe', 'Assorted case'],
    );
  });

  test('no entries means no groups', () {
    expect(groupUsages([]), isEmpty);
  });
}
