import 'package:flutter/material.dart';

import 'package:eal_scanner/screens/accountScreen.dart';
import 'package:eal_scanner/screens/dispatches/dispatchListScreen.dart';
import 'package:eal_scanner/screens/homeScreen.dart';
import 'package:eal_scanner/screens/issuance/issuanceListScreen.dart';
import 'package:eal_scanner/screens/usages/usagesListScreen.dart';
import 'package:eal_scanner/services/authService.dart';
import 'package:eal_scanner/theme/app_tokens.dart';

/// The app's navigation spine.
///
/// The old build opened on a dashboard of three cards: every module cost a tap
/// in and a back out, and there was no way to cross from production to
/// dispatch without returning to the top. Persistent tabs put all three one
/// tap from anywhere, and each tab keeps its own scroll and filter state.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex.clamp(0, _tabs.length - 1);

  @override
  void initState() {
    super.initState();
    // The role is cached from the sign-in and a token lasts a year, so an
    // admin changing it would otherwise never reach the app. Re-read at the
    // start, here rather than on the account screen, because this is what
    // the tabs are built from: the bar settles once, in the first moment,
    // instead of changing under someone later.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AuthService.refreshUser();
      if (mounted) setState(() {});
    });
  }

  /// The tabs this account can actually use.
  ///
  /// Every one of them opens by asking the server for a list, and the server
  /// refuses where the role does not allow it. A tab that can only ever show
  /// a refusal is worse than no tab: it reads as something broken rather
  /// than something this account does not do. The permission each one needs
  /// is the one its own route asks for, and the server accepts any of
  /// several keys for the same list, so these do too.
  static final List<_TabSpec> _tabs = [
    const _TabSpec(
      'Home',
      Icons.home_outlined,
      Icons.home_rounded,
      AppColors.blue,
      needs: ['dashboard:view'],
    ),
    const _TabSpec(
      'Issuance',
      Icons.assignment_turned_in_outlined,
      Icons.assignment_turned_in_rounded,
      AppColors.indigo,
      needs: ['issuance:view', 'stock:view'],
    ),
    const _TabSpec(
      'Production',
      Icons.factory_outlined,
      Icons.factory_rounded,
      AppColors.teal,
      needs: ['usage:view', 'finished:view'],
    ),
    const _TabSpec(
      'Dispatch',
      Icons.local_shipping_outlined,
      Icons.local_shipping_rounded,
      AppColors.amber,
      needs: ['dispatch:view'],
    ),
    // Settings and the sign-out. Nothing on it asks the server for anything
    // the role could be refused, so it is always there.
    const _TabSpec(
      'Account',
      Icons.person_outline_rounded,
      Icons.person_rounded,
      AppColors.blue,
      needs: [],
    ),
  ];

  static Widget _screenFor(String label) {
    switch (label) {
      case 'Home':
        return const HomeScreen();
      case 'Issuance':
        return const IssuanceListScreen();
      case 'Production':
        return const UsagesListScreen();
      case 'Dispatch':
        return const DispatchListScreen();
      default:
        return const AccountScreen();
    }
  }

  List<_TabSpec> get _allowed => _tabs
      .where((t) => t.needs.isEmpty || AuthService.canAny(t.needs))
      .toList();

  @override
  Widget build(BuildContext context) {
    final tabs = _allowed;
    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: IndexedStack(
        index: index,
        children: [for (final tab in tabs) _screenFor(tab.label)],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _TabButton(
                      spec: tabs[i],
                      selected: index == i,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(
    this.label,
    this.icon,
    this.activeIcon,
    this.accent, {
    required this.needs,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Color accent;

  /// Any one of these is enough, as on the route this tab's list calls.
  final List<String> needs;
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? spec.accent : AppColors.ink500;

    return Semantics(
      selected: selected,
      button: true,
      label: spec.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            // Without this the Column fills the height it is offered, which
            // stretches the whole bar to the full screen and leaves the body
            // with nothing.
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? spec.activeIcon : spec.icon,
                size: 22,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
