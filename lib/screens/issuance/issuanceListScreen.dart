import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/models/issuance.dart';
import 'package:eal_scanner/screens/issuance/EALStickerScreen.dart';
import 'package:eal_scanner/screens/issuance/issuanceDetailScreen.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/list_header.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// Labels received from the excise office.
///
/// The date filter is on the surface instead of behind a calendar icon,
/// loading shows skeleton rows rather than a full-screen barrier, and an
/// empty day says which day had the last records.
class IssuanceListScreen extends StatefulWidget {
  const IssuanceListScreen({super.key});

  @override
  State<IssuanceListScreen> createState() => _IssuanceListScreenState();
}

class _IssuanceListScreenState extends State<IssuanceListScreen> {
  final Issuancecontroller _controller = Get.find<Issuancecontroller>();
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_requested && _controller.ealIssuance.isEmpty) {
        _requested = true;
        _controller.fetchEALIssuance();
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
              title: 'EAL issuance',
              countLabel: _controller.isLoading.value
                  ? null
                  : '${_controller.ealIssuance.length} '
                      '${_controller.ealIssuance.length == 1 ? 'record' : 'records'}',
              searchHint: 'Pack, market or company',
              onSearchChanged: (v) => _controller.searchQuery.value = v,
              dateLabel: formatDayMonth(_controller.selectedDate.value),
              onPickDate: _controller.pickDate,
              accent: AppColors.indigo,
              showProgress: _controller.isLoading.value &&
                  _controller.ealIssuance.isNotEmpty,
            ),
          ),

          Obx(() => _FilterRow(controller: _controller)),

          Obx(() {
            if (_controller.ealIssuance.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.md,
                AppSpace.gutter,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _SummaryFigure(
                      value: formatQty(_controller.totalIssued),
                      label: 'labels issued',
                    ),
                  ),
                  _SummaryFigure(
                    value: formatQty(_controller.totalUnused),
                    label: 'unused',
                    color: AppColors.caution,
                    alignEnd: true,
                  ),
                ],
              ),
            );
          }),

          Expanded(child: Obx(_buildBody)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.to(() => const EALStickerScreen()),
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New issuance',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final error = _controller.errorMessage.value;

    if (_controller.isLoading.value && _controller.ealIssuance.isEmpty) {
      return const SkeletonList();
    }

    if (error.isNotEmpty && _controller.ealIssuance.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: NoticeBanner(
          level: NoticeLevel.error,
          title: 'Could not load issuance',
          message: error,
          trailing: TextButton(
            onPressed: _controller.fetchEALIssuance,
            child: const Text('Retry'),
          ),
        ),
      );
    }

    final rows = _controller.filteredIssuance;

    if (rows.isEmpty) {
      final searching = _controller.searchQuery.value.trim().isNotEmpty;

      if (searching) {
        return EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Nothing matches “${_controller.searchQuery.value.trim()}”',
          message: 'Try a pack size, a market, or part of the company name.',
          accent: AppColors.indigo,
          tint: AppColors.indigoTint,
        );
      }

      return EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'No labels issued on '
            '${formatDayMonthYear(_controller.selectedDate.value)}',
        message: 'Widen the range to the last seven days, or record the '
            'issuance you have in hand.',
        accent: AppColors.indigo,
        tint: AppColors.indigoTint,
        primaryLabel: 'Show the last 7 days',
        onPrimary: () => _controller.setRange(
          endDate: DateTime.now(),
          days: 7,
        ),
        secondaryLabel: 'Record a new issuance',
        onSecondary: () => Get.to(() => const EALStickerScreen()),
      );
    }

    return RefreshIndicator(
      color: AppColors.indigo,
      onRefresh: () async => _controller.fetchEALIssuance(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.md,
          AppSpace.gutter,
          96,
        ),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _IssuanceCard(issuance: rows[i]),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.controller});

  final Issuancecontroller controller;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final selected = controller.selectedDate.value;
    final days = controller.rangeDays.value;

    final isToday = days == 1 && _isSameDay(selected, now);
    final isYesterday = days == 1 &&
        _isSameDay(selected, now.subtract(const Duration(days: 1)));
    final isWeek = days == 7;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.md),
      child: FilterPillRow(
        children: [
          FilterPill(
            label: 'Today',
            selected: isToday,
            accent: AppColors.indigo,
            onTap: () => controller.setRange(endDate: DateTime.now()),
          ),
          FilterPill(
            label: 'Yesterday',
            selected: isYesterday,
            accent: AppColors.indigo,
            onTap: () => controller.setRange(
              endDate: DateTime.now().subtract(const Duration(days: 1)),
            ),
          ),
          FilterPill(
            label: 'Last 7 days',
            selected: isWeek,
            accent: AppColors.indigo,
            onTap: () =>
                controller.setRange(endDate: DateTime.now(), days: 7),
          ),
          if (!isToday && !isYesterday && !isWeek)
            FilterPill(
              label: formatDayMonth(selected),
              selected: true,
              accent: AppColors.indigo,
              onTap: controller.pickDate,
            ),
        ],
      ),
    );
  }
}

class _SummaryFigure extends StatelessWidget {
  const _SummaryFigure({
    required this.value,
    required this.label,
    this.color = AppColors.ink900,
    this.alignEnd = false,
  });

  final String value;
  final String label;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(value, style: AppText.figure(size: 17, color: color)),
        Text(label, style: AppText.micro),
      ],
    );
  }
}

class _IssuanceCard extends StatelessWidget {
  const _IssuanceCard({required this.issuance});

  final IssuanceModel issuance;

  int get _from => int.tryParse(issuance.serialFrom) ?? 0;
  int get _to => int.tryParse(issuance.serialTo) ?? 0;
  int get _used => issuance.issuedQuantity - issuance.balanceQuantity;

  @override
  Widget build(BuildContext context) {
    final complete = issuance.balanceQuantity <= 0;

    return AppCard(
      onTap: () => Get.to(() => EALIssuanceDetailScreen(issuance: issuance)),
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
                      issuance.packName,
                      style: AppText.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      issuance.companyName,
                      style: AppText.small,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              MarketChip(issuance.market),
            ],
          ),

          const SizedBox(height: 11),
          SerialRangeText(
            prefix: issuance.prefix,
            from: _from,
            to: _to,
            size: 14,
          ),

          const SizedBox(height: 12),
          LinkedProgressBar(
            linked: _used,
            required_: issuance.issuedQuantity,
            accent: complete ? AppColors.green : AppColors.indigo,
            label: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatQty(_used),
                    style: AppText.mono(size: 12.5, weight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: ' of ${formatQty(issuance.issuedQuantity)} used',
                    style: AppText.small,
                  ),
                ],
              ),
            ),
            trailing: complete
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: AppColors.green,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Fully used',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.greenDeep,
                        ),
                      ),
                    ],
                  )
                : Text(
                    '${formatQty(issuance.balanceQuantity)} left',
                    style: AppText.mono(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: AppColors.ink500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
