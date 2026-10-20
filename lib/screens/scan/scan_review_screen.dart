import 'package:flutter/material.dart';

import 'package:eal_scanner/screens/scan/scan_success_screen.dart';
import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// The last look before anything is sent.
///
/// States what the range is, what it attaches to, and what it does to the
/// line's balance. A rejection from the server is shown here with the
/// server's own wording — overlapping ranges and over-linking both come back
/// with specific messages worth reading.
class ScanReviewScreen extends StatefulWidget {
  const ScanReviewScreen({
    super.key,
    required this.target,
    required this.draft,
  });

  final ScanTarget target;
  final ScanDraft draft;

  @override
  State<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends State<ScanReviewScreen> {
  bool _sending = false;
  String _error = '';

  ScanTarget get _target => widget.target;
  ScanDraft get _draft => widget.draft;

  int get _labels => _draft.labels;
  int get _cases => _draft.casesFor(_target.bottlesPerCase);

  /// The flow screen already refuses a part case; this is the second
  /// gate, so the figure can never be sent rounded.
  bool get _wholeCases => _draft.hasWholeCases(_target.bottlesPerCase);

  /// Where the line stands once this range is added.
  ({int after, int outstanding, bool completes, bool exceeds})? get _lineEffect {
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

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = '';
    });

    final error = await _target.submit(_draft);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _sending = false;
        _error = error;
      });
      return;
    }

    final result = await Navigator.pushReplacement<ScanReviewResult, void>(
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
    Navigator.pop(context, result ?? ScanReviewResult.done);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _target.module.accent;
    final leads = _target.unit == ScanUnit.cases;
    final effect = _lineEffect;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        shape: const Border(
          bottom: BorderSide(color: AppColors.line, width: 1),
        ),
        title: const Text('Check before sending', style: AppText.appBarTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: Container(
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.green,
                borderRadius: AppRadius.brPill,
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
              title: 'The server would not accept this',
              message: _error,
            ),
            const SizedBox(height: AppSpace.lg),
          ],

          // The range, as the headline fact.
          AppCard(
            radius: AppRadius.card,
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('RANGE TO RECORD', style: AppText.section),
                    ),
                    if (_draft.typedByHand)
                      const Pill(
                        label: 'by hand',
                        background: AppColors.cautionTint,
                        foreground: AppColors.cautionDeep,
                        fontSize: 11,
                        dense: true,
                      ),
                  ],
                ),
                const SizedBox(height: 13),
                _EndRow(
                  label: 'From',
                  prefix: _draft.prefix,
                  serial: _draft.from,
                ),
                const SizedBox(height: 8),
                _EndRow(
                  label: 'To',
                  prefix: _draft.prefix,
                  serial: _draft.to,
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpace.lg),
                  child: Divider(),
                ),

                Row(
                  children: [
                    Expanded(
                      child: FigureTile(
                        value: formatQty(leads ? _cases : _labels),
                        label: leads ? 'cases' : 'labels',
                        size: 22,
                      ),
                    ),
                    Expanded(
                      child: FigureTile(
                        value: formatQty(leads ? _labels : _cases),
                        label: leads
                            ? 'labels'
                            : 'cases · ${_target.bottlesPerCase} per case',
                        size: 22,
                        color: AppColors.ink700,
                      ),
                    ),
                  ],
                ),

                if (_draft.isPartialCase(_target.bottlesPerCase)) ...[
                  const SizedBox(height: AppSpace.lg),
                  NoticeBanner(
                    title: 'Not a whole number of cases',
                    message:
                        '${_draft.remainderFor(_target.bottlesPerCase)} labels '
                        'more than ${formatCases(_cases)}. This cannot be '
                        'recorded — go back and scan both ends again.',
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpace.md),

          // What it attaches to.
          AppCard(
            radius: AppRadius.card,
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RECORDING AGAINST', style: AppText.section),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _target.module.tint,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        switch (_target.module) {
                          AppModule.issuance =>
                            Icons.assignment_turned_in_outlined,
                          AppModule.production => Icons.factory_outlined,
                          AppModule.dispatch => Icons.local_shipping_outlined,
                          AppModule.neutral => Icons.qr_code_2_rounded,
                        },
                        size: 18,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        _target.contextLine,
                        style: AppText.label,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (effect != null) ...[
            const SizedBox(height: AppSpace.md),
            _LineEffectCard(
              required_: _target.requiredCases!,
              already: _target.alreadyLinkedCases ?? 0,
              adding: _cases,
              effect: effect,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: (_sending || !_wholeCases) ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: accent),
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
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
                  _wholeCases
                      ? 'Saved to the server straight away'
                      : 'Cannot be sent until the range makes whole cases',
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
}

class _EndRow extends StatelessWidget {
  const _EndRow({
    required this.label,
    required this.prefix,
    required this.serial,
  });

  final String label;
  final String prefix;
  final int serial;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 38,
          child: Text(label, style: AppText.micro),
        ),
        Expanded(
          child: SerialValue(serial: serial, prefix: prefix, size: 18),
        ),
      ],
    );
  }
}

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
        message: 'The line is for ${formatCases(required_)} and '
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
      message: '${formatCases(effect.outstanding)} left after this one. '
          'The dispatch cannot move to Loaded until every line is covered.',
    );
  }
}
