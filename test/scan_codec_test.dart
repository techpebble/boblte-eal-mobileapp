import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// The QR formats and the case arithmetic were ported from the three old
/// scan screens into one codec. These pin that behaviour, because getting the
/// "from" serial wrong by one case silently mis-states every quantity.
void main() {
  group('serial presentation', () {
    test('leading zeros are separated from the significant digits', () {
      final parts = splitSerial(12001);
      expect(parts.zeros, '00000');
      expect(parts.digits, '12001');
      expect(parts.zeros.length + parts.digits.length, kSerialDigits);
    });

    test('a serial of zero still renders a digit', () {
      final parts = splitSerial(0);
      expect(parts.digits, '0');
      expect(parts.zeros, '000000000');
    });

    test('a full-width serial has no padding', () {
      final parts = splitSerial(1234567890);
      expect(parts.zeros, isEmpty);
      expect(parts.digits, '1234567890');
    });
  });

  group('official pipe-separated label', () {
    const payload = 'ML123|0000012012|0000012001|0000012012|12|1';

    test('the second field is read as the scanned serial', () {
      expect(EalQrCodec.readSingle(payload), 12012);
    });

    test('a carton barcode or any other code is rejected', () {
      expect(EalQrCodec.readSingle('8901234567890'), isNull);
      expect(EalQrCodec.readSingle('ML123|12|34'), isNull);
      expect(EalQrCodec.readSingle(''), isNull);
    });

    test('the label names the last bottle of its case', () {
      // Scanning the first case of a 12-bottle pack yields a run starting a
      // full case earlier: 12012 - 12 + 1.
      expect(EalQrCodec.firstSerialOfCase(12012, 12), '0000012001');
      expect(EalQrCodec.firstSerialOfCase(1752, 24), '0000001729');
    });

    test('the first serial never goes below zero', () {
      expect(EalQrCodec.firstSerialOfCase(5, 48), '0000000000');
    });
  });

  group('underscore-separated range label', () {
    const payload = '0000012001_0000060000_ABC|5|';

    test('both ends come from one code', () {
      expect(EalQrCodec.looksLikeRange(payload), isTrue);

      final range = EalQrCodec.readRange(payload);
      expect(range, isNotNull);
      expect(range!.from, '0000012001');
      expect(range.to, '0000060000');
    });

    test('a single-label payload is not mistaken for a range', () {
      expect(
        EalQrCodec.looksLikeRange(
          'ML123|0000012012|0000012001|0000012012|12|1',
        ),
        isFalse,
      );
    });
  });

  group('draft arithmetic', () {
    ScanDraft draftOf(String from, String to) =>
        ScanDraft(prefix: 'ML1', serialFrom: from, serialTo: to);

    test('labels are inclusive of both ends', () {
      expect(draftOf('0000012001', '0000013920').labels, 1920);
      expect(draftOf('0000012001', '0000012001').labels, 1);
    });

    test('cases divide down to whole cases only', () {
      final draft = draftOf('0000012001', '0000013920');
      expect(draft.casesFor(12), 160);
      expect(draft.isPartialCase(12), isFalse);
    });

    test('a range that is not a whole number of cases is flagged', () {
      final draft = draftOf('0000012001', '0000012010');
      expect(draft.labels, 10);
      expect(draft.casesFor(12), 0);
      expect(draft.isPartialCase(12), isTrue);
    });

    test('a backwards range is detected rather than counted', () {
      final draft = draftOf('0000013920', '0000012001');
      expect(draft.isBackwards, isTrue);
      expect(draft.labels, 0);
    });

    test('a draft is only complete with a prefix and both ends', () {
      expect(const ScanDraft().isComplete, isFalse);
      expect(
        const ScanDraft(
          prefix: 'ML',
          serialFrom: '1',
          serialTo: '2',
        ).isComplete,
        isFalse,
        reason: 'the prefix is three characters',
      );
      expect(draftOf('0000012001', '0000013920').isComplete, isTrue);
    });

    test('typing either end marks the record as entered by hand', () {
      expect(draftOf('1', '2').typedByHand, isFalse);
      expect(
        draftOf('1', '2').copyWith(toTypedByHand: true).typedByHand,
        isTrue,
      );
    });

    test('a zero bottlesPerCase cannot divide by zero', () {
      final draft = draftOf('0000012001', '0000013920');
      expect(draft.casesFor(0), 0);
      expect(draft.isPartialCase(0), isFalse);
    });
  });

  group('whole cases only', () {
    // A part case is a mis-scan, not a rounding problem: casesFor would
    // quietly drop the remainder, so the range is refused instead.
    ScanDraft rangeOf(int from, int to) => ScanDraft(
      prefix: 'ML1',
      serialFrom: from.toString().padLeft(10, '0'),
      serialTo: to.toString().padLeft(10, '0'),
    );

    test('an exact multiple of the case size is accepted', () {
      final draft = rangeOf(12001, 13920);
      expect(draft.labels, 1920);
      expect(draft.hasWholeCases(12), isTrue);
      expect(draft.remainderFor(12), 0);
      expect(draft.casesFor(12), 160);
    });

    test('one label over a case is refused', () {
      final draft = rangeOf(12001, 13921);
      expect(draft.labels, 1921);
      expect(draft.hasWholeCases(12), isFalse);
      expect(draft.remainderFor(12), 1);
    });

    test('one label short of a case is refused', () {
      final draft = rangeOf(12001, 13919);
      expect(draft.labels, 1919);
      expect(draft.hasWholeCases(12), isFalse);
      expect(draft.remainderFor(12), 11);
    });

    test('the same range can be whole for one pack and not another', () {
      final draft = rangeOf(12001, 13920);
      expect(draft.hasWholeCases(12), isTrue, reason: '1920 / 12 = 160');
      expect(draft.hasWholeCases(48), isTrue, reason: '1920 / 48 = 40');
      expect(draft.hasWholeCases(50), isFalse, reason: '1920 / 50 = 38.4');
      expect(draft.remainderFor(50), 20);
    });

    test('a single label is refused unless a case holds one', () {
      final draft = rangeOf(12001, 12001);
      expect(draft.labels, 1);
      expect(draft.hasWholeCases(12), isFalse);
      expect(draft.hasWholeCases(1), isTrue);
    });
  });
}
