import 'package:eal_scanner/models/dispatch.dart';
import 'package:eal_scanner/models/grouping_order.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';

/// Dispatch notes gathered by company and market, as issuance and production
/// are.
///
/// There is no third level here. A note's lines live on the note's own
/// screen: listing them under every depot only buries the next one, and the
/// figure that matters on a list is what the note is still short.
class DispatchGroup {
  DispatchGroup({
    required this.companyName,
    required this.market,
    required this.notes,
  });

  final String companyName;

  /// As the server stores it: `local` or `export`.
  final String market;

  final List<DispatchModel> notes;

  int get cases => notes.fold<int>(0, (sum, n) => sum + n.totalQuantity);
  int get linked => notes.fold<int>(0, (sum, n) => sum + n.issuedQty);

  /// Cases on these notes with no labels against them yet.
  int get short {
    final outstanding = cases - linked;
    return outstanding > 0 ? outstanding : 0;
  }
}

/// Groups notes for display. Companies read A to Z, markets local first,
/// and within a group the notes still short come before the ones that are
/// done — they are the only ones the phone can do anything about.
List<DispatchGroup> groupDispatches(List<DispatchModel> notes) {
  final byGroup = <String, List<DispatchModel>>{};

  for (final note in notes) {
    final key = '${note.companyName}\u0000${note.market.toLowerCase()}';
    byGroup.putIfAbsent(key, () => []).add(note);
  }

  final groups = <DispatchGroup>[];

  for (final entry in byGroup.entries) {
    final parts = entry.key.split('\u0000');

    groups.add(
      DispatchGroup(
        companyName: parts[0],
        market: parts[1],
        notes: entry.value
          ..sort((a, b) {
            final aShort = a.issuedQty < a.totalQuantity ? 0 : 1;
            final bShort = b.issuedQty < b.totalQuantity ? 0 : 1;
            if (aShort != bShort) return aShort - bShort;

            final byStage =
                dispatchStageIndex(a.status) - dispatchStageIndex(b.status);
            if (byStage != 0) return byStage;

            return a.depotName.toLowerCase().compareTo(
              b.depotName.toLowerCase(),
            );
          }),
      ),
    );
  }

  groups.sort((a, b) {
    final byCompany = a.companyName.toLowerCase().compareTo(
      b.companyName.toLowerCase(),
    );
    if (byCompany != 0) return byCompany;
    return marketRank(a.market).compareTo(marketRank(b.market));
  });

  return groups;
}
