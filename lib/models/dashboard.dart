/// Models for `GET /api/v1/dashboard`.
///
/// One call replaces the three full-document list fetches the home screen
/// would otherwise need, and it is the only place the "short of labels"
/// figures come from pre-computed.
double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

double? _numOrNull(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int _int(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _date(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

/// One headline figure, with the equivalent figure for the preceding period.
class DashboardKpi {
  DashboardKpi({
    required this.value,
    required this.unit,
    required this.previous,
    required this.changePct,
    required this.count,
    this.openRanges,
    this.shareOfIssuedPct,
  });

  final double value;
  final String unit;
  final double previous;

  /// Null when the earlier figure was zero — the change is undefined, not
  /// infinite, and the UI says "no prior figure" rather than showing 0%.
  final double? changePct;
  final int count;
  final int? openRanges;
  final double? shareOfIssuedPct;

  factory DashboardKpi.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return DashboardKpi(
      value: _num(j['value']),
      unit: _str(j['unit']) ?? 'labels',
      previous: _num(j['previous']),
      changePct: _numOrNull(j['changePct']),
      count: _int(j['count']),
      openRanges: j['openRanges'] == null ? null : _int(j['openRanges']),
      shareOfIssuedPct: _numOrNull(j['shareOfIssuedPct']),
    );
  }

  static DashboardKpi empty() => DashboardKpi(
    value: 0,
    unit: 'labels',
    previous: 0,
    changePct: null,
    count: 0,
  );
}

/// A dispatch note still short of EAL links.
class OpenNote {
  OpenNote({
    required this.id,
    required this.depot,
    required this.company,
    required this.market,
    required this.status,
    required this.cases,
    required this.linkedCases,
    required this.outstandingCases,
    required this.linkedPct,
    required this.ageDays,
    this.dateDispatched,
  });

  final String id;
  final String? depot;
  final String? company;
  final String market;
  final String status;
  final double cases;
  final double linkedCases;
  final double outstandingCases;
  final double linkedPct;
  final int ageDays;
  final DateTime? dateDispatched;

  factory OpenNote.fromJson(Map<String, dynamic> json) {
    return OpenNote(
      id: _str(json['id']) ?? '',
      depot: _str(json['depot']),
      company: _str(json['company']),
      market: _str(json['market']) ?? 'local',
      status: _str(json['status']) ?? 'draft',
      cases: _num(json['cases']),
      linkedCases: _num(json['linkedCases']),
      outstandingCases: _num(json['outstandingCases']),
      linkedPct: _num(json['linkedPct']),
      ageDays: _int(json['ageDays']),
      dateDispatched: _date(json['dateDispatched']),
    );
  }
}

class AwaitingLinking {
  AwaitingLinking({
    required this.count,
    required this.casesOutstanding,
    required this.notes,
  });

  final int count;
  final double casesOutstanding;
  final List<OpenNote> notes;

  factory AwaitingLinking.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    final raw = j['notes'];
    return AwaitingLinking(
      count: _int(j['count']),
      casesOutstanding: _num(j['casesOutstanding']),
      notes: raw is List
          ? raw
                .whereType<Map>()
                .map((e) => OpenNote.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const <OpenNote>[],
    );
  }

  static AwaitingLinking empty() =>
      AwaitingLinking(count: 0, casesOutstanding: 0, notes: const []);
}

enum MovementType { issuance, usage, dispatchLink, unknown }

/// One entry in the merged activity feed.
class Movement {
  Movement({
    required this.type,
    required this.event,
    required this.prefix,
    required this.serialFrom,
    required this.serialTo,
    required this.quantity,
    required this.unit,
    this.at,
    this.company,
    this.item,
    this.packName,
    this.bottlesPerCase,
    this.market,
    this.status,
    this.user,
    this.dispatchId,
  });

  final MovementType type;
  final String event;
  final String prefix;
  final int serialFrom;
  final int serialTo;
  final double quantity;
  final String unit;
  final DateTime? at;
  final String? company;
  final String? item;
  final String? packName;
  final int? bottlesPerCase;
  final String? market;
  final String? status;
  final String? user;
  final String? dispatchId;

  /// The feed reports labels; the floor counts cases.
  double? get cases {
    final per = bottlesPerCase;
    if (per == null || per <= 0) return null;
    return quantity / per;
  }

  /// The best available name for the row: the item where there is one,
  /// otherwise the pack it was issued against.
  String get title => item ?? packName ?? company ?? event;

  factory Movement.fromJson(Map<String, dynamic> json) {
    final pack = json['pack'];
    final packMap = pack is Map ? Map<String, dynamic>.from(pack) : null;

    return Movement(
      type: switch (_str(json['type'])) {
        'issuance' => MovementType.issuance,
        'usage' => MovementType.usage,
        'dispatch-link' => MovementType.dispatchLink,
        _ => MovementType.unknown,
      },
      event: _str(json['event']) ?? 'Activity',
      prefix: _str(json['prefix']) ?? '',
      serialFrom: _int(json['serialFrom']),
      serialTo: _int(json['serialTo']),
      quantity: _num(json['quantity']),
      unit: _str(json['unit']) ?? 'labels',
      at: _date(json['at']),
      company: _str(json['company']),
      item: _str(json['item']),
      packName: packMap == null ? null : _str(packMap['name']),
      bottlesPerCase: packMap == null ? null : _int(packMap['bottlesPerCase']),
      market: _str(json['market']),
      status: _str(json['status']),
      user: _str(json['user']),
      dispatchId: _str(json['dispatchId']),
    );
  }
}

class DashboardData {
  DashboardData({
    required this.labelsOnHand,
    required this.issued,
    required this.applied,
    required this.dispatched,
    required this.awaitingLinking,
    required this.recentMovement,
    this.periodStart,
    this.periodEnd,
  });

  final DashboardKpi labelsOnHand;
  final DashboardKpi issued;
  final DashboardKpi applied;
  final DashboardKpi dispatched;
  final AwaitingLinking awaitingLinking;
  final List<Movement> recentMovement;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final kpis = json['kpis'] is Map
        ? Map<String, dynamic>.from(json['kpis'] as Map)
        : const <String, dynamic>{};
    final period = json['period'] is Map
        ? Map<String, dynamic>.from(json['period'] as Map)
        : const <String, dynamic>{};
    final movement = json['recentMovement'];

    Map<String, dynamic>? kpi(String key) =>
        kpis[key] is Map ? Map<String, dynamic>.from(kpis[key] as Map) : null;

    return DashboardData(
      labelsOnHand: DashboardKpi.fromJson(kpi('labelsOnHand')),
      issued: DashboardKpi.fromJson(kpi('issued')),
      applied: DashboardKpi.fromJson(kpi('applied')),
      dispatched: DashboardKpi.fromJson(kpi('dispatched')),
      awaitingLinking: AwaitingLinking.fromJson(
        json['awaitingLinking'] is Map
            ? Map<String, dynamic>.from(json['awaitingLinking'] as Map)
            : null,
      ),
      recentMovement: movement is List
          ? movement
                .whereType<Map>()
                .map((e) => Movement.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const <Movement>[],
      periodStart: _date(period['startDate']),
      periodEnd: _date(period['endDate']),
    );
  }

  static DashboardData empty() => DashboardData(
    labelsOnHand: DashboardKpi.empty(),
    issued: DashboardKpi.empty(),
    applied: DashboardKpi.empty(),
    dispatched: DashboardKpi.empty(),
    awaitingLinking: AwaitingLinking.empty(),
    recentMovement: const [],
  );
}
