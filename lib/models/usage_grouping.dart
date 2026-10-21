import 'package:eal_scanner/models/grouping_order.dart';
import 'package:eal_scanner/models/usage.dart';

/// Production entries gathered by company and market, then by item.
///
/// The same shape as the issuance list, with two differences that come from
/// the record rather than the design: an entry is a withdrawal and has no
/// balance of its own, and production counts in cases, so cases lead and
/// labels follow.

/// One item within a company and market.
class ItemGroup {
  ItemGroup({required this.itemName, required this.rows});

  final String itemName;
  final List<UsageModel> rows;

  int get cases => rows.fold<int>(0, (sum, r) => sum + r.usedQuantityInCases);
  int get labels => rows.fold<int>(0, (sum, r) => sum + r.usedQuantity);

  /// Bottles to a case, worked out from the two quantities the record
  /// already carries. Null where it does not divide evenly, rather than
  /// showing a figure that is nearly right.
  int? get bottlesPerCase {
    if (cases <= 0 || labels <= 0) return null;
    if (labels % cases != 0) return null;
    return labels ~/ cases;
  }
}

/// One company and market, holding its items.
class UsageGroup {
  UsageGroup({
    required this.companyName,
    required this.market,
    required this.items,
  });

  final String companyName;

  /// As the server stores it: `local` or `export`.
  final String market;

  final List<ItemGroup> items;

  int get cases => items.fold<int>(0, (sum, i) => sum + i.cases);
  int get labels => items.fold<int>(0, (sum, i) => sum + i.labels);
  int get entryCount => items.fold<int>(0, (sum, i) => sum + i.rows.length);
}

/// Groups entries for display. Companies read A to Z, markets local first,
/// items by the size in their name then alphabetically, and the entries
/// within an item in the order they were made.
List<UsageGroup> groupUsages(List<UsageModel> rows) {
  final byGroup = <String, List<UsageModel>>{};

  for (final row in rows) {
    final key = '${row.companyName}\u0000${row.market.toLowerCase()}';
    byGroup.putIfAbsent(key, () => []).add(row);
  }

  final groups = <UsageGroup>[];

  for (final entry in byGroup.entries) {
    final parts = entry.key.split('\u0000');
    final byItem = <String, List<UsageModel>>{};

    for (final row in entry.value) {
      byItem.putIfAbsent(row.itemName, () => []).add(row);
    }

    final items = byItem.entries
        .map(
          (e) => ItemGroup(
            itemName: e.key,
            rows: e.value..sort((a, b) => a.dateUsed.compareTo(b.dateUsed)),
          ),
        )
        .toList()
      ..sort((a, b) => compareBySize(a.itemName, b.itemName));

    groups.add(
      UsageGroup(companyName: parts[0], market: parts[1], items: items),
    );
  }

  groups.sort((a, b) {
    final byCompany =
        a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase());
    if (byCompany != 0) return byCompany;
    return marketRank(a.market).compareTo(marketRank(b.market));
  });

  return groups;
}
