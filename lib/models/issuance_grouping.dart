import 'package:eal_scanner/models/issuance.dart';

/// Issuance records gathered by company and market, then by pack size.
///
/// An excise return is asked for in exactly those terms, so the totals are
/// held at both levels and nothing has to be added up by hand. Pure functions
/// over the records the list already has: no server call and no new field.

/// One pack size within a company and market.
class PackGroup {
  PackGroup({required this.packName, required this.rows});

  final String packName;
  final List<IssuanceModel> rows;

  int get issued => rows.fold<int>(0, (sum, r) => sum + r.issuedQuantity);
  int get unused => rows.fold<int>(0, (sum, r) => sum + r.balanceQuantity);
}

/// One company and market, holding its pack sizes.
class IssuanceGroup {
  IssuanceGroup({
    required this.companyName,
    required this.market,
    required this.packs,
  });

  final String companyName;

  /// As the server stores it: `local` or `export`.
  final String market;

  final List<PackGroup> packs;

  int get issued => packs.fold<int>(0, (sum, p) => sum + p.issued);
  int get unused => packs.fold<int>(0, (sum, p) => sum + p.unused);
  int get recordCount => packs.fold<int>(0, (sum, p) => sum + p.rows.length);
}

/// `local` before `export`, matching the server's own enum order.
int _marketRank(String market) => market.toLowerCase() == 'local' ? 0 : 1;

/// The millilitres leading a pack name, so 90ml sorts before 180ml. Names
/// that do not start with a number fall back to their text.
int? _packSize(String name) {
  final match = RegExp(r'^\s*(\d+)').firstMatch(name);
  return match == null ? null : int.tryParse(match.group(1)!);
}

int _comparePacks(String a, String b) {
  final sa = _packSize(a);
  final sb = _packSize(b);
  if (sa != null && sb != null && sa != sb) return sa.compareTo(sb);
  if (sa != null && sb == null) return -1;
  if (sa == null && sb != null) return 1;
  return a.toLowerCase().compareTo(b.toLowerCase());
}

/// Groups records for display. Companies read A to Z, markets local first,
/// pack sizes smallest first, and the ranges within a pack size in serial
/// order — so the same records always land in the same place.
List<IssuanceGroup> groupIssuances(List<IssuanceModel> rows) {
  final byGroup = <String, List<IssuanceModel>>{};

  for (final row in rows) {
    final key = '${row.companyName}\u0000${row.market.toLowerCase()}';
    byGroup.putIfAbsent(key, () => []).add(row);
  }

  final groups = <IssuanceGroup>[];

  for (final entry in byGroup.entries) {
    final parts = entry.key.split('\u0000');
    final byPack = <String, List<IssuanceModel>>{};

    for (final row in entry.value) {
      byPack.putIfAbsent(row.packName, () => []).add(row);
    }

    final packs = byPack.entries
        .map(
          (e) => PackGroup(
            packName: e.key,
            rows: e.value
              ..sort(
                (a, b) => (int.tryParse(a.serialFrom) ?? 0)
                    .compareTo(int.tryParse(b.serialFrom) ?? 0),
              ),
          ),
        )
        .toList()
      ..sort((a, b) => _comparePacks(a.packName, b.packName));

    groups.add(
      IssuanceGroup(companyName: parts[0], market: parts[1], packs: packs),
    );
  }

  groups.sort((a, b) {
    final byCompany =
        a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase());
    if (byCompany != 0) return byCompany;
    return _marketRank(a.market).compareTo(_marketRank(b.market));
  });

  return groups;
}
