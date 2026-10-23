import 'package:eal_scanner/models/items.dart';

/// Everything the server knows about one label.
///
/// The find endpoint answers with four lists — the issuance that covers the
/// serial, the production runs that consumed it, the dispatch links that
/// carry it, and the dispatch notes those links belong to. A label passes
/// through those three stages in that order, so they are read as stages
/// here rather than kept as four parallel lists.
class EalTrace {
  const EalTrace({
    required this.serial,
    required this.prefix,
    required this.issuances,
    required this.runs,
    required this.dispatches,
  });

  final int serial;
  final String prefix;
  final List<TraceIssuance> issuances;
  final List<TraceRun> runs;
  final List<TraceDispatch> dispatches;

  /// The label exists at all: the server answers 404 when no issuance
  /// covers the serial, so an empty list here means nothing was found.
  bool get wasIssued => issuances.isNotEmpty;
  bool get wasUsed => runs.isNotEmpty;
  bool get wasDispatched => dispatches.isNotEmpty;

  /// What the label is, where that is known. The issuance names the pack
  /// and the company; a run names the item it was stuck on.
  String? get itemName => runs.isEmpty ? null : runs.first.itemName;
  String? get companyName =>
      issuances.isEmpty ? null : issuances.first.companyName;
  String? get packName => issuances.isEmpty ? null : issuances.first.packName;
  int? get bottlesPerCase =>
      issuances.isEmpty ? null : issuances.first.bottlesPerCase;
  String? get market => issuances.isEmpty ? null : issuances.first.market;

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }

  static String? _name(dynamic value) {
    if (value is Map) return value['name']?.toString();
    return null;
  }

  factory EalTrace.fromJson(Map<String, dynamic> json) {
    final body = (json['respondData'] ?? json) as Map<String, dynamic>;

    final issuances = ((body['issuance'] ?? []) as List)
        .map((e) => TraceIssuance.fromJson(e as Map<String, dynamic>))
        .toList();

    final runs = ((body['usage'] ?? []) as List)
        .map((e) => TraceRun.fromJson(e as Map<String, dynamic>))
        .toList();

    // The links carry the serials; the notes carry the depot and the stage.
    // They arrive as two lists joined by dispatchId.
    final notes = <String, Map<String, dynamic>>{
      for (final n in ((body['dispatches'] ?? []) as List))
        '${(n as Map<String, dynamic>)['_id'] ?? n['id']}': n,
    };

    final dispatches = ((body['ealDispatches'] ?? []) as List)
        .map(
          (e) => TraceDispatch.fromJson(
            e as Map<String, dynamic>,
            notes['${e['dispatchId']}'],
          ),
        )
        .toList();

    return EalTrace(
      serial: _int(body['serial']),
      prefix: (body['prefix'] ?? '').toString(),
      issuances: issuances,
      runs: runs,
      dispatches: dispatches,
    );
  }
}

/// The issuance that covers the serial: where the label came from.
class TraceIssuance {
  const TraceIssuance({
    required this.id,
    required this.date,
    required this.serialFrom,
    required this.serialTo,
    required this.issuedQuantity,
    required this.balanceQuantity,
    required this.companyName,
    required this.packName,
    required this.bottlesPerCase,
    required this.market,
  });

  final String id;
  final DateTime? date;
  final int serialFrom;
  final int serialTo;
  final int issuedQuantity;
  final int balanceQuantity;
  final String companyName;
  final String packName;
  final int bottlesPerCase;
  final String market;

  factory TraceIssuance.fromJson(Map<String, dynamic> json) {
    final pack = json['pack'];

    return TraceIssuance(
      id: '${json['id'] ?? json['_id'] ?? ''}',
      date: EalTrace._date(json['dateIssued']),
      serialFrom: EalTrace._int(json['serialFrom']),
      serialTo: EalTrace._int(json['serialTo']),
      issuedQuantity: EalTrace._int(json['issuedQuantity']),
      balanceQuantity: EalTrace._int(json['balanceQuantity']),
      companyName: EalTrace._name(json['company']) ?? '—',
      packName: EalTrace._name(pack) ?? '—',
      bottlesPerCase: pack is Map ? EalTrace._int(pack['bottlesPerCase']) : 0,
      market: '${json['market'] ?? ''}',
    );
  }
}

/// A production run that applied the label.
class TraceRun {
  const TraceRun({
    required this.id,
    required this.date,
    required this.serialFrom,
    required this.serialTo,
    required this.itemName,
    required this.cases,
    required this.waitingCases,
  });

  final String id;
  final DateTime? date;
  final int serialFrom;
  final int serialTo;
  final String itemName;
  final int cases;

  /// Cases of this run that have not gone out yet.
  final int waitingCases;

  factory TraceRun.fromJson(Map<String, dynamic> json) {
    return TraceRun(
      id: '${json['id'] ?? json['_id'] ?? ''}',
      date: EalTrace._date(json['dateUsed']),
      serialFrom: EalTrace._int(json['serialFrom']),
      serialTo: EalTrace._int(json['serialTo']),
      itemName: Item.displayNameFromJson(json['item']),
      cases: EalTrace._int(json['usedQuantityInCases']),
      waitingCases: EalTrace._int(json['balanceQuantityInCases']),
    );
  }
}

/// A dispatch link, with the note it belongs to where the server sent one.
class TraceDispatch {
  const TraceDispatch({
    required this.id,
    required this.dispatchId,
    required this.date,
    required this.serialFrom,
    required this.serialTo,
    required this.cases,
    required this.depotName,
    required this.status,
  });

  final String id;
  final String dispatchId;
  final DateTime? date;
  final int serialFrom;
  final int serialTo;
  final int cases;

  /// Empty where the note itself did not come back with the links.
  final String depotName;
  final String status;

  factory TraceDispatch.fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic>? note,
  ) {
    return TraceDispatch(
      id: '${json['id'] ?? json['_id'] ?? ''}',
      dispatchId: '${json['dispatchId'] ?? ''}',
      date: EalTrace._date(json['dateDispatched']),
      serialFrom: EalTrace._int(json['serialFrom']),
      serialTo: EalTrace._int(json['serialTo']),
      cases: EalTrace._int(json['usedQuantityInCases']),
      depotName: note == null ? '' : EalTrace._name(note['deliveryTo']) ?? '',
      status: note == null ? '' : '${note['status'] ?? ''}',
    );
  }
}
