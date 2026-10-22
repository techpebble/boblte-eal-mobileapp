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
/// entry dead. Digits come from a keypad built into the screen rather than the
/// system keyboard — the keys are larger, only digits are reachable, and the
/// layout never jumps as a keyboard slides in or out. The arithmetic is shown
/// as it is typed, so a transposed digit surfaces as a wrong case count rather
/// than a wrong record.
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
  String _digits = '';

  void _press(String digit) {
    if (_digits.length >= kSerialDigits) return;
    HapticFeedback.selectionClick();
    setState(() => _digits += digit);
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  void _clear() {
    if (_digits.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _digits = '');
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

  /// The two ends in order, once both are known.
  (int from, int to)? get _ends {
    final recorded = _recorded;
    final other = widget.counterpartSerial;
    if (recorded == null || other == null || other.isEmpty) return null;

    final a = int.tryParse(recorded);
    final b = int.tryParse(other);
    if (a == null || b == null) return null;

    return widget.isFrom ? (a, b) : (b, a);
  }

  /// True when this serial would put the range the wrong way round.
  bool get _backwards {
    final ends = _ends;
    return ends != null && ends.$2 < ends.$1;
  }

  int? get _labels {
    final ends = _ends;
    if (ends == null || ends.$2 < ends.$1) return null;
    return ends.$2 - ends.$1 + 1;
  }

  /// Whether the range this would make divides into whole cases. Null when
  /// the other end is not known yet, so there is nothing to check against.
  bool? get _wholeCases {
    final labels = _labels;
    if (labels == null || widget.bottlesPerCase <= 0) return null;
    return labels % widget.bottlesPerCase == 0;
  }

  bool get _canSubmit =>
      _recorded != null && !_backwards && _wholeCases != false;

  String get _subtitle {
    final parts = <String>[
      if (widget.stepIndex != null && widget.stepCount != null)
        'Step ${widget.stepIndex} of ${widget.stepCount}',
      'recorded exactly as typed',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final complete = _digits.length == kSerialDigits;

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
            Text(
              _subtitle,
              style: const TextStyle(fontSize: 11.5, color: AppColors.ink500),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // The keypad takes a fixed share of the height so the keys stay
          // reachable on a small phone without ever overflowing.
          final keyHeight = ((constraints.maxHeight * 0.55 - 27) / 4).clamp(
            44.0,
            58.0,
          );

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    14,
                    AppSpace.gutter,
                    4,
                  ),
                  children: [
                    // Context as one quiet strip, not a card competing with
                    // the field.
                    Row(
                      children: [
                        SerialPrefixChip(widget.prefix),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.bottlesPerCase} per case',
                          style: AppText.small,
                        ),
                      ],
                    ),

                    // The field comes first: whoever is here is already held
                    // up by a label that would not read.
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            widget.isFrom
                                ? 'First serial of the run'
                                : 'Last serial of the run',
                            style: AppText.label,
                          ),
                        ),
                        Text(
                          '${_digits.length} / $kSerialDigits',
                          style: AppText.mono(
                            size: 12,
                            weight: FontWeight.w600,
                            color: complete
                                ? AppColors.greenDeep
                                : AppColors.ink500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _SerialDisplay(
                      digits: _digits,
                      accent: widget.accent,
                      onBackspace: _backspace,
                    ),

                    // One feedback block, directly under the field.
                    const SizedBox(height: 12),
                    _Feedback(
                      prefix: widget.prefix,
                      bottlesPerCase: widget.bottlesPerCase,
                      ends: _ends,
                      labels: _labels,
                      backwards: _backwards,
                      wholeCases: _wholeCases,
                      typed: _recorded != null,
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  4,
                  AppSpace.gutter,
                  0,
                ),
                child: _Keypad(
                  keyHeight: keyHeight,
                  onDigit: _press,
                  onClear: _clear,
                  onBackspace: _backspace,
                ),
              ),
            ],
          );
        },
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accent,
                  ),
                  child: const Text('Use this serial'),
                ),
                const SizedBox(height: 9),
                Text(
                  'Typed serials are flagged for a supervisor to check',
                  textAlign: TextAlign.center,
                  style: AppText.micro,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The digits as they will be recorded: the zeros the app fills in are shown
/// dimmed, so the full ten-digit serial is visible while it is being typed.
class _SerialDisplay extends StatelessWidget {
  const _SerialDisplay({
    required this.digits,
    required this.accent,
    required this.onBackspace,
  });

  final String digits;
  final Color accent;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final padding = '0' * (kSerialDigits - digits.length);
    final style = AppText.mono(
      size: 27,
      weight: FontWeight.w600,
      letterSpacing: 1.6,
    );

    return Semantics(
      label: digits.isEmpty ? 'No digits entered' : 'Serial $padding$digits',
      child: Container(
        height: 64,
        padding: const EdgeInsets.only(left: 16, right: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(
            color: digits.isEmpty ? AppColors.line : accent,
            width: digits.isEmpty ? 1 : 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: padding,
                      style: style.copyWith(color: AppColors.ink400),
                    ),
                    TextSpan(text: digits, style: style),
                  ],
                ),
                maxLines: 1,
              ),
            ),
            IconButton(
              onPressed: digits.isEmpty ? null : onBackspace,
              tooltip: 'Delete last digit',
              icon: const Icon(Icons.backspace_outlined, size: 21),
              color: AppColors.ink500,
            ),
          ],
        ),
      ),
    );
  }
}

/// One block under the field: the hint before anything is typed, then the
/// range and its counts, or the reason the range cannot be recorded.
class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.prefix,
    required this.bottlesPerCase,
    required this.ends,
    required this.labels,
    required this.backwards,
    required this.wholeCases,
    required this.typed,
  });

  final String prefix;
  final int bottlesPerCase;
  final (int, int)? ends;
  final int? labels;
  final bool backwards;
  final bool? wholeCases;
  final bool typed;

  @override
  Widget build(BuildContext context) {
    if (backwards) {
      return const NoticeBanner(
        title: 'The ends are the wrong way round',
        message:
            'This serial sits before the other end of the range. Check '
            'the digits against the label.',
      );
    }

    if (wholeCases == false) {
      final labels = this.labels!;
      return NoticeBanner(
        title: 'Not a whole number of cases',
        message:
            '${labels % bottlesPerCase} labels over '
            '${formatQty(labels ~/ bottlesPerCase)}. Check the serial — this '
            'range cannot be recorded.',
      );
    }

    final ends = this.ends;
    final labels = this.labels;
    if (ends == null || labels == null) {
      return Text(
        typed
            ? 'Recorded as shown above, digit for digit.'
            : 'Type only the digits. Leading zeros are filled in for you.',
        style: AppText.small,
      );
    }

    final cases = bottlesPerCase <= 0 ? null : labels ~/ bottlesPerCase;

    return AppCard(
      background: AppColors.blueTint,
      borderColor: AppColors.blueLine,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_rounded, size: 15, color: AppColors.green),
              const SizedBox(width: 8),
              Expanded(
                child: SerialRangeText(
                  prefix: prefix,
                  from: ends.$1,
                  to: ends.$2,
                  size: 13.5,
                  showPrefix: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Wrapped, not a plain row: a six-figure label count and its case
          // count together are wider than a phone at this size.
          Wrap(
            spacing: 18,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Figure(value: formatQty(labels), label: 'labels'),
              if (cases != null)
                _Figure(value: formatQty(cases), label: 'cases'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Digits only, big targets, and a layout that never shifts.
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.keyHeight,
    required this.onDigit,
    required this.onClear,
    required this.onBackspace,
  });

  final double keyHeight;
  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> keys) => Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) const SizedBox(width: 9),
            Expanded(child: keys[i]),
          ],
        ],
      ),
    );

    Widget digit(String d) => _Key(
      height: keyHeight,
      onPressed: () => onDigit(d),
      child: Text(d, style: AppText.mono(size: 23, weight: FontWeight.w600)),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([digit('1'), digit('2'), digit('3')]),
        row([digit('4'), digit('5'), digit('6')]),
        row([digit('7'), digit('8'), digit('9')]),
        row([
          _Key(
            height: keyHeight,
            tinted: true,
            onPressed: onClear,
            child: const Text(
              'Clear',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink700,
              ),
            ),
          ),
          digit('0'),
          _Key(
            height: keyHeight,
            tinted: true,
            onPressed: onBackspace,
            semanticLabel: 'Delete last digit',
            child: const Icon(
              Icons.backspace_outlined,
              size: 21,
              color: AppColors.ink700,
            ),
          ),
        ]),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.height,
    required this.child,
    required this.onPressed,
    this.tinted = false,
    this.semanticLabel,
  });

  final double height;
  final Widget child;
  final VoidCallback onPressed;
  final bool tinted;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        height: height,
        child: Material(
          color: tinted ? AppColors.sunken : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            side: tinted
                ? BorderSide.none
                : const BorderSide(color: AppColors.line),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: Center(child: child),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value, style: AppText.figure(size: 21)),
        const SizedBox(width: 5),
        Text(label, style: AppText.small),
      ],
    );
  }
}
