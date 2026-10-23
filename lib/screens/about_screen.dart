import 'package:flutter/material.dart';

import 'package:eal_scanner/branding.dart';
import 'package:eal_scanner/config/api_config.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';

/// What the app is, rather than what this account is.
///
/// The licences live here instead of on the account page: they are read
/// once, by one person, and they do not belong between a sign-out button
/// and a set of scanning preferences.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('About', style: AppText.appBarTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.xxl,
          AppSpace.gutter,
          AppSpace.xxl,
        ),
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                AppBrand.logo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.qr_code_2_rounded,
                  size: 34,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            AppBrand.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppColors.ink900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version ${AppBrand.version}',
            textAlign: TextAlign.center,
            style: AppText.mono(size: 12.5, color: AppColors.ink500),
          ),
          const SizedBox(height: 12),
          Text(
            'Issuance, production and dispatch for excise adhesive labels. '
            'Every scan is written to the server as it happens.',
            textAlign: TextAlign.center,
            style: AppText.small,
          ),

          const SizedBox(height: AppSpace.xxl),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _AboutRow(
                  icon: Icons.menu_book_outlined,
                  label: 'Open-source licences',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: AppBrand.name,
                    applicationVersion: AppBrand.version,
                  ),
                  isLast: ApiConfig.isProduction,
                ),

                // Only a test build names its server, as the sign-in
                // screen does. The build that ships names none: there is
                // only one, and the address belongs in nobody's pocket.
                if (!ApiConfig.isProduction)
                  Container(
                    color: AppColors.cautionTint,
                    child: _AboutRow(
                      icon: Icons.science_outlined,
                      iconColor: AppColors.caution,
                      label: 'Test server',
                      labelColor: AppColors.cautionDeep,
                      value: ApiConfig.label,
                      isLast: true,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpace.lg),
          Text(
            'Built for the plant floor. Report anything that reads wrongly '
            'through Account · Report a problem.',
            textAlign: TextAlign.center,
            style: AppText.micro,
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.iconColor = AppColors.ink500,
    this.labelColor = AppColors.ink900,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color labelColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.lineSoft, width: 1),
              ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: labelColor,
              ),
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: AppText.mono(size: 12.5, color: AppColors.ink500),
            ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.ink400,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
