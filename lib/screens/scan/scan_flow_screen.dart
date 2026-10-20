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

  @override
  Widget build(BuildContext context) {
    final accent = _target.module.accent;
    final ready = _draft.isComplete && !_draft.isBackwards;

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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                '$_stepsDone of $_stepCount',
                style: AppText.mono(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: AppColors.ink500,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(5),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              0,
              AppSpace.gutter,
              0,
            ),
            child: Row(
              children: [
                for (var i = 0; i < _stepCount; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: i < _stepsDone ? AppColors.green : AppColors.line,
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

          _PrefixStep(
            draft: _draft,
            editing: _editingPrefix,
            field: _prefixField,
            accent: accent,
            onChanged: _setPrefix,
            onEdit: () => setState(() => _editingPrefix = true),
          ),

          const SizedBox(height: AppSpace.md),
          _SerialStep(
            index: 2,
            title: _draft.rangeFromSingleQr
                ? 'Range scanned'
                : 'First label of the run',
            hint: 'The lowest serial — the first case off the line.',
            serial: _draft.hasFrom ? _draft.from : null,
            prefix: _draft.prefix,
            typedByHand: _draft.fromTypedByHand,
            capturedAt: _draft.capturedFromAt,
            accent: accent,
            active: _draft.hasPrefix && !_draft.hasFrom,
            enabled: _draft.hasPrefix,
            onScan: () => _scan(isFrom: true),
            onType: () => _typeSerial(isFrom: true),
          ),

          if (!_draft.rangeFromSingleQr) ...[
            const SizedBox(height: AppSpace.md),
            _SerialStep(
              index: 3,
              title: 'Last label of the run',
              hint: 'The highest serial — the last case off the line.',
              serial: _draft.hasTo ? _draft.to : null,
              prefix: _draft.prefix,
              typedByHand: _draft.toTypedByHand,
              capturedAt: _draft.capturedToAt,
              accent: accent,
              active: _draft.hasFrom && !_draft.hasTo,
              enabled: _draft.hasPrefix,
              onScan: () => _scan(isFrom: false),
              onType: () => _typeSerial(isFrom: false),
            ),
          ],

          if (_draft.rangeFromSingleQr) ...[
            const SizedBox(height: AppSpace.md),
            NoticeBanner(
              level: NoticeLevel.info,
              title: 'One code covered the whole range',
              message: 'That label carried both ends, so there is no second '
                  'scan. Scan the first label again to enter the ends '
                  'separately.',
            ),
          ],

          const SizedBox(height: AppSpace.lg),
          _RunningTotal(target: _target, draft: _draft),
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
                  onPressed: ready ? _continue : null,
                  style: ElevatedButton.styleFrom(backgroundColor: accent),
                  child: const Text('Continue to summary'),
                ),
                if (!ready) ...[
                  const SizedBox(height: 9),
                  Text(
                    _blockingReason(),
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

  String _blockingReason() {
    if (!_draft.hasPrefix) return 'Enter the three-character prefix';
    if (!_draft.hasFrom) return 'Scan the first label of the run';
    if (!_draft.hasTo) return 'Scan the last label of the run';
    if (_draft.isBackwards) {
      return 'The last serial is lower than the first — rescan one of them';
    }
    return 'Nothing is sent until you confirm the summary';
  }
}

class _PrefixStep extends StatelessWidget {
  const _PrefixStep({
    required this.draft,
    required this.editing,
    required this.field,
    required this.accent,
    required this.onChanged,
    required this.onEdit,
  });

  final ScanDraft draft;
  final bool editing;
  final TextEditingController field;
  final Color accent;
  final ValueChanged<String> onChanged;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    if (!editing && draft.hasPrefix) {
      return AppCard(
        child: Row(
          children: [
            const _StepTick(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Serial prefix', style: AppText.small),
                  const SizedBox(height: 1),
                  Text(
                    draft.prefix,
                    style: AppText.mono(
                      size: 16,
                      weight: FontWeight.w600,
                      letterSpacing: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Change'),
            ),
          ],
        ),
      );
    }

    return AppCard(
      borderColor: accent,
      borderWidth: 2,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StepNumber(number: 1, accent: accent),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Serial prefix', style: AppText.cardTitle),
                    SizedBox(height: 2),
                    Text(
                      'The three characters printed before the digits',
                      style: AppText.small,
                    ),
                  ],
                ),
              ),
            ],
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
            style: AppText.mono(size: 26, weight: FontWeight.w600, letterSpacing: 7),
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

class _SerialStep extends StatelessWidget {
  const _SerialStep({
    required this.index,
    required this.title,
    required this.hint,
    required this.serial,
    required this.prefix,
    required this.typedByHand,
    required this.capturedAt,
    required this.accent,
    required this.active,
    required this.enabled,
    required this.onScan,
    required this.onType,
  });

  final int index;
  final String title;
  final String hint;
  final int? serial;
  final String prefix;
  final bool typedByHand;
  final DateTime? capturedAt;
  final Color accent;
  final bool active;
  final bool enabled;
  final VoidCallback onScan;
  final VoidCallback onType;

  @override
  Widget build(BuildContext context) {
    // Captured: show the value, keep it changeable.
    if (serial != null) {
      return AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: _StepTick(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.small),
                  const SizedBox(height: 2),
                  SerialValue(serial: serial!, size: 17),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        typedByHand ? 'Typed by hand' : 'Scanned',
                        style: AppText.micro,
                      ),
                      if (capturedAt != null)
                        Text(
                          ' · ${formatClock(capturedAt!)}',
                          style: AppText.micro,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onScan,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Rescan'),
            ),
          ],
        ),
      );
    }

    // The live step carries the action.
    return AppCard(
      borderColor: active ? accent : AppColors.line,
      borderWidth: active ? 2 : 1,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StepNumber(
                number: index,
                accent: active ? accent : AppColors.ink400,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.cardTitle),
                    const SizedBox(height: 2),
                    Text(hint, style: AppText.small),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          ElevatedButton.icon(
            onPressed: enabled ? onScan : null,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
            label: const Text('Open scanner'),
            style: ElevatedButton.styleFrom(backgroundColor: accent),
          ),
          const SizedBox(height: 9),
          OutlinedButton(
            onPressed: enabled ? onType : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              textStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Type the serial instead'),
          ),
        ],
      ),
    );
  }
}

class _StepNumber extends StatelessWidget {
  const _StepNumber({required this.number, required this.accent});

  final int number;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: accent, borderRadius: AppRadius.brPill),
      child: Text(
        '$number',
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _StepTick extends StatelessWidget {
  const _StepTick();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.greenTint,
        borderRadius: AppRadius.brPill,
      ),
      child: const Icon(Icons.check_rounded, size: 15, color: AppColors.green),
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
            Text(
              'That is not a whole number of cases — '
              '${labels % target.bottlesPerCase} labels over '
              '${formatQty(cases)}. Check both ends before submitting.',
              style: AppText.small,
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
