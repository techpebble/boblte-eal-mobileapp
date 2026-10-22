import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/models/dispatch.dart';
import 'package:eal_scanner/screens/dispatches/DispatchDetailScreen.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/list_header.dart';

/// Dispatch notes for the day.
///
/// Notes short of EAL links lead the list and carry their shortfall in words;
/// the old screen tinted the whole card by status and left the quantity
/// mismatch to a red number.
class DispatchListScreen extends StatefulWidget {
  const DispatchListScreen({super.key});

  @override
  State<DispatchListScreen> createState() => _DispatchListScreenState();
}

class _DispatchListScreenState extends State<DispatchListScreen> {
  final DispatchController _controller = Get.find<DispatchController>();
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_requested && _controller.dispatches.isEmpty) {
        _requested = true;
        _controller.fetchDispatches();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          Obx(
            () => ListScreenHeader(
              title: 'Dispatches',
              countLabel: _controller.isLoading.value
                  ? null
                  : '${_controller.dispatches.length} '
                        '${_controller.dispatches.length == 1 ? 'note' : 'notes'}',
              searchHint: 'Depot, vehicle or driver',
              onSearchChanged: (v) => _controller.searchQuery.value = v,
              dateLabel: formatDayMonth(_controller.selectedDate.value),
              onPickDate: _controller.pickDate,
              accent: AppColors.amber,
              showProgress:
                  _controller.isLoading.value &&
                  _controller.dispatches.isNotEmpty,
            ),
          ),

          // Observables are read here, inside the Obx closure; reading
          // them inside _FilterRow.build puts them outside GetX's scope.
          Obx(
            () => _FilterRow(
              controller: _controller,
              selectedDate: _controller.selectedDate.value,
              rangeDays: _controller.rangeDays.value,
              statusFilter: _controller.statusFilter.value,
              shortCount: _controller.shortCount,
            ),
          ),

          Expanded(child: Obx(_buildBody)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final error = _controller.errorMessage.value;

    if (_controller.isLoading.value && _controller.dispatches.isEmpty) {
      return const SkeletonList();
    }

    if (error.isNotEmpty && _controller.dispatches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: NoticeBanner(
          level: NoticeLevel.error,
          title: 'Could not load dispatches',
          message: error,
          trailing: TextButton(
            onPressed: _controller.fetchDispatches,
            child: const Text('Retry'),
          ),
        ),
      );
    }

    final rows = _controller.filteredDispatches
      // Notes needing labels first, then by stage.
      ..sort((a, b) {
        final aShort = _controller.isShortOfLabels(a) ? 0 : 1;
        final bShort = _controller.isShortOfLabels(b) ? 0 : 1;
        if (aShort != bShort) return aShort - bShort;
        return dispatchStageIndex(a.status) - dispatchStageIndex(b.status);
      });

    if (rows.isEmpty) {
      final filtering =
          _controller.searchQuery.value.trim().isNotEmpty ||
          _controller.statusFilter.value.isNotEmpty;

      if (filtering) {
        return EmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: 'Nothing matches those filters',
          message:
              'Clear the status filter or the search to see the whole '
              'day again.',
          accent: AppColors.amber,
          tint: AppColors.amberTint,
          primaryLabel: 'Clear filters',
          onPrimary: () {
            _controller.searchQuery.value = '';
            _controller.statusFilter.value = '';
          },
        );
      }

      return EmptyState(
        icon: Icons.local_shipping_outlined,
        title:
            'No dispatches on '
            '${formatDayMonthYear(_controller.selectedDate.value)}',
        message:
            'Dispatch notes are raised in the back office. Widen the '
            'range if you are looking for an earlier one.',
        accent: AppColors.amber,
        tint: AppColors.amberTint,
        primaryLabel: 'Show the last 7 days',
        onPrimary: () => _controller.setRange(endDate: DateTime.now(), days: 7),
      );
    }

    return RefreshIndicator(
      color: AppColors.amber,
      onRefresh: () async => _controller.fetchDispatches(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.md,
          AppSpace.gutter,
          AppSpace.xxl,
        ),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _DispatchCard(
          dispatch: rows[i],
          isShort: _controller.isShortOfLabels(rows[i]),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.controller,
    required this.selectedDate,
    required this.rangeDays,
    required this.statusFilter,
    required this.shortCount,
  });

  final DispatchController controller;
  final DateTime selectedDate;
  final int rangeDays;
  final String statusFilter;
  final int shortCount;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final selected = selectedDate;
    final days = rangeDays;
    final status = statusFilter;

    final isToday = days == 1 && _isSameDay(selected, now);
    final isWeek = days == 7;
    final short = shortCount;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.md),
      child: FilterPillRow(
        children: [
          // The filter that gets acted on, first.
          if (short > 0)
            FilterPill(
              label: 'Short $short',
              selected: status == 'short',
              accent: AppColors.caution,
              leading: Icon(
                Icons.warning_amber_rounded,
                size: 13,
                color: status == 'short' ? Colors.white : AppColors.caution,
              ),
              onTap: () => controller.setStatusFilter('short'),
            ),
          FilterPill(
            label: 'Today',
            selected: isToday && status.isEmpty,
            accent: AppColors.amber,
            onTap: () {
              controller.statusFilter.value = '';
              controller.setRange(endDate: DateTime.now());
            },
          ),
          FilterPill(
            label: 'Last 7 days',
            selected: isWeek,
            accent: AppColors.amber,
            onTap: () => controller.setRange(endDate: DateTime.now(), days: 7),
          ),
          for (final stage in kDispatchStages)
            FilterPill(
              label: titleCase(stage),
              selected: status == stage,
              accent: AppColors.amber,
              onTap: () => controller.setStatusFilter(stage),
            ),
        ],
      ),
    );
  }
}

class _DispatchCard extends StatelessWidget {
  const _DispatchCard({required this.dispatch, required this.isShort});

  final DispatchModel dispatch;
  final bool isShort;

  @override
  Widget build(BuildContext context) {
    final outstanding = dispatch.totalQuantity - dispatch.issuedQty;
    final notStarted = dispatch.issuedQty <= 0;

    return AppCard(
      onTap: () => Get.to(() => DispatchDetailScreen(dispatchId: dispatch.id)),
      borderColor: isShort ? AppColors.cautionLine : AppColors.line,
      borderWidth: isShort ? 1.5 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dispatch.depotName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        titleCase(dispatch.market),
                        dispatch.vehicleNumber.trim().isEmpty
                            ? 'vehicle not set'
                            : dispatch.vehicleNumber,
                      ].join(' · '),
                      style: AppText.small,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              DispatchStatusPill(dispatch.status),
            ],
          ),

          const SizedBox(height: 12),
          LinkedProgressBar(
            linked: dispatch.issuedQty,
            required_: dispatch.totalQuantity,
            label: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatQty(dispatch.issuedQty),
                    style: AppText.mono(size: 12.5, weight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: ' of ${formatCases(dispatch.totalQuantity)} linked',
                    style: AppText.small,
                  ),
                ],
              ),
            ),
            trailing: isShort
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 13,
                        color: AppColors.caution,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        notStarted
                            ? 'Not started'
                            : '${formatQty(outstanding)} short',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cautionDeep,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Complete',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.greenDeep,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
