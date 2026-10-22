import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/models/dispatch.dart';
import 'package:eal_scanner/screens/dispatches/EALDetailScreen.dart';
import 'package:eal_scanner/services/authService.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// One dispatch note: where it is in its lifecycle, who is driving it, and
/// which lines are short of labels.
class DispatchDetailScreen extends StatefulWidget {
  const DispatchDetailScreen({super.key, required this.dispatchId});

  final String dispatchId;

  @override
  State<DispatchDetailScreen> createState() => _DispatchDetailScreenState();
}

class _DispatchDetailScreenState extends State<DispatchDetailScreen> {
  final DispatchController _controller = Get.find<DispatchController>();

  DispatchModel? get _dispatch =>
      _controller.dispatches.firstWhereOrNull((d) => d.id == widget.dispatchId);

  bool get _canUpdate => AuthService.can('dispatch:status');

  Future<void> _openUpdateSheet(DispatchModel dispatch) async {
    final shortCases = dispatch.totalQuantity - dispatch.issuedQty;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _UpdateDispatchSheet(
        dispatch: dispatch,
        shortCases: shortCases > 0 ? shortCases : 0,
        controller: _controller,
      ),
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final dispatch = _dispatch;

      if (dispatch == null) {
        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppBar(
            title: const Text('Dispatch', style: AppText.appBarTitle),
          ),
          body: EmptyState(
            icon: Icons.help_outline_rounded,
            title: 'This dispatch is no longer here',
            message:
                'It may have been removed, or the day has moved on. Go '
                'back and refresh the list.',
            accent: AppColors.amber,
            tint: AppColors.amberTint,
            primaryLabel: 'Back to dispatches',
            onPrimary: () => Navigator.pop(context),
          ),
        );
      }

      final short = dispatch.totalQuantity - dispatch.issuedQty;
      final isShort = short > 0;
      final shortLines = dispatch.items
          .where((i) => i.issuedQty < i.quantityInCases)
          .toList();

      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dispatch.depotName,
                style: AppText.appBarTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${formatDayMonthYear(dispatch.dateDispatched)} · '
                '${titleCase(dispatch.market)}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.ink500),
              ),
            ],
          ),
          actions: [
            // The sheet behind this sets the vehicle and moves the note
            // along, both of which the server guards with dispatch:status.
            if (_canUpdate)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: OutlinedButton(
                  onPressed: () => _openUpdateSheet(dispatch),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Edit'),
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(58),
            child: _StageRail(status: dispatch.status),
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
            if (isShort)
              NoticeBanner(
                title: '${formatCases(short)} still need labels',
                message: shortLines.length == 1
                    ? 'One line is short. This dispatch cannot move to Loaded '
                          'until every line is covered.'
                    : '${shortLines.length} lines are short. This dispatch '
                          'cannot move to Loaded until every line is covered.',
              )
            else
              const NoticeBanner(
                level: NoticeLevel.success,
                title: 'Every line is fully labelled',
                message: 'This dispatch can be moved on to the next stage.',
              ),

            const SizedBox(height: AppSpace.lg),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  _MetaRow(
                    icon: Icons.local_shipping_outlined,
                    label: 'Vehicle',
                    value: dispatch.vehicleNumber.trim().isEmpty
                        ? null
                        : dispatch.vehicleNumber,
                    placeholder: 'Not set',
                    isMono: true,
                  ),
                  _MetaRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Driver',
                    value: dispatch.driverName.trim().isEmpty
                        ? null
                        : dispatch.driverName,
                    placeholder: 'Not set',
                    trailing: dispatch.driverContact.trim().isEmpty
                        ? null
                        : Text(
                            dispatch.driverContact,
                            style: AppText.mono(
                              size: 12.5,
                              color: AppColors.ink500,
                            ),
                          ),
                  ),
                  _MetaRow(
                    icon: Icons.apartment_rounded,
                    label: 'Company',
                    value: dispatch.companyName,
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpace.xl),
            SectionHeading(
              'Lines',
              trailing: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: formatQty(dispatch.issuedQty),
                      style: AppText.mono(size: 12, weight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: ' / ${formatQty(dispatch.totalQuantity)} cases',
                      style: AppText.small,
                    ),
                  ],
                ),
              ),
            ),

            for (var i = 0; i < dispatch.items.length; i++) ...[
              if (i > 0) const SizedBox(height: 9),
              _LineCard(
                item: dispatch.items[i],
                lineNumber: i + 1,
                onTap: () => Get.to(
                  () => EALDetailScreen(
                    dispatchItemId: dispatch.items[i].id,
                    dispatchId: dispatch.id,
                  ),
                ),
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
              child: Row(
                children: [
                  if (_canUpdate)
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => _openUpdateSheet(dispatch),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 50),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 21),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final line = shortLines.isNotEmpty
                            ? shortLines.first
                            : dispatch.items.firstOrNull;
                        if (line == null) return;

                        Get.to(
                          () => EALDetailScreen(
                            dispatchItemId: line.id,
                            dispatchId: dispatch.id,
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
                      label: Text(
                        isShort
                            ? 'Link the missing ${formatQty(short)}'
                            : 'Review linked labels',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        minimumSize: const Size.fromHeight(50),
                      ),
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

/// The five stages, drawn as a rail. Replaces the status chip the old screen
/// pinned to the bottom-right corner of the header card.
class _StageRail extends StatelessWidget {
  const _StageRail({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final current = dispatchStageIndex(status);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Row(
        children: [
          for (var i = 0; i < kDispatchStages.length; i++)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i == 0
                              ? Colors.transparent
                              : (i <= current
                                    ? AppColors.blue
                                    : AppColors.line),
                        ),
                      ),
                      Container(
                        width: i == current ? 20 : 18,
                        height: i == current ? 20 : 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i <= current ? AppColors.blue : AppColors.line,
                          shape: BoxShape.circle,
                          border: i == current
                              ? Border.all(color: AppColors.blueLine, width: 4)
                              : null,
                        ),
                        child: i < current
                            ? const Icon(
                                Icons.check_rounded,
                                size: 11,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i == kDispatchStages.length - 1
                              ? Colors.transparent
                              : (i < current ? AppColors.blue : AppColors.line),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    titleCase(kDispatchStages[i]),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: i <= current
                          ? AppColors.blueDeep
                          : AppColors.ink500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.placeholder = '—',
    this.isMono = false,
    this.isLast = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final bool isMono;
  final bool isLast;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.lineSoft, width: 1),
              ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.ink500),
          const SizedBox(width: 10),
          Text(label, style: AppText.small),
          const Spacer(),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  has ? value! : placeholder,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: isMono
                      ? AppText.mono(size: 14, weight: FontWeight.w600)
                      : TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: has ? AppColors.ink900 : AppColors.ink500,
                        ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.item,
    required this.lineNumber,
    required this.onTap,
  });

  final DispatchItemModel item;
  final int lineNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final short = item.quantityInCases - item.issuedQty;
    final isShort = short > 0;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      borderColor: isShort ? AppColors.cautionLine : AppColors.line,
      borderWidth: isShort ? 1.5 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Line $lineNumber · ${formatCases(item.quantityInCases)} '
                      'ordered',
                      style: AppText.micro,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isShort)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 13,
                      color: AppColors.caution,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${formatQty(short)} short',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cautionDeep,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${formatQty(item.issuedQty)} linked',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.greenDeep,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          LinkedProgressBar(
            linked: item.issuedQty,
            required_: item.quantityInCases,
            height: 6,
          ),
          if (item.links.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${item.links.length} '
                  '${item.links.length == 1 ? 'range' : 'ranges'}',
                  style: AppText.micro,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SerialRangeText(
                    prefix: item.links.first.prefix,
                    from: item.links.first.serialFrom,
                    to: item.links.first.serialTo,
                    size: 11.5,
                    showPrefix: false,
                    color: AppColors.ink700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Vehicle, driver and stage.
///
/// The old sheet let any stage be tapped and reported the refusal afterwards
/// in a snackbar. Here a stage that cannot be reached says so before it is
/// tapped, and names what is blocking it.
class _UpdateDispatchSheet extends StatefulWidget {
  const _UpdateDispatchSheet({
    required this.dispatch,
    required this.shortCases,
    required this.controller,
  });

  final DispatchModel dispatch;
  final int shortCases;
  final DispatchController controller;

  @override
  State<_UpdateDispatchSheet> createState() => _UpdateDispatchSheetState();
}

class _UpdateDispatchSheetState extends State<_UpdateDispatchSheet> {
  late final TextEditingController _vehicle = TextEditingController(
    text: widget.dispatch.vehicleNumber,
  );
  late final TextEditingController _driver = TextEditingController(
    text: widget.dispatch.driverName,
  );
  late final TextEditingController _contact = TextEditingController(
    text: widget.dispatch.driverContact,
  );

  late String _status = widget.dispatch.status.toLowerCase();
  bool _saving = false;
  String _error = '';

  int get _currentIndex => dispatchStageIndex(widget.dispatch.status);

  String? get _nextStage => _currentIndex < kDispatchStages.length - 1
      ? kDispatchStages[_currentIndex + 1]
      : null;

  /// Mirrors the server: `loaded` is refused while any line is short, and
  /// `final` can go back to `draft` only when nothing is linked yet.
  String? _blockedReason(String stage) {
    if (stage == 'loaded' && widget.shortCases > 0) {
      return '${formatCases(widget.shortCases)} on this dispatch have no '
          'labels linked yet.';
    }
    return null;
  }

  bool get _canRevertToDraft =>
      widget.dispatch.status.toLowerCase() == 'final' &&
      widget.dispatch.issuedQty == 0;

  @override
  void dispose() {
    _vehicle.dispose();
    _driver.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = '';
    });

    final error = await widget.controller.updateVehicleDetails(
      dispatchId: widget.dispatch.id,
      vehicleNumber: _vehicle.text.trim(),
      driverName: _driver.text.trim(),
      driverContact: _contact.text.trim(),
      status: _status,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextStage;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  0,
                  AppSpace.gutter,
                  0,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Update dispatch', style: AppText.title),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 19),
                      tooltip: 'Close',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.canvas,
                        foregroundColor: AppColors.ink700,
                      ),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.lg,
                    AppSpace.gutter,
                    AppSpace.lg,
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

                    const Text('Vehicle number', style: AppText.label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _vehicle,
                      textCapitalization: TextCapitalization.characters,
                      style: AppText.mono(size: 15.5, weight: FontWeight.w600),
                      inputFormatters: [
                        TextInputFormatter.withFunction(
                          (_, next) =>
                              next.copyWith(text: next.text.toUpperCase()),
                        ),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'BR 01 GA 0000',
                      ),
                    ),

                    const SizedBox(height: AppSpace.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Driver name', style: AppText.label),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _driver,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'Full name',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 11),
                        SizedBox(
                          width: 140,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Contact', style: AppText.label),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _contact,
                                keyboardType: TextInputType.phone,
                                style: AppText.mono(size: 15),
                                decoration: const InputDecoration(
                                  hintText: '10 digits',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpace.xl),
                    const SectionHeading('Stage'),

                    // Current stage.
                    _StageOption(
                      stage: widget.dispatch.status.toLowerCase(),
                      index: _currentIndex,
                      selected: _status == widget.dispatch.status.toLowerCase(),
                      isCurrent: true,
                      onTap: () => setState(
                        () => _status = widget.dispatch.status.toLowerCase(),
                      ),
                    ),

                    if (next != null) ...[
                      const SizedBox(height: 9),
                      _StageOption(
                        stage: next,
                        index: _currentIndex + 1,
                        selected: _status == next,
                        blockedReason: _blockedReason(next),
                        onTap: () => setState(() => _status = next),
                      ),
                    ],

                    if (_canRevertToDraft) ...[
                      const SizedBox(height: 9),
                      _StageOption(
                        stage: 'draft',
                        index: 0,
                        selected: _status == 'draft',
                        note: 'Allowed while nothing is linked',
                        onTap: () => setState(() => _status = 'draft'),
                      ),
                    ],

                    // Everything beyond the next stage, for orientation only.
                    for (
                      var i = _currentIndex + 2;
                      i < kDispatchStages.length;
                      i++
                    ) ...[
                      const SizedBox(height: 9),
                      _StageOption(
                        stage: kDispatchStages[i],
                        index: i,
                        selected: false,
                        unreachableAfter: titleCase(kDispatchStages[i - 1]),
                        onTap: null,
                      ),
                    ],

                    const SizedBox(height: AppSpace.md),
                    Text(
                      'A dispatch moves one stage at a time, and never '
                      'backwards once labels are linked. Ask a supervisor to '
                      'reverse a stage.',
                      style: AppText.small,
                    ),
                  ],
                ),
              ),

              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.line, width: 1),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  12,
                  AppSpace.gutter,
                  12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.amber,
                        ),
                        child: _saving
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
                            : const Text('Save changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageOption extends StatelessWidget {
  const _StageOption({
    required this.stage,
    required this.index,
    required this.selected,
    required this.onTap,
    this.isCurrent = false,
    this.blockedReason,
    this.unreachableAfter,
    this.note,
  });

  final String stage;
  final int index;
  final bool selected;
  final VoidCallback? onTap;
  final bool isCurrent;
  final String? blockedReason;
  final String? unreachableAfter;
  final String? note;

  bool get _disabled =>
      onTap == null || blockedReason != null || unreachableAfter != null;

  @override
  Widget build(BuildContext context) {
    final blocked = blockedReason != null;

    final Color border;
    final Color background;
    if (blocked) {
      border = AppColors.cautionLine;
      background = AppColors.cautionTint;
    } else if (selected) {
      border = AppColors.blue;
      background = AppColors.blueTint;
    } else if (unreachableAfter != null) {
      border = AppColors.lineSoft;
      background = AppColors.field;
    } else {
      border = AppColors.line;
      background = AppColors.surface;
    }

    final content = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.brControl,
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (blocked)
            const Icon(
              Icons.lock_outline_rounded,
              size: 21,
              color: AppColors.caution,
            )
          else
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 21,
              color: selected
                  ? AppColors.blue
                  : (_disabled ? AppColors.ink400 : AppColors.ink500),
            ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: titleCase(stage),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: blocked
                              ? AppColors.cautionDeep
                              : (_disabled
                                    ? AppColors.ink500
                                    : AppColors.ink900),
                        ),
                      ),
                      TextSpan(
                        text:
                            ' · stage ${index + 1} of '
                            '${kDispatchStages.length}',
                        style: AppText.small,
                      ),
                    ],
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(height: 2),
                  Text('Where it is now', style: AppText.small),
                ],
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note!, style: AppText.small),
                ],
                if (blocked) ...[
                  const SizedBox(height: 3),
                  Text('Blocked: $blockedReason', style: AppText.small),
                ],
                if (unreachableAfter != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Available after $unreachableAfter',
                    style: AppText.small,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (_disabled) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brControl,
      child: content,
    );
  }
}
