import 'package:eal_scanner/models/issuance.dart';
import 'package:eal_scanner/models/issuance_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

/// Grouping decides what the list says the totals are, so the arithmetic and
/// the ordering are pinned here rather than read off a screen.
void main() {
  IssuanceModel record({
    String company = 'Blue Ocean Beverages Pvt. Ltd.',
    String pack = '90ml',
    String market = 'local',
    String prefix = 'EXT',
    required int from,
    required int to,
    int used = 0,
  }) {
    final issued = to - from + 1;
    return IssuanceModel(
      id: '$prefix$from',
      companyName: company,
      packName: pack,
      dateIssued: DateTime(2026, 10, 21),
      issuedQuantity: issued,
      balanceQuantity: issued - used,
      market: market,
      prefix: prefix,
      serialFrom: from.toString(),
      serialTo: to.toString(),
      usedSerialRanges: [],
    );
  }

  test('a company and market hold their pack sizes', () {
    final groups = groupIssuances([
      record(from: 2804736001, to: 2804832000, used: 57600),
      record(pack: '180ml', from: 19450001, to: 19498000),
      record(pack: '750ml', market: 'export', from: 200001, to: 236000),
    ]);

    expect(groups, hasLength(2), reason: 'local and export are separate');

    final local = groups.first;
    expect(local.market, 'local');
    expect(local.packs.map((p) => p.packName), ['90ml', '180ml']);
    expect(local.issued, 144000);
    expect(local.unused, 144000 - 57600);

    final export = groups.last;
    expect(export.market, 'export');
    expect(export.issued, 36000);
  });

  test('pack sizes sort by millilitres, not alphabetically', () {
    final groups = groupIssuances([
      record(pack: '750ml', from: 1, to: 100),
      record(pack: '90ml', from: 101, to: 200),
      record(pack: '180ml', from: 201, to: 300),
    ]);

    expect(groups.single.packs.map((p) => p.packName),
        ['90ml', '180ml', '750ml']);
  });

  test('a pack size adds up its ranges, in serial order', () {
    final groups = groupIssuances([
      record(from: 2804784001, to: 2804832000, used: 48000),
      record(from: 2804736001, to: 2804784000, used: 9600),
    ]);

    final pack = groups.single.packs.single;
    expect(pack.rows.map((r) => r.serialFrom), ['2804736001', '2804784001']);
    expect(pack.issued, 96000);
    expect(pack.unused, 96000 - 57600);
    expect(groups.single.recordCount, 2);
  });

  test('companies read A to Z, with local before export', () {
    final groups = groupIssuances([
      record(company: 'Zenith Distillers', from: 1, to: 10),
      record(company: 'Alpha Beverages', market: 'export', from: 11, to: 20),
      record(company: 'Alpha Beverages', from: 21, to: 30),
    ]);

    expect(
      groups.map((g) => '${g.companyName} ${g.market}'),
      ['Alpha Beverages local', 'Alpha Beverages export', 'Zenith Distillers local'],
    );
  });

  test('no records means no groups', () {
    expect(groupIssuances([]), isEmpty);
  });

  test('a pack name with no number still sorts, after the sized ones', () {
    final groups = groupIssuances([
      record(pack: 'Assorted', from: 1, to: 10),
      record(pack: '90ml', from: 11, to: 20),
    ]);

    expect(groups.single.packs.map((p) => p.packName), ['90ml', 'Assorted']);
  });
}
