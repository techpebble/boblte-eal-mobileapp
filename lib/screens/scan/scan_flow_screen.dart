import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:eal_scanner/screens/scan/manual_serial_screen.dart';
import 'package:eal_scanner/screens/scan/scan_success_screen.dart';
import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/screens/scan/scanner_camera.dart';
import 'package:eal_scanner/services/settingsService.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// The footer's two buttons share this, so the style never changes under
/// the button when the footer swaps one for the other.
const _primaryActionText = TextStyle(
  fontSize: 16.5,
  fontWeight: FontWeight.w600,
);

/// The one scan wizard, serving all three modules.
///
/// Replaces three near-identical copies of `EALScanScreen`. Every step stays
/// editable after the fact, the running figures are shown before anything is
/// sent, and a step can be completed by typing when a label will not read.
/// Pops `true` once a range has been recorded.
class ScanFlowScreen extends StatefulWidget {
  const ScanFlowScreen({super.key, required this.target});

  final ScanTarget target;

  @override
  State<ScanFlowScreen> createState() => _ScanFlowScreenState();
}

class _ScanFlowScreenState extends State<ScanFlowScreen> {
  late ScanDraft _draft = ScanDraft(prefix: _initialPrefix);

  late final TextEditingController _prefixField = TextEditingController(
    text: _initialPrefix,
  );

  late bool _editingPrefix = !_draft.hasPrefix;
  String _error = '';

  /// A rejection from the server, kept apart from a misread code: the two
  /// need different wording and the server's own message is worth reading.
  String _serverError = '';
  bool _sending = false;

  ScanTarget get _target => widget.target;

  String get _initialPrefix {
    final given = widget.target.initialPrefix.trim().toUpperCase();
    if (given.length == 3) return given;

    final saved = SettingsService.defaultPrefix;
    return saved.length == 3 ? saved : given;
  }

  /// A range carried by one QR code collapses the two scan steps into one.
  int get _stepCount => _draft.rangeFromSingleQr ? 2 : 3;

  int get _stepsDone {
    var done = 0;
    if (_draft.hasPrefix) done++;
    if (_draft.hasFrom) done++;
    if (_draft.rangeFromSingleQr) return done;
    if (_draft.hasTo) done++;
    return done;
  }

  @override
  void dispose() {
    _prefixField.dispose();
    super.dispose();
  }

  void _setPrefix(String value) {
    final upper = value.trim().toUpperCase();
    setState(() {
      _draft = _draft.copyWith(prefix: upper);
      _error = '';
      if (upper.length == 3) {
        _editingPrefix = false;
        FocusScope.of(context).unfocus();
      }
    });
  }

  Future<void> _scan({required bool isFrom}) async {
    if (!_draft.hasPrefix) {
      setState(() => _error = 'Enter the three-character prefix first.');
      return;
    }

    final outcome = await Navigator.push<ScannerOutcome>(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerCamera(
          stepLabel: isFrom ? 'Scan the first label' : 'Scan the last label',
          instruction: isFrom
              ? 'The lowest serial of the run — the first case off the line.'
              : 'The highest serial of the run — the last case off the line.',
          stepIndex: isFrom ? 2 : 3,
          stepCount: _stepCount,
          accent: _target.module.accent,
          capturedPrefix: !isFrom && _draft.hasFrom ? _draft.prefix : null,
          capturedSerial: !isFrom && _draft.hasFrom ? _draft.from : null,
        ),
      ),
    );

    if (!mounted || outcome == null) return;

    switch (outcome) {
      case ScannerCaptured(:final capture):
        _applyCapture(capture, isFrom: isFrom);
      case ScannerAskedToType():
        await _typeSerial(isFrom: isFrom);
    }
  }

  Future<void> _typeSerial({required bool isFrom}) async {
    if (!_draft.hasPrefix) {
      setState(() => _error = 'Enter the three-character prefix first.');
      return;
    }

    final counterpart = isFrom ? _draft.serialTo : _draft.serialFrom;

    final recorded = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ManualSerialScreen(
          prefix: _draft.prefix,
          bottlesPerCase: _target.bottlesPerCase,
          isFrom: isFrom,
          counterpartSerial: counterpart.isEmpty ? null : counterpart,
          stepIndex: isFrom ? 2 : 3,
          stepCount: _stepCount,
          accent: _target.module.accent,
        ),
      ),
    );

    if (!mounted || recorded == null) return;

    setState(() {
      _error = '';
      if (isFrom) {
        _draft = _draft.copyWith(
          serialFrom: recorded,
          rawFrom: null,
          fromTypedByHand: true,
          rangeFromSingleQr: false,
          capturedFromAt: DateTime.now(),
        );
      } else {
        _draft = _draft.copyWith(
          serialTo: recorded,
          rawTo: null,
          toTypedByHand: true,
          capturedToAt: DateTime.now(),
        );
      }
    });
  }

  /// Reads a captured code. The two payload formats and the case arithmetic
  /// are exactly as the old screens handled them.
  void _applyCapture(BarcodeCapture capture, {required bool isFrom}) {
    if (capture.barcodes.isEmpty) return;

    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) {
      setState(() => _error = 'That code carried no data. Try again.');
      return;
    }

    // Some issuance labels carry the whole range in one code.
    if (_target.allowRangeQr && EalQrCodec.looksLikeRange(raw)) {
      final range = EalQrCodec.readRange(raw);
      if (range == null) {
        setState(() => _error = 'Could not read the range from that code.');
        return;
      }

      setState(() {
        _error = '';
        _draft = _draft.copyWith(
          serialFrom: range.from,
          serialTo: range.to,
          rawFrom: raw,
          rawTo: raw,
          fromTypedByHand: false,
          toTypedByHand: false,
          rangeFromSingleQr: true,
          capturedFromAt: DateTime.now(),
          capturedToAt: DateTime.now(),
        );
      });
      return;
    }

    final scanned = EalQrCodec.readSingle(raw);
    if (scanned == null) {
      setState(
        () => _error =
            'That is not an EAL label code. Check you are scanning '
            'the excise label and not the carton barcode.',
      );
      return;
    }

    setState(() {
      _error = '';

      // Moving from a whole-range code back to single labels: the other end
      // no longer belongs to this scan.
      final wasRange = _draft.rangeFromSingleQr;

      if (isFrom) {
        _draft = _draft.copyWith(
          serialFrom: EalQrCodec.firstSerialOfCase(
            scanned,
            _target.bottlesPerCase,
          ),
          serialTo: wasRange ? '' : _draft.serialTo,
          rawFrom: raw,
          fromTypedByHand: false,
          rangeFromSingleQr: false,
          capturedFromAt: DateTime.now(),
        );
      } else {
        _draft = _draft.copyWith(
          serialTo: EalQrCodec.pad(scanned),
          serialFrom: wasRange ? '' : _draft.serialFrom,
          rawTo: raw,
          toTypedByHand: false,
          rangeFromSingleQr: false,
          capturedToAt: DateTime.now(),
        );
      }
    });
  }

  int get _labels => _draft.labels;
  int get _cases => _draft.casesFor(_target.bottlesPerCase);

  /// Where a dispatch line stands once this range is added.
  ({int after, int outstanding, bool completes, bool exceeds})?
  get _lineEffect {
    if (!_target.hasTargetQuantity) return null;

    final required = _target.requiredCases!;
    final already = _target.alreadyLinkedCases ?? 0;
    final after = already + _cases;

    return (
      after: after,
      outstanding: required - after,
      completes: after == required,
      exceeds: after > required,
    );
  }

  /// Sends the range. The screen shows everything that was on the separate
  /// review step, so the button itself is the confirmation.
  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _serverError = '';
    });

    final error = await _target.submit(_draft);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _sending = false;
        _serverError = error;
      });
      return;
    }

    final outcome = await Navigator.push<ScanOutcome>(
      context,
      MaterialPageRoute(
        builder: (_) => ScanSuccessScreen(
          target: _target,
          draft: _draft,
          labels: _labels,
          cases: _cases,
          lineAfter: _lineEffect?.after,
        ),
      ),
    );

    if (!mounted) return;

    // Backing out of a confirmation means finished, not undo.
    switch (outcome ?? ScanOutcome.done) {
      case ScanOutcome.done:
        Navigator.pop(context, true);
      case ScanOutcome.another:
        // Keep the prefix — the next run almost always shares it.
        setState(() {
          _draft = ScanDraft(prefix: _draft.prefix);
          _editingPrefix = false;
          _sending = false;
          _error = '';
          _serverError = '';
        });
    }
  }

  /// The prefix is the first step, so it owns the screen until it is set.
  bool get _needsPrefix => !_draft.hasPrefix;

  /// Which end the next scan is for. The first end until it is captured.
  bool get _onFirstEnd => !_draft.hasFrom;

  @override
  Widget build(BuildContext context) {
    final accent = _target.module.accent;
    final complete = _draft.isComplete;
    final leads = _target.unit == ScanUnit.cases;
    final effect = complete ? _lineEffect : null;
    // A part case is refused outright: the quantity would be wrong and
    // the remainder silently dropped.
    final ready =
        complete &&
        !_draft.isBackwards &&
        _draft.hasWholeCases(_target.bottlesPerCase);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        shape: const Border(
          bottom: BorderSide(color: AppColors.line, width: 1),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_target.title, style: AppText.appBarTitle),
            Text(
              _target.contextLine,
              style: const TextStyle(fontSize: 11.5, color: AppColors.ink500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        // One progress indicator, not a rail and a counter saying the same
        // thing. The step is named in the body where the work is.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: Semantics(
              label:
                  'Step ${_stepsDone + (complete ? 0 : 1)} '
                  'of $_stepCount',
              child: Row(
                children: [
                  for (var i = 0; i < _stepCount; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: i < _stepsDone
                              ? AppColors.green
                              : AppColors.line,
                          borderRadius: AppRadius.brPill,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
          if (_error.isNotEmpty) ...[
            NoticeBanner(
              level: NoticeLevel.error,
              title: 'That did not read',
              message: _error,
              trailing: IconButton(
                onPressed: () => setState(() => _error = ''),
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Dismiss',
              ),
            ),
            const SizedBox(height: AppSpace.md),
          ],

          if (_serverError.isNotEmpty) ...[
            NoticeBanner(
              level: NoticeLevel.error,
              title: 'The server would not accept this',
              message: _serverError,
            ),
            const SizedBox(height: AppSpace.md),
          ],

          if (_editingPrefix || _needsPrefix)
            _PrefixEditor(
              field: _prefixField,
              accent: accent,
              onChanged: _setPrefix,
            )
          else ...[
            // What is captured, read as one building range rather than a
            // column of finished step cards.
            Row(
              children: [
                Expanded(
                  child: Text(
                    complete ? 'RANGE TO RECORD' : 'RANGE SO FAR',
                    style: AppText.section,
                  ),
                ),
                if (complete && _draft.typedByHand) ...[
                  const Pill(
                    label: 'by hand',
                    background: AppColors.cautionTint,
                    foreground: AppColors.cautionDeep,
                    fontSize: 11,
                    dense: true,
                  ),
                  const SizedBox(width: 8),
                ],
                _PrefixChipButton(
                  prefix: _draft.prefix,
                  onPressed: () => setState(() => _editingPrefix = true),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _RangeCard(
              draft: _draft,
              accent: accent,
              // No edits while it is being sent.
              onEditFrom: _sending ? null : () => _scan(isFrom: true),
              onEditTo: _sending || _draft.rangeFromSingleQr
                  ? null
                  : () => _scan(isFrom: false),
              // Once both ends are in, the card also says what the range
              // comes to — this was the whole of the old review screen.
              // Unless the count is being checked against paper, in which
              // case it gets a card of its own below.
              summary: complete && !_target.verifiesCount
                  ? _SummaryFigures(
                      labels: _labels,
                      cases: _cases,
                      leads: leads,
                      bottlesPerCase: _target.bottlesPerCase,
                      partialBy: _draft.isPartialCase(_target.bottlesPerCase)
                          ? _draft.remainderFor(_target.bottlesPerCase)
                          : null,
                    )
                  : null,
            ),

            if (complete && _target.verifiesCount) ...[
              const SizedBox(height: 14),
              _VerifyCard(
                subject: _target.subjectName!,
                market: _target.subjectMarket,
                cases: _cases,
                labels: _labels,
                bottlesPerCase: _target.bottlesPerCase,
                accent: accent,
              ),
              if (_draft.isPartialCase(_target.bottlesPerCase)) ...[
                const SizedBox(height: AppSpace.lg),
                NoticeBanner(
                  title: 'Not a whole number of cases',
                  message:
                      '${_draft.remainderFor(_target.bottlesPerCase)} labels '
                      'more than ${formatCases(_cases)}. This cannot be '
                      'recorded — one of the two ends above names the wrong '
                      'label.',
                ),
              ],
            ],
          ],

          if (!complete && _target.hasTargetQuantity) ...[
            const SizedBox(height: 10),
            Text(_targetLine(), style: AppText.small),
          ],

          // The one thing to do now, or what the finished range comes to.
          if (!complete && !_needsPrefix && !_editingPrefix) ...[
            const SizedBox(height: 24),
            _StepBlock(
              step: 'STEP ${_stepsDone + 1} OF $_stepCount',
              title: _onFirstEnd
                  ? 'Scan the first label'
                  : 'Scan the last label',
              hint: _onFirstEnd
                  ? 'The lowest serial of the run — the first case off the '
                        'line. Hold the code inside the frame and it reads on '
                        'its own.'
                  : 'The highest serial of the run — the last case off the '
                        'line. Hold the code inside the frame and it reads on '
                        'its own.',
              accent: accent,
            ),
          ],

          if (effect != null) ...[
            const SizedBox(height: AppSpace.md),
            _LineEffectCard(
              required_: _target.requiredCases!,
              already: _target.alreadyLinkedCases ?? 0,
              adding: _cases,
              effect: effect,
            ),
          ],

          if (_draft.rangeFromSingleQr) ...[
            const SizedBox(height: AppSpace.lg),
            NoticeBanner(
              level: NoticeLevel.info,
              title: 'One code covered the whole range',
              message:
                  'That label carried both ends, so there is no second '
                  'scan. Scan the first label again to enter the ends '
                  'separately.',
            ),
          ] else if (_target.allowRangeQr && !complete && !_needsPrefix) ...[
            const SizedBox(height: 20),
            NoticeBanner(
              level: NoticeLevel.info,
              message:
                  'Some issuance codes carry both ends at once. If this '
                  'one does, the range fills in and you are done after this '
                  'scan.',
            ),
          ],
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
            // One action at a time: the step's action while scanning, then
            // Continue once both ends are in.
            child: complete
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: (ready && !_sending) ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          minimumSize: const Size.fromHeight(56),
                          textStyle: _primaryActionText,
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                leads
                                    ? 'Record ${formatCases(_cases)}'
                                    : 'Record ${formatLabels(_labels)}',
                              ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        ready
                            ? 'Saved to the server straight away'
                            : _blockingReason(),
                        textAlign: TextAlign.center,
                        style: AppText.small,
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _needsPrefix
                            ? null
                            : () => _scan(isFrom: _onFirstEnd),
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 21,
                        ),
                        label: const Text('Open scanner'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          minimumSize: const Size.fromHeight(56),
                          textStyle: _primaryActionText,
                        ),
                      ),
                      // The fallback stays reachable but stops competing
                      // with the scanner.
                      SizedBox(
                        height: AppSpace.touch,
                        child: TextButton(
                          onPressed: _needsPrefix
                              ? null
                              : () => _typeSerial(isFrom: _onFirstEnd),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.ink500,
                            textStyle: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Label damaged? Type it by hand'),
                        ),
                      ),
                      if (_needsPrefix)
                        Text(
                          'Enter the three-character prefix first',
                          textAlign: TextAlign.center,
                          style: AppText.small,
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _targetLine() {
    final needs = 'This line needs ${formatCases(_target.requiredCases!)}';
    final linked = _target.alreadyLinkedCases ?? 0;
    if (linked == 0) return '$needs.';
    return '$needs. ${formatQty(linked)} already linked.';
  }

  String _blockingReason() {
    if (!_draft.hasPrefix) return 'Enter the three-character prefix';
    if (!_draft.hasFrom) return 'Scan the first label of the run';
    if (!_draft.hasTo) return 'Scan the last label of the run';
    if (_draft.isBackwards) {
      return 'The last serial is lower than the first — rescan one of them';
    }
    if (!_draft.hasWholeCases(_target.bottlesPerCase)) {
      final over = _draft.remainderFor(_target.bottlesPerCase);
      return '$over label${over == 1 ? '' : 's'} over a whole case — '
          'one of the two ends is wrong';
    }
    return 'Saved to the server straight away';
  }
}

/// The prefix, set once and then kept out of the way.
class _PrefixEditor extends StatelessWidget {
  const _PrefixEditor({
    required this.field,
    required this.accent,
    required this.onChanged,
  });

  final TextEditingController field;
  final Color accent;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: accent,
      borderWidth: 2,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Serial prefix', style: AppText.cardTitle),
          const SizedBox(height: 2),
          const Text(
            'The three characters printed before the digits',
            style: AppText.small,
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: field,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            inputFormatters: [
              LengthLimitingTextInputFormatter(3),
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              TextInputFormatter.withFunction(
                (_, next) => next.copyWith(text: next.text.toUpperCase()),
              ),
            ],
            style: AppText.mono(
              size: 26,
              weight: FontWeight.w600,
              letterSpacing: 7,
            ),
            onChanged: onChanged,
            decoration: const InputDecoration(
              hintText: 'ABC',
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// The set prefix, as a chip that can be tapped to change it.
class _PrefixChipButton extends StatelessWidget {
  const _PrefixChipButton({required this.prefix, required this.onPressed});

  final String prefix;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Serial prefix $prefix. Change it.',
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.brPill,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
          child: Row(
            children: [
              SerialPrefixChip(prefix),
              const SizedBox(width: 7),
              const Icon(
                Icons.edit_outlined,
                size: 15,
                color: AppColors.ink500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two ends in one card, so the range reads as a range.
class _RangeCard extends StatelessWidget {
  const _RangeCard({
    required this.draft,
    required this.accent,
    required this.onEditFrom,
    required this.onEditTo,
    this.summary,
  });

  final ScanDraft draft;
  final Color accent;
  final VoidCallback? onEditFrom;
  final VoidCallback? onEditTo;

  /// What the finished range comes to, shown inside the same card so the
  /// range and its figures read as one thing.
  final Widget? summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brTile,
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _EndRow(
            label: 'From',
            serial: draft.hasFrom ? draft.from : null,
            typedByHand: draft.fromTypedByHand,
            capturedAt: draft.capturedFromAt,
            waiting: draft.hasPrefix && !draft.hasFrom,
            accent: accent,
            onEdit: onEditFrom,
            editTooltip: 'Rescan the first label',
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
          _EndRow(
            label: 'To',
            serial: draft.hasTo ? draft.to : null,
            typedByHand: draft.toTypedByHand,
            capturedAt: draft.capturedToAt,
            waiting: draft.hasFrom && !draft.hasTo,
            accent: accent,
            onEdit: onEditTo,
            editTooltip: 'Rescan the last label',
          ),
          if (summary != null) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
              child: summary!,
            ),
          ],
        ],
      ),
    );
  }
}

class _EndRow extends StatelessWidget {
  const _EndRow({
    required this.label,
    required this.serial,
    required this.typedByHand,
    required this.capturedAt,
    required this.waiting,
    required this.accent,
    required this.onEdit,
    required this.editTooltip,
  });

  final String label;
  final int? serial;
  final bool typedByHand;
  final DateTime? capturedAt;

  /// This is the end the next scan will fill, so it is drawn as a gap being
  /// waited on rather than a blank.
  final bool waiting;

  final Color accent;
  final VoidCallback? onEdit;
  final String editTooltip;

  @override
  Widget build(BuildContext context) {
    final captured = serial != null;

    return Container(
      color: waiting ? AppColors.canvas : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: waiting ? accent : AppColors.ink500,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (captured)
                  SerialValue(serial: serial!, size: 18)
                else
                  Text(
                    '·' * kSerialDigits,
                    style: AppText.mono(
                      size: 18,
                      weight: FontWeight.w600,
                      color: AppColors.ink400,
                      letterSpacing: 4.7,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  captured
                      ? [
                          typedByHand ? 'Typed by hand' : 'Scanned',
                          if (capturedAt != null) formatClock(capturedAt!),
                        ].join(' · ')
                      : waiting
                      ? 'Waiting for this one'
                      : 'Not captured yet',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: waiting ? accent : AppColors.ink500,
                  ),
                ),
              ],
            ),
          ),
          if (captured && onEdit != null)
            IconButton(
              onPressed: onEdit,
              tooltip: editTooltip,
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.ink500,
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// The step being worked on, stated once and plainly.
class _StepBlock extends StatelessWidget {
  const _StepBlock({
    required this.step,
    required this.title,
    required this.hint,
    required this.accent,
  });

  final String step;
  final String title;
  final String hint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(step, style: AppText.section.copyWith(color: accent)),
        const SizedBox(height: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: AppColors.ink900,
          ),
        ),
        const SizedBox(height: 6),
        Text(hint, style: AppText.bodyMuted),
      ],
    );
  }
}

/// What the finished range comes to, and anything that stops it being sent.
class _SummaryFigures extends StatelessWidget {
  const _SummaryFigures({
    required this.labels,
    required this.cases,
    required this.leads,
    required this.bottlesPerCase,
    required this.partialBy,
  });

  final int labels;
  final int cases;

  /// Dispatch and production count in cases; an issuance counts in labels.
  final bool leads;

  final int bottlesPerCase;

  /// Labels over a whole case, where the range does not divide evenly.
  final int? partialBy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FigureTile(
                value: formatQty(leads ? cases : labels),
                label: leads ? 'cases' : 'labels',
                size: 22,
              ),
            ),
            Expanded(
              child: FigureTile(
                value: formatQty(leads ? labels : cases),
                label: leads ? 'labels' : 'cases · $bottlesPerCase per case',
                size: 22,
                color: AppColors.ink700,
              ),
            ),
          ],
        ),
        if (partialBy != null) ...[
          const SizedBox(height: AppSpace.lg),
          NoticeBanner(
            title: 'Not a whole number of cases',
            message:
                '$partialBy labels more than ${formatCases(cases)}. '
                'This cannot be recorded — one of the two ends above names '
                'the wrong label.',
          ),
        ],
      ],
    );
  }
}

/// The figure being checked against the day sheet, with the thing it counts
/// on the same card.
///
/// One large number and nothing else large, so there is nothing on screen to
/// mistake it for. The labels and the case size are the arithmetic behind it,
/// so they sit under it rather than beside it at the same size — which is
/// what the two equal tiles used to do.
class _VerifyCard extends StatelessWidget {
  const _VerifyCard({
    required this.subject,
    required this.market,
    required this.cases,
    required this.labels,
    required this.bottlesPerCase,
    required this.accent,
  });

  final String subject;
  final String? market;
  final int cases;
  final int labels;
  final int bottlesPerCase;
  final Color accent;

  Widget _behind(String value, String label) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12, color: AppColors.ink500),
        children: [
          TextSpan(
            text: value,
            style: AppText.mono(
              size: 12,
              weight: FontWeight.w600,
              color: AppColors.ink700,
            ),
          ),
          TextSpan(text: ' $label'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.16,
                      color: AppColors.ink900,
                    ),
                  ),
                ),
                if (market != null) ...[
                  const SizedBox(width: 9),
                  MarketChip(market!, dense: true),
                ],
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 15),
            child: Column(
              children: [
                // Scaled down rather than wrapped or cut: a day's run can
                // reach six figures, and a phone can be narrow.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatQty(cases),
                    style: AppText.figure(size: 52, color: AppColors.tealDeep),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'cases produced',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 11),
            // Its own bottom corners, and darker than the page. A square
            // child painted over the card's rounded border, which is drawn
            // behind it, so the two bottom corners went missing and the
            // bottom edge read as a line adrift under the card. Canvas here
            // was the page colour exactly, which hid the band as well.
            decoration: const BoxDecoration(
              color: AppColors.sunken,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(14.5),
              ),
              border: Border(top: BorderSide(color: AppColors.line, width: 1)),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 2,
              children: [
                _behind(formatQty(labels), 'labels'),
                const Text('·', style: TextStyle(color: AppColors.ink400)),
                _behind('$bottlesPerCase', 'per case'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Where a dispatch line stands once this range is added.
class _LineEffectCard extends StatelessWidget {
  const _LineEffectCard({
    required this.required_,
    required this.already,
    required this.adding,
    required this.effect,
  });

  final int required_;
  final int already;
  final int adding;
  final ({int after, int outstanding, bool completes, bool exceeds}) effect;

  @override
  Widget build(BuildContext context) {
    if (effect.exceeds) {
      return NoticeBanner(
        level: NoticeLevel.error,
        title: 'That is more than the line ordered',
        message:
            'The line is for ${formatCases(required_)} and '
            '${formatQty(already)} are linked. Adding ${formatQty(adding)} '
            'would overshoot by ${formatQty(-effect.outstanding)}. The server '
            'will refuse it.',
      );
    }

    if (effect.completes) {
      return AppCard(
        radius: AppRadius.card,
        background: AppColors.greenTint,
        borderColor: AppColors.greenLine,
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: AppColors.green,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This completes the line',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.greenDeep,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${formatQty(already)} cases are linked already. With '
                        'these ${formatQty(adding)}, all '
                        '${formatQty(required_)} are accounted for.',
                        style: AppText.small,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            LinkedProgressBar(
              linked: effect.after,
              required_: required_,
              height: 8,
              accent: AppColors.green,
            ),
          ],
        ),
      );
    }

    return NoticeBanner(
      title: 'The line will still be short',
      message:
          '${formatCases(effect.outstanding)} left after this one. '
          'The dispatch cannot move to Loaded until every line is covered.',
    );
  }
}
