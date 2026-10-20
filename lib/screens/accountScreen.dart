import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/branding.dart';
import 'package:eal_scanner/config/api_config.dart';
import 'package:eal_scanner/controllers/dashboardController.dart';
import 'package:eal_scanner/controllers/loginController.dart';
import 'package:eal_scanner/services/authService.dart';
import 'package:eal_scanner/services/settingsService.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';

/// Account, scanning preferences and the sign-out. The old build hid logout
/// behind an unlabelled app-bar icon and offered nothing else.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late bool _torch = SettingsService.torchByDefault;
  late bool _feedback = SettingsService.scanFeedback;
  late String _prefix = SettingsService.defaultPrefix;

  Map<String, dynamic> get _user => AuthService.user ?? const {};

  String get _name {
    final value = _user['fullName'];
    final name = value?.toString().trim() ?? '';
    return name.isEmpty ? 'Signed in' : name;
  }

  String get _initials {
    final parts = _name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'EA';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get _subtitle {
    final role = _user['role']?.toString().trim() ?? '';
    final email = _user['email']?.toString().trim() ?? '';
    final roleLabel = role.isEmpty
        ? null
        : role[0].toUpperCase() + role.substring(1).toLowerCase();

    return [roleLabel, email.isEmpty ? null : email]
        .whereType<String>()
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Account', style: AppText.title),
        shape: const Border(
          bottom: BorderSide(color: AppColors.line, width: 1),
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
          AppCard(
            radius: AppRadius.card,
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _subtitle,
                          style: AppText.small,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpace.xl),
          const SectionHeading('Scanning'),
          _Group(
            children: [
              _SwitchRow(
                icon: Icons.flashlight_on_outlined,
                label: 'Torch on by default',
                value: _torch,
                onChanged: (v) async {
                  setState(() => _torch = v);
                  await SettingsService.setTorchByDefault(v);
                },
              ),
              _SwitchRow(
                icon: Icons.volume_up_outlined,
                label: 'Beep and vibrate on scan',
                value: _feedback,
                onChanged: (v) async {
                  setState(() => _feedback = v);
                  await SettingsService.setScanFeedback(v);
                },
              ),
              _NavRow(
                icon: Icons.tag_rounded,
                label: 'Default serial prefix',
                value: _prefix.isEmpty ? 'Not set' : _prefix,
                valueIsMono: _prefix.isNotEmpty,
                onTap: _editPrefix,
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: AppSpace.xl),
          const SectionHeading('Data'),
          _Group(
            children: [
              Obx(() {
                final controller = Get.find<DashboardController>();
                final offline = controller.isOffline.value;
                return _StatusRow(
                  icon: offline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                  label: 'Server connection',
                  value: offline ? 'No connection' : 'Online',
                  valueColor:
                      offline ? AppColors.cautionDeep : AppColors.greenDeep,
                  dotColor: offline ? AppColors.caution : AppColors.green,
                );
              }),
              Obx(() {
                final controller = Get.find<DashboardController>();
                return _NavRow(
                  icon: Icons.refresh_rounded,
                  label: 'Refresh overview',
                  value: controller.lastUpdatedLabel,
                  onTap: () => controller.fetch(background: true),
                  isLast: true,
                );
              }),
            ],
          ),

          const SizedBox(height: AppSpace.xl),
          const SectionHeading('Support'),
          _Group(
            children: [
              _NavRow(
                icon: Icons.menu_book_outlined,
                label: 'How to scan a range',
                onTap: _showScanHelp,
              ),
              _NavRow(
                icon: Icons.help_outline_rounded,
                label: 'Report a problem',
                onTap: _showReportHelp,
                isLast: true,
              ),
            ],
          ),

          const SizedBox(height: AppSpace.xxl),
          OutlinedButton.icon(
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.redLine, width: 1.5),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            '${AppBrand.name} ${AppBrand.version} · ${ApiConfig.label}',
            textAlign: TextAlign.center,
            style: AppText.mono(size: 11, color: AppColors.ink500),
          ),
        ],
      ),
    );
  }

  Future<void> _editPrefix() async {
    final field = TextEditingController(text: _prefix);

    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Default serial prefix'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pre-fills the first step of a scan. Leave it empty to type the '
              'prefix each time.',
              style: AppText.small,
            ),
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: field,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: AppText.mono(size: 18, weight: FontWeight.w600),
              decoration: const InputDecoration(hintText: 'ML'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(field.text.trim().toUpperCase()),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    field.dispose();

    if (saved == null || !mounted) return;
    setState(() => _prefix = saved);
    await SettingsService.setDefaultPrefix(saved);
  }

  void _showScanHelp() {
    _showSheet(
      title: 'How to scan a range',
      body: const [
        'Enter the prefix printed before the digits, such as ML.',
        'Scan the first label of the run — the lowest serial.',
        'Scan the last label — the highest serial.',
        'Check the case count on the summary, then submit.',
        'If a label is torn or will not read, type the serial instead. '
            'Typed entries are marked so a supervisor can check them.',
      ],
    );
  }

  void _showReportHelp() {
    _showSheet(
      title: 'Report a problem',
      body: [
        'Note the depot or item, the serial range, and the time.',
        'Say whether the range was scanned or typed by hand.',
        'Quote the build below so the version is unambiguous.',
        '${AppBrand.name} ${AppBrand.version} · ${ApiConfig.label}',
      ],
    );
  }

  void _showSheet({required String title, required List<String> body}) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            0,
            AppSpace.gutter,
            AppSpace.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.title),
              const SizedBox(height: AppSpace.md),
              for (var i = 0; i < body.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: const BoxDecoration(
                          color: AppColors.blueTint,
                          borderRadius: AppRadius.brPill,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blueDeep,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(body[i], style: AppText.bodyMuted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(
          'Anything already saved stays on the server. You will need your '
          'password to sign back in.',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay signed in'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Get.find<LoginController>().logout();
    }
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.child,
    this.onTap,
    this.isLast = false,
  });

  final Widget child;
  final VoidCallback? onTap;
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
      child: child,
    );

    if (onTap == null) return content;

    return InkWell(onTap: onTap, child: content);
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.ink500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: AppColors.ink900,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.blue,
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.valueIsMono = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;
  final bool valueIsMono;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      onTap: onTap,
      isLast: isLast,
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.ink500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: AppColors.ink900,
              ),
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: valueIsMono
                  ? AppText.mono(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: AppColors.ink500,
                    )
                  : const TextStyle(fontSize: 13.5, color: AppColors.ink500),
            ),
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.ink400,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.dotColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.ink500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: AppColors.ink900,
              ),
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              borderRadius: AppRadius.brPill,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
