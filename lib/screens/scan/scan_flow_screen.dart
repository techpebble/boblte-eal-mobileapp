import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:eal_scanner/screens/scan/manual_serial_screen.dart';
import 'package:eal_scanner/screens/scan/scan_review_screen.dart';
import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/screens/scan/scanner_camera.dart';
import 'package:eal_scanner/services/settingsService.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

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
  late ScanDraft _draft = ScanDraft(
    prefix: _initialPrefix,
  );

  late final TextEditingController _prefixField =
      TextEditingController(text: _initialPrefix);

  late bool _editingPrefix = !_draft.hasPrefix;
  String _error = '';

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
        () => _error = 'That is not an EAL label code. Check you are scanning '
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

  Future<void> _continue() async {
    final result = await Navigator.push<ScanReviewResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ScanReviewScreen(target: _target, draft: _draft),
      ),
    );

    if (!mounted || result == null) return;

    switch (result) {
      case ScanReviewResult.done:
        Navigator.pop(context, true);
      case ScanReviewResult.another:
        // Keep the prefix — the next run almost always shares it.
        setState(() {
          _draft = ScanDraft(prefix: _draft.prefix);
          _editingPrefix = false;
          _error = '';
        });
      case ScanReviewResult.cancelled:
        break;
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
    // A part case is refused outright: the quantity would be wrong and
    // the remainder silently dropped.
    final ready = complete &&
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
              label: 'Step ${_stepsDone + (complete ? 0 : 1)} '
                  'of $_stepCount',
              child: Row(
                children: [
                  for (var i = 0; i < _stepCount; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color:
                              i < _stepsDone ? AppColors.green : AppColors.line,
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
                const Expanded(
                  child: Text('RANGE SO FAR', style: AppText.section),
                ),
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
              onEditFrom: () => _scan(isFrom: true),
              onEditTo: _draft.rangeFromSingleQr
                  ? null
                  : () => _scan(isFrom: false),
            ),
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

          if (complete) ...[
            const SizedBox(height: AppSpace.lg),
            _RunningTotal(target: _target, draft: _draft),
          ],

          if (_draft.rangeFromSingleQr) ...[
            const SizedBox(height: AppSpace.lg),
            NoticeBanner(
              level: NoticeLevel.info,
              title: 'One code covered the whole range',
              message: 'That label carried both ends, so there is no second '
                  'scan. Scan the first label again to enter the ends '
                  'separately.',
            ),
          ] else if (_target.allowRangeQr && !complete && !_needsPrefix) ...[
            const SizedBox(height: 20),
            NoticeBanner(
              level: NoticeLevel.info,
              message: 'Some issuance codes carry both ends at once. If this '
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
                        onPressed: ready ? _continue : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: const Text('Continue to summary'),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _blockingReason(),
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
                          textStyle: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                          ),
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
    return 'Nothing is sent until you confirm the summary';
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
  });

  final ScanDraft draft;
  final Color accent;
  final VoidCallback onEditFrom;
  final VoidCallback? onEditTo;

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

/// What the range will mean, before it is committed.
class _RunningTotal extends StatelessWidget {
  const _RunningTotal({required this.target, required this.draft});

  final ScanTarget target;
  final ScanDraft draft;

  @override
  Widget build(BuildContext context) {
    final labels = draft.labels;
    final cases = draft.casesFor(target.bottlesPerCase);
    final leads = target.unit == ScanUnit.cases;

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: const BoxDecoration(
        color: AppColors.sunken,
        borderRadius: AppRadius.brTile,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RUNNING TOTAL', style: AppText.section),
          const SizedBox(height: 7),
          if (labels == 0)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('—', style: AppText.figure(size: 24, color: AppColors.ink500)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'once both ends are captured',
                    style: AppText.small,
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatQty(leads ? cases : labels),
                  style: AppText.figure(size: 24),
                ),
                const SizedBox(width: 7),
                Text(leads ? 'cases' : 'labels', style: AppText.small),
                const Spacer(),
                Text(
                  leads
                      ? '${formatQty(labels)} labels'
                      : '${formatQty(cases)} cases',
                  style: AppText.mono(size: 12.5, color: AppColors.ink500),
                ),
              ],
            ),

          if (draft.isPartialCase(target.bottlesPerCase) && labels > 0) ...[
            const SizedBox(height: AppSpace.md),
            NoticeBanner(
              title: 'Not a whole number of cases',
              message:
                  '${draft.remainderFor(target.bottlesPerCase)} labels over '
                  '${formatQty(cases)}. This range cannot be recorded — one '
                  'of the two ends names the wrong label.',
            ),
          ],

          if (target.hasTargetQuantity) ...[
            const SizedBox(height: AppSpace.md),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'This line needs ${formatCases(target.requiredCases!)}',
                    style: AppText.small,
                  ),
                  if ((target.alreadyLinkedCases ?? 0) > 0)
                    TextSpan(
                      text: '. ${formatQty(target.alreadyLinkedCases!)} '
                          'already linked.',
                      style: AppText.small,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
