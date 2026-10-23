import 'package:eal_scanner/models/items.dart';

/// Everything the server knows about one label.
///
/// A serial on its own does not name a label: a prefix is reused across
/// packs and the ranges under it overlap, so the same ten digits can sit in
/// two issuances. The server answers that in one of two ways — either it
/// asks which book ([needsChoice], with [candidates]), or it traces the one
/// book it could settle on and reads each stage from the stage before it.
class EalTrace {
  const EalTrace({
    required this.serial,
    required this.prefix,
    required this.state,
    required this.needsChoice,
    required this.candidates,
    required this.book,
    required this.runs,
    required this.dispatches,
  });

  final int serial;

  /// The prefix as asked for, which may be empty where only digits were.
  final String prefix;

  /// Where the label has got to: on-hand, applied, linked, in-transit or
  /// delivered. The server reads it off the furthest stage reached.
  final String state;

  /// The server could not settle on one book, so the operator picks.
  final bool needsChoice;

  /// The books that hold this serial. Sent when the choice is open, and
  /// again alongside a reading so the way back to the others stays open.
  final List<TraceBook> candidates;

  /// The book this reading is of, where there is one.
  final TraceBook? book;

  final List<TraceRun> runs;
  final List<TraceDispatch> dispatches;

  bool get wasUsed => runs.isNotEmpty;
  bool get wasDispatched => dispatches.isNotEmpty;

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse('$value');

  static String? _name(dynamic value) =>
      value is Map ? value['name']?.toString() : null;

  /// Who typed it in. The server populates createdBy with the full name,
  /// and falls back to the account it was signed in under.
  static String _person(dynamic value) {
    if (value is! Map) return '';
    final name = '${value['fullName'] ?? ''}'.trim();
    return name.isNotEmpty ? name : '${value['email'] ?? ''}'.trim();
  }

  static List<dynamic> _list(dynamic value) => value is List ? value : const [];

  factory EalTrace.fromJson(Map<String, dynamic> json) {
    final issuance = json['issuance'];

    return EalTrace(
      serial: _int(json['serial']),
      prefix: '${json['prefix'] ?? ''}',
      state: '${json['state'] ?? ''}',
      needsChoice: json['needsChoice'] == true,
      candidates: _list(
        json['candidates'],
      ).map((e) => TraceBook.fromJson(e as Map<String, dynamic>)).toList(),
      book: issuance is Map<String, dynamic>
          ? TraceBook.fromJson(issuance)
          : null,
      runs: _list(
        json['usage'],
      ).map((e) => TraceRun.fromJson(e as Map<String, dynamic>)).toList(),
      dispatches: _list(
        json['ealDispatches'],
      ).map((e) => TraceDispatch.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// An issuance the serial could have come from: one book of labels.
class TraceBook {
  const TraceBook({
    required this.id,
    required this.prefix,
    required this.packName,
    required this.bottlesPerCase,
    required this.companyName,
    required this.market,
    required this.date,
    required this.serialFrom,
    required this.serialTo,
    required this.issuedQuantity,
    required this.balanceQuantity,
    required this.enteredBy,
    required this.enteredAt,
  });

  /// What the server takes back as the choice.
  final String id;

  final String prefix;
  final String packName;
  final int bottlesPerCase;
  final String companyName;
  final String market;
  final DateTime? date;
  final int serialFrom;
  final int serialTo;
  final int issuedQuantity;
  final int balanceQuantity;

  /// Only on the book being read: a candidate is just enough to choose by.
  final String enteredBy;
  final DateTime? enteredAt;

  /// How the book is named on screen: the pack, and what a case holds.
  String get packLabel =>
      bottlesPerCase > 0 ? '$packName · $bottlesPerCase per case' : packName;

  factory TraceBook.fromJson(Map<String, dynamic> json) {
    final pack = json['pack'];

    return TraceBook(
      id: '${json['id'] ?? json['_id'] ?? ''}',
      prefix: '${json['prefix'] ?? ''}',
      packName: EalTrace._name(pack) ?? '—',
      bottlesPerCase: pack is Map ? EalTrace._int(pack['bottlesPerCase']) : 0,
      companyName: EalTrace._name(json['company']) ?? '—',
      market: '${json['market'] ?? ''}',
      date: EalTrace._date(json['dateIssued']),
      serialFrom: EalTrace._int(json['serialFrom']),
      serialTo: EalTrace._int(json['serialTo']),
      issuedQuantity: EalTrace._int(json['issuedQuantity']),
      balanceQuantity: EalTrace._int(json['balanceQuantity']),
      enteredBy: EalTrace._person(json['createdBy']),
      enteredAt: EalTrace._date(json['createdAt']),
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
    required this.enteredBy,
    required this.enteredAt,
  });

  final String id;
  final DateTime? date;
  final int serialFrom;
  final int serialTo;
  final String itemName;
  final int cases;

  /// Cases of this run that have not gone out yet.
  final int waitingCases;

  final String enteredBy;
  final DateTime? enteredAt;

  factory TraceRun.fromJson(Map<String, dynamic> json) {
    return TraceRun(
      id: '${json['id'] ?? json['_id'] ?? ''}',
      date: EalTrace._date(json['dateUsed']),
      serialFrom: EalTrace._int(json['serialFrom']),
      serialTo: EalTrace._int(json['serialTo']),
      itemName: Item.displayNameFromJson(json['item']),
      cases: EalTrace._int(json['usedQuantityInCases']),
      waitingCases: EalTrace._int(json['balanceQuantityInCases']),
      enteredBy: EalTrace._person(json['createdBy']),
      enteredAt: EalTrace._date(json['createdAt']),
    );
  }
}

/// A dispatch link, with the note it belongs to carried alongside it.
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
    required this.enteredBy,
    required this.enteredAt,
  });

  final String id;
  final String dispatchId;
  final DateTime? date;
  final int serialFrom;
  final int serialTo;
  final int cases;

  /// Empty where the note did not come back with the link.
  final String depotName;
  final String status;

  final String enteredBy;
  final DateTime? enteredAt;

  factory TraceDispatch.fromJson(Map<String, dynamic> json) {
    final note = json['note'];

    return TraceDispatch(
      id: '${json['id'] ?? json['_id'] ?? ''}',
      dispatchId: '${json['dispatchId'] ?? ''}',
      date: EalTrace._date(json['dateDispatched']),
      serialFrom: EalTrace._int(json['serialFrom']),
      serialTo: EalTrace._int(json['serialTo']),
      cases: EalTrace._int(json['usedQuantityInCases']),
      depotName: note is Map ? EalTrace._name(note['deliveryTo']) ?? '' : '',
      status: note is Map ? '${note['status'] ?? ''}' : '',
      enteredBy: EalTrace._person(json['createdBy']),
      enteredAt: EalTrace._date(json['createdAt']),
    );
  }
}
