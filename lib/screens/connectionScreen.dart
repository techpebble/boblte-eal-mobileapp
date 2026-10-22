import 'package:flutter/material.dart';

import 'package:eal_scanner/branding.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';

/// Shown in place of the home screen's content when the server cannot be
/// reached. The app records every scan straight to the server, so there is no
/// local queue to fall back on — saying that once and plainly beats letting
/// each screen fail on its own.
class ConnectionLostView extends StatelessWidget {
  const ConnectionLostView({
    super.key,
    required this.onRetry,
    this.isRetrying = false,
    this.lastReachedAt,
  });

  final VoidCallback onRetry;
  final bool isRetrying;
  final String? lastReachedAt;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.xxl,
        AppSpace.gutter,
        AppSpace.xxl,
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.cautionTint,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              size: 42,
              color: AppColors.caution,
            ),
          ),
          const SizedBox(height: 20),
          const Text('No connection', style: AppText.headline),
          const SizedBox(height: 9),
          const Text(
            'EAL Track records every scan on the server as you go. Nothing can '
            'be issued, entered or linked until the network is back.',
            textAlign: TextAlign.center,
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isRetrying ? null : onRetry,
              icon: isRetrying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 19),
              label: Text(isRetrying ? 'Trying…' : 'Try again'),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            radius: AppRadius.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('WORTH CHECKING', style: AppText.section),
                const SizedBox(height: 4),
                ..._checks.map(
                  (check) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(check.icon, size: 18, color: AppColors.ink500),
                        const SizedBox(width: 10),
                        Expanded(child: Text(check.text, style: AppText.small)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            lastReachedAt == null
                ? '${AppBrand.name} could not reach the server'
                : 'Last reached the server at $lastReachedAt',
            style: AppText.mono(size: 11.5, color: AppColors.ink500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static const _checks = <_Check>[
    _Check(
      Icons.wifi_rounded,
      'Plant Wi-Fi reaches the bottling hall but not every corner of the '
      'store — step back towards the doorway.',
    ),
    _Check(
      Icons.smartphone_rounded,
      'Mobile data switched off, or flight mode left on.',
    ),
    _Check(
      Icons.edit_note_rounded,
      'Write the serial range on the day sheet and enter it by hand once you '
      'are back on the network.',
    ),
  ];
}

class _Check {
  const _Check(this.icon, this.text);
  final IconData icon;
  final String text;
}
