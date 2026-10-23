import 'package:eal_scanner/theme/app_tokens.dart';

/// Which figure a module leads with. Issuance counts labels; production and
/// dispatch count cases, because that is what the floor and the depot count.
enum ScanUnit { labels, cases }

/// How the operator left the summary.
enum ScanOutcome {
  /// Sent, and finished.
  done,

  /// Sent, and wants to record another range against the same target.
  another,
}

/// Describes what a scan is being recorded against, so one wizard can serve
/// issuance, production and dispatch instead of the three near-identical
/// copies the old build carried.
class ScanTarget {
  const ScanTarget({
    required this.module,
    required this.title,
    required this.contextLine,
    required this.bottlesPerCase,
    required this.unit,
    required this.submit,
    this.allowRangeQr = false,
    this.initialPrefix = '',
    this.requiredCases,
    this.alreadyLinkedCases,
    this.subjectName,
    this.subjectMarket,
  });

  final AppModule module;

  /// App bar title, e.g. "Link labels".
  final String title;

  /// The thing being recorded against, e.g. "Central Depot · Reserve Whisky".
  final String contextLine;

  final int bottlesPerCase;
  final ScanUnit unit;

  /// Some issuance QR codes carry both ends of the range, which collapses the
  /// two scan steps into one. Only issuance labels are printed that way.
  final bool allowRangeQr;

  final String initialPrefix;

  /// Dispatch lines have a quantity to reach, so the wizard can say whether
  /// this range completes the line or leaves it short.
  final int? requiredCases;
  final int? alreadyLinkedCases;

  /// What the count is of, named beside the figure once both ends are in,
  /// so the number can be checked against the day sheet without reading the
  /// app bar. Production sets these; a module that leaves them null keeps
  /// the paired figures inside the range card.
  final String? subjectName;
  final String? subjectMarket;

  /// Returns null when the server accepted it, otherwise the message to show.
  final Future<String?> Function(ScanDraft draft) submit;

  bool get hasTargetQuantity => requiredCases != null && requiredCases! > 0;

  /// What the module does with the range, for the button that sends it.
  /// "Record 1,000 cases" on a run; "Link 160 cases" against a dispatch
  /// line, where recording is not what is happening.
  String get actionVerb => module == AppModule.dispatch ? 'Link' : 'Record';

  /// What the large figure counts, named under it.
  String get countLabel =>
      module == AppModule.dispatch ? 'cases to link' : 'cases produced';

  /// True where the finished count gets a card of its own rather than a
  /// tile beside the labels.
  bool get verifiesCount => subjectName != null && unit == ScanUnit.cases;
}

/// A range being assembled, step by step.
class ScanDraft {
  const ScanDraft({
    this.prefix = '',
    this.serialFrom = '',
    this.serialTo = '',
    this.rawFrom,
    this.rawTo,
    this.fromTypedByHand = false,
    this.toTypedByHand = false,
    this.rangeFromSingleQr = false,
    this.capturedFromAt,
    this.capturedToAt,
  });

  final String prefix;

  /// Both padded to ten digits, as the API expects them.
  final String serialFrom;
  final String serialTo;

  /// The raw QR payloads, kept so a mis-scan can be recognised.
  final String? rawFrom;
  final String? rawTo;

  /// Typed rather than scanned. Carried through to the summary so the record
  /// shows how the figure was obtained.
  final bool fromTypedByHand;
  final bool toTypedByHand;

  /// One QR carried the whole range, so there is no separate second step.
  final bool rangeFromSingleQr;

  final DateTime? capturedFromAt;
  final DateTime? capturedToAt;

  bool get hasPrefix => prefix.length == 3;
  bool get hasFrom => serialFrom.isNotEmpty;
  bool get hasTo => serialTo.isNotEmpty;
  bool get isComplete => hasPrefix && hasFrom && hasTo;
  bool get typedByHand => fromTypedByHand || toTypedByHand;

  int get from => int.tryParse(serialFrom) ?? 0;
  int get to => int.tryParse(serialTo) ?? 0;

  /// Matches the old `calculateStickerCount`.
  int get labels {
    if (!hasFrom || !hasTo) return 0;
    final count = to - from + 1;
    return count < 0 ? 0 : count;
  }

  /// Whole cases only; the API takes an integer.
  int casesFor(int bottlesPerCase) {
    if (bottlesPerCase <= 0) return 0;
    return labels ~/ bottlesPerCase;
  }

  /// True when the range does not divide into whole cases.
  ///
  /// A part case is not a rounding problem, it is a wrong scan: one of the
  /// two ends names the wrong label. The range is refused rather than
  /// truncated, because [casesFor] would quietly drop the remainder.
  bool isPartialCase(int bottlesPerCase) {
    if (bottlesPerCase <= 0 || labels == 0) return false;
    return labels % bottlesPerCase != 0;
  }

  /// The inverse of [isPartialCase], for readability at call sites that gate
  /// on the range being acceptable.
  bool hasWholeCases(int bottlesPerCase) => !isPartialCase(bottlesPerCase);

  /// Labels left over beyond the last whole case.
  int remainderFor(int bottlesPerCase) {
    if (bottlesPerCase <= 0 || labels == 0) return 0;
    return labels % bottlesPerCase;
  }

  bool get isBackwards => hasFrom && hasTo && to < from;

  ScanDraft copyWith({
    String? prefix,
    String? serialFrom,
    String? serialTo,
    String? rawFrom,
    String? rawTo,
    bool? fromTypedByHand,
    bool? toTypedByHand,
    bool? rangeFromSingleQr,
    DateTime? capturedFromAt,
    DateTime? capturedToAt,
  }) {
    return ScanDraft(
      prefix: prefix ?? this.prefix,
      serialFrom: serialFrom ?? this.serialFrom,
      serialTo: serialTo ?? this.serialTo,
      rawFrom: rawFrom ?? this.rawFrom,
      rawTo: rawTo ?? this.rawTo,
      fromTypedByHand: fromTypedByHand ?? this.fromTypedByHand,
      toTypedByHand: toTypedByHand ?? this.toTypedByHand,
      rangeFromSingleQr: rangeFromSingleQr ?? this.rangeFromSingleQr,
      capturedFromAt: capturedFromAt ?? this.capturedFromAt,
      capturedToAt: capturedToAt ?? this.capturedToAt,
    );
  }
}

/// Reads an EAL QR payload.
///
/// Two formats are in circulation and both are preserved exactly as the old
/// screens parsed them:
///
///  * the pipe-separated official label, whose second field is the serial of
///    the *last* bottle in that case, and
///  * an underscore-separated form that carries a whole range in one code.
class EalQrCodec {
  EalQrCodec._();

  /// Case-insensitive, and the prefix may carry a dash or a dot: labels
  /// come from several presses and they are not all printed the same way.
  /// The serial is held to eight to twelve digits rather than exactly ten,
  /// because a press that drops a leading zero still prints a real label.
  static final RegExp _single = RegExp(
    r'^([A-Za-z0-9.\-]+)\|(\d{8,12})\|(\d{8,12})\|(\d{8,12})\|(\d+)\|(\d+)$',
  );

  static final RegExp _range = RegExp(r'^(\d{8,12})_(\d{8,12})_.*[|~]\d*\|?$');

  /// A payload as it comes off the camera: a code often carries a trailing
  /// newline, and a label held at an angle can pick up a leading space.
  /// Neither is a reason to refuse it.
  static String clean(String raw) => raw.trim();

  /// Pads a serial the way the API expects it.
  static String pad(int serial) => serial.toString().padLeft(10, '0');

  /// The serial printed on a single label.
  static int? readSingle(String raw) {
    final value = clean(raw);
    if (!_single.hasMatch(value)) return null;
    return int.tryParse(value.split('|')[1]);
  }

  /// The prefix the label itself carries, where it has one. The operator
  /// types a prefix before scanning, and a label from another book reads
  /// as a perfectly good number under it.
  static String? prefixOf(String raw) {
    final match = _single.firstMatch(clean(raw));
    return match?.group(1)?.toUpperCase();
  }

  /// Both ends of a range, where the code carries them.
  static ({String from, String to})? readRange(String raw) {
    final match = _range.firstMatch(clean(raw));
    if (match == null) return null;

    final from = match.group(1);
    final to = match.group(2);
    if (from == null || to == null) return null;

    return (from: from, to: to);
  }

  static bool looksLikeRange(String raw) => _range.hasMatch(clean(raw));

  /// A scanned code names the last bottle of its case, so the first serial of
  /// the run sits a full case earlier. This is the arithmetic the old screens
  /// applied and it is why the operator scans the *first* case's label.
  static String firstSerialOfCase(int scanned, int bottlesPerCase) {
    final first = scanned - bottlesPerCase + 1;
    return pad(first < 0 ? 0 : first);
  }
}
