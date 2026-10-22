import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/models/dispatch.dart';
import 'package:eal_scanner/screens/scan/scan_flow_screen.dart';
import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/services/authService.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// Reconciling one dispatch line against the labels linked to it.
///
/// The old screen signalled a mismatch with red text against green. Here the
/// three figures are named, the gap is stated in words, and the action scans
/// exactly the shortfall.
class EALDetailScreen extends StatefulWidget {
  const EALDetailScreen({
    super.key,
    required this.dispatchItemId,
    required this.dispatchId,
  });

  final String dispatchItemId;
  final String dispatchId;

  @override
  State<EALDetailScreen> createState() => _EALDetailScreenState();
}

class _EALDetailScreenState extends State<EALDetailScreen> {
  final DispatchController _controller = Get.find<DispatchController>();
  String _error = '';
  bool _busy = false;

  DispatchModel? get _dispatch =>
      _controller.dispatches.firstWhereOrNull((d) => d.id == widget.dispatchId);

  DispatchItemModel? get _item =>
      _dispatch?.items.firstWhereOrNull((i) => i.id == widget.dispatchItemId);

  /// Linking and unlinking are one permission on the server, so they are
  /// one here: a role that can do neither is offered neither.
  bool get _hasLinkPermission => AuthService.can('dispatch:link');

  /// Labels may only be changed while the note is Final — the server
  /// refuses the rest. A draft's lines can still change, so labels would be
  /// against numbers that no longer hold; once it is loaded the quantities
  /// have been checked against the lorry.
  bool get _stageAllowsLinking =>
      (_dispatch?.status ?? '').toLowerCase().trim() == 'final';

  bool get _canLink => _hasLinkPermission && _stageAllowsLinking;

  /// Why the buttons are not there, or null when they are. A control that
  /// is simply missing, or greyed with no reason, is the one people ask
  /// about.
  String? get _whyNotLinking {
    if (!_hasLinkPermission) {
      return 'Your role does not include linking labels. Ask an '
          'administrator.';
    }
    if (_stageAllowsLinking) return null;

    final stage = (_dispatch?.status ?? '').toLowerCase().trim();
    if (stage == 'draft') {
      return 'This dispatch is still a draft. Labels can be linked once it '
          'is marked Final and its lines are settled.';
    }
    return 'This dispatch has already been ${titleCase(stage)}, so its '
        'labels can no longer be changed.';
  }

  Future<void> _unlink(EALLinkModel link) async {
    final item = _item;
    if (item == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unlink this range?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'These labels go back to the production pool and this line will '
              'be short again.',
              style: AppText.bodyMuted,
            ),
            const SizedBox(height: AppSpace.md),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                borderRadius: AppRadius.brControl,
              ),
              child: SerialRangeText(
                prefix: link.prefix,
                from: link.serialFrom,
                to: link.serialTo,
                size: 13.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = '';
    });

    final error = await _controller.removeEALLink(
      dispatchId: widget.dispatchId,
      itemId: item.itemId,
      prefix: link.prefix,
      serialFrom: link.serialFrom.toString(),
      serialTo: link.serialTo.toString(),
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error ?? '';
    });
  }

  Future<void> _scanMissing() async {
    final dispatch = _dispatch;
    final item = _item;
    if (dispatch == null || item == null) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScanFlowScreen(
          target: ScanTarget(
            module: AppModule.dispatch,
            title: 'Link labels',
            contextLine: '${dispatch.depotName} · ${item.name}',
            bottlesPerCase: item.bottlesPerCase,
            unit: ScanUnit.cases,
            requiredCases: item.quantityInCases,
            alreadyLinkedCases: item.issuedQty,
            submit: (draft) => _controller.submitEALLink(
              dispatchId: widget.dispatchId,
              itemId: item.itemId,
              prefix: draft.prefix,
              serialFrom: draft.serialFrom,
              serialTo: draft.serialTo,
            ),
          ),
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final dispatch = _dispatch;
      final item = _item;

      if (dispatch == null || item == null) {
        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppBar(title: const Text('Line', style: AppText.appBarTitle)),
          body: EmptyState(
            icon: Icons.help_outline_rounded,
            title: 'This line is no longer here',
            message:
                'It may have been removed, or the list has moved on. Go '
                'back and open the dispatch again.',
            accent: AppColors.amber,
            tint: AppColors.amberTint,
            primaryLabel: 'Back to the dispatch',
            onPrimary: () => Navigator.pop(context),
          ),
        );
      }

      final ordered = item.quantityInCases;
      final linked = item.issuedQty;
      final short = ordered - linked;
      final complete = short <= 0;
      final lineNumber = dispatch.items.indexOf(item) + 1;

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
                item.name,
                style: AppText.appBarTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Line $lineNumber · ${dispatch.depotName} · '
                '${formatDayMonth(dispatch.dateDispatched)}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.ink500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
            if (_error.isNotEmpty) ...[
              NoticeBanner(
                level: NoticeLevel.error,
                title: 'That did not go through',
                message: _error,
                trailing: IconButton(
                  onPressed: () => setState(() => _error = ''),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Dismiss',
                ),
              ),
              const SizedBox(height: AppSpace.md),
            ],

            // Three figures and the gap between them.
            AppCard(
              radius: AppRadius.card,
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FigureTile(
                          value: formatQty(ordered),
                          label: 'ordered',
                          size: 23,
                        ),
                      ),
                      Expanded(
                        child: FigureTile(
                          value: formatQty(linked),
                          label: 'linked',
                          size: 23,
                        ),
                      ),
                      Expanded(
                        child: FigureTile(
                          value: formatQty(complete ? 0 : short),
                          label: complete ? 'complete' : 'short',
                          size: 23,
                          color: complete
                              ? AppColors.greenDeep
                              : AppColors.caution,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'cases · ${item.bottlesPerCase} bottles per case',
                    style: AppText.micro,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  LinkedProgressBar(
                    linked: linked,
                    required_: ordered,
                    height: 9,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  if (complete)
                    const NoticeBanner(
                      level: NoticeLevel.success,
                      title: 'Fully labelled',
                      message:
                          'Every case on this line has a label against '
                          'it.',
                    )
                  else
                    NoticeBanner(
                      title: '${formatCases(short)} still need labels',
                      // Telling someone to link on a screen that cannot
                      // link reads as a contradiction of the lock at the
                      // foot of it. The shortfall is still worth stating.
                      message: _canLink
                          ? 'Link ${formatQty(short * item.bottlesPerCase)} '
                                'more labels to balance this line. Scanned '
                                'labels must already be recorded as '
                                'produced.'
                          : '${formatQty(short * item.bottlesPerCase)} '
                                'labels\u2019 worth, once this line can be '
                                'linked.',
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppSpace.xl),
            SectionHeading(
              'Linked ranges',
              trailing: Text(
                '${item.links.length}',
                style: AppText.mono(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.ink500,
                ),
              ),
            ),

            if (item.links.isEmpty)
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_off_rounded,
                      size: 20,
                      color: AppColors.caution,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No labels are linked to this line yet.',
                        style: AppText.small,
                      ),
                    ),
                  ],
                ),
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < item.links.length; i++)
                      _LinkRow(
                        link: item.links[i],
                        bottlesPerCase: item.bottlesPerCase,
                        isLast: i == item.links.length - 1,
                        onUnlink: _busy || !_canLink
                            ? null
                            : () => _unlink(item.links[i]),
                      ),
                  ],
                ),
              ),

            if (item.links.isNotEmpty) ...[
              const SizedBox(height: 11),
              Text(
                'Unlinking returns those labels to the production pool. You '
                'will be asked to confirm.',
                style: AppText.small,
              ),
            ],
          ],
        ),
        // Nothing to carry here once the line is covered: the server
        // allows no more than the cases ordered, so "Link another range"
        // could only come back refused, and a bar repeating the Fully
        // labelled banner is just another thing to read.
        bottomNavigationBar: _canLink && complete
            ? null
            : Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.line, width: 1),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.gutter,
                      12,
                      AppSpace.gutter,
                      12,
                    ),
                    // Where labels cannot be changed, the reason stands in place
                    // of the button rather than beside a dead one.
                    child: _canLink
                        ? ElevatedButton.icon(
                            onPressed: _busy ? null : _scanMissing,
                            icon: const Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 20,
                            ),
                            label: Text(
                              'Scan the missing ${formatCases(short)}',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.amber,
                            ),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: AppColors.ink500,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  _whyNotLinking ?? '',
                                  style: AppText.small,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
      );
    });
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.link,
    required this.bottlesPerCase,
    required this.isLast,
    required this.onUnlink,
  });

  final EALLinkModel link;
  final int bottlesPerCase;
  final bool isLast;
  final VoidCallback? onUnlink;

  @override
  Widget build(BuildContext context) {
    final labels = link.serialTo - link.serialFrom + 1;
    final cases = bottlesPerCase > 0 ? labels ~/ bottlesPerCase : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.lineSoft, width: 1),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SerialRangeText(
                  prefix: link.prefix,
                  from: link.serialFrom,
                  to: link.serialTo,
                  size: 13.5,
                ),
                const SizedBox(height: 3),
                Text(
                  cases == null
                      ? formatLabels(labels)
                      : '${formatCases(cases)} · ${formatLabels(labels)}',
                  style: AppText.micro,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onUnlink,
            icon: const Icon(Icons.link_off_rounded, size: 19),
            tooltip: 'Unlink this range',
            color: AppColors.red,
          ),
        ],
      ),
    );
  }
}
