import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// Typing a serial when the label will not read.
///
/// The old flow had no fallback at all: a torn or smudged label stopped the
/// entry dead. The arithmetic is shown as it is typed, so a transposed digit
/// surfaces as a wrong case count rather than a wrong record.
class ManualSerialScreen extends StatefulWidget {
  const ManualSerialScreen({
    super.key,
    required this.prefix,
    required this.bottlesPerCase,
    required this.isFrom,
    this.counterpartSerial,
    this.stepIndex,
    this.stepCount,
    this.accent = AppColors.blue,
  });

  final String prefix;
  final int bottlesPerCase;

  /// The first label of the run, which sits a case earlier than the serial
  /// printed on it, or the last label, which is taken as printed.
  final bool isFrom;

  /// The other end of the range, where it is already known, so the counts
  /// can be shown live.
  final String? counterpartSerial;

  final int? stepIndex;
  final int? stepCount;
  final Color accent;

  @override
  State<ManualSerialScreen> createState() => _ManualSerialScreenState();
}

class _ManualSerialScreenState extends State<ManualSerialScreen> {
  final TextEditingController _field = TextEditingController();
  String _digits = '';

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  int? get _typed => _digits.isEmpty ? null : int.tryParse(_digits);

  /// What will actually be recorded for this end of the range.
  ///
  /// Typed serials are taken exactly as entered, for both ends. Only a
  /// scanned code gets counted back a case, because a QR names the last
  /// bottle of its case; someone typing is reading the serial they want
  /// recorded, so adjusting it would record a number they never saw.
  String? get _recorded {
    final typed = _typed;
    if (typed == null) return null;
    return EalQrCodec.pad(typed);
  }

  int? get _labels {
    final recorded = _recorded;
    final other = widget.counterpartSerial;
    if (recorded == null || other == null || other.isEmpty) return null;

    final a = int.tryParse(recorded);
    final b = int.tryParse(other);
    if (a == null || b == null) return null;

    final from = widget.isFrom ? a : b;
    final to = widget.isFrom ? b : a;
    final count = to - from + 1;
    return count < 0 ? null : count;
  }

  /// Whether the range this would make divides into whole cases. Null when
  /// the other end is not known yet, so there is nothing to check against.
  bool? get _wholeCases {
    final labels = _labels;
    if (labels == null || widget.bottlesPerCase <= 0) return null;
    return labels % widget.bottlesPerCase == 0;
  }

  bool get _canSubmit =>
      _recorded != null && _digits.length <= 10 && _wholeCases != false;

  @override
  Widget build(BuildContext context) {
    final recorded = _recorded;
    final labels = _labels;
    final cases = labels == null || widget.bottlesPerCase <= 0
        ? null
        : labels ~/ widget.bottlesPerCase;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        shape: const Border(
          bottom: BorderSide(color: AppColors.line, width: 1),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isFrom ? 'Type the first serial' : 'Type the last serial',
              style: AppText.appBarTitle,
            ),
            if (widget.stepIndex != null && widget.stepCount != null)
              Text(
                'Step ${widget.stepIndex} of ${widget.stepCount}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.ink500,
                ),
              ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.lg,
          AppSpace.gutter,
          AppSpace.xxl,
        ),
        children: [
          Text(
            'For labels that are torn, smudged or will not read. The serial '
            'is recorded exactly as you type it, so enter the '
            '${widget.isFrom ? 'first' : 'last'} serial of the run itself.',
            style: AppText.bodyMuted,
          ),

          const SizedBox(height: AppSpace.lg),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Prefix', style: AppText.micro),
                      const SizedBox(height: 1),
                      Text(
                        widget.prefix.isEmpty ? '—' : widget.prefix,
                        style: AppText.mono(
                          size: 16,
                          weight: FontWeight.w600,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${widget.bottlesPerCase} per case',
                  style: AppText.small,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpace.lg),
          Text(
            widget.isFrom ? 'First serial of the run' : 'Last serial of the run',
            style: AppText.label,
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _field,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: AppText.mono(size: 26, weight: FontWeight.w600, letterSpacing: 1.6),
            onChanged: (v) => setState(() => _digits = v),
            decoration: InputDecoration(
              hintText: '0000000000',
              hintStyle: AppText.mono(
                size: 26,
                weight: FontWeight.w600,
                color: AppColors.ink400,
                letterSpacing: 1.6,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixText: '${_digits.length}/10',
              suffixStyle: AppText.mono(size: 12, color: AppColors.ink500),
            ),
          ),

          const SizedBox(height: 9),
          if (recorded == null)
            Text(
              'Type only the digits. Leading zeros are filled in for you.',
              style: AppText.small,
            )
          else
            Row(
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: AppColors.green,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Row(
                    children: [
                      Text('Records as ', style: AppText.small),
                      Flexible(
                        child: SerialValue(
                          serial: int.parse(recorded),
                          prefix: widget.prefix,
                          size: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          if (labels != null) ...[
            const SizedBox(height: AppSpace.lg),
            AppCard(
              background: AppColors.blueTint,
              borderColor: AppColors.blueLine,
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'THIS MAKES THE RANGE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.72,
                      color: AppColors.blueDeep,
                    ),
                  ),
                  const SizedBox(height: 9),
                  SerialRangeText(
                    prefix: widget.prefix,
                    from: widget.isFrom
                        ? int.parse(recorded!)
                        : int.parse(widget.counterpartSerial!),
                    to: widget.isFrom
                        ? int.parse(widget.counterpartSerial!)
                        : int.parse(recorded!),
                    size: 14,
                    showPrefix: false,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Figure(value: formatQty(labels), label: 'labels'),
                      const SizedBox(width: 20),
                      if (cases != null)
                        _Figure(value: formatQty(cases), label: 'cases'),
                    ],
                  ),
                ],
              ),
            ),
          ],

          if (_wholeCases == false) ...[
            const SizedBox(height: AppSpace.lg),
            NoticeBanner(
              title: 'Not a whole number of cases',
              message: '${labels! % widget.bottlesPerCase} labels over '
                  '${formatQty(labels ~/ widget.bottlesPerCase)}. Check the '
                  'serial — this range cannot be recorded.',
            ),
          ],

          const SizedBox(height: AppSpace.lg),
          NoticeBanner(
            title: 'Marked as entered by hand',
            message: 'Typed serials are flagged on the record so a supervisor '
                'can check them against the physical stock.',
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              12,
              AppSpace.gutter,
              12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: _canSubmit
                      ? () => Navigator.pop(context, _recorded)
                      : null,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: widget.accent),
                  child: const Text('Use this serial'),
                ),
                if (_wholeCases == false) ...[
                  const SizedBox(height: 9),
                  Text(
                    'The range must make whole cases',
                    textAlign: TextAlign.center,
                    style: AppText.small,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppText.figure(size: 20)),
        Text(label, style: AppText.micro),
      ],
    );
  }
}
