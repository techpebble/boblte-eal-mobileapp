import 'package:flutter/material.dart';

import 'package:eal_scanner/screens/accountScreen.dart';
import 'package:eal_scanner/screens/dispatches/dispatchListScreen.dart';
import 'package:eal_scanner/screens/homeScreen.dart';
import 'package:eal_scanner/screens/issuance/issuanceListScreen.dart';
import 'package:eal_scanner/screens/usages/usagesListScreen.dart';
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
  late int _index = widget.initialIndex;

  static const _tabs = <_TabSpec>[
    _TabSpec('Home', Icons.home_outlined, Icons.home_rounded, AppColors.blue),
    _TabSpec(
      'Issuance',
      Icons.assignment_turned_in_outlined,
      Icons.assignment_turned_in_rounded,
      AppColors.indigo,
    ),
    _TabSpec(
      'Production',
      Icons.factory_outlined,
      Icons.factory_rounded,
      AppColors.teal,
    ),
    _TabSpec(
      'Dispatch',
      Icons.local_shipping_outlined,
      Icons.local_shipping_rounded,
      AppColors.amber,
    ),
    _TabSpec(
      'Account',
      Icons.person_outline_rounded,
      Icons.person_rounded,
      AppColors.blue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          IssuanceListScreen(),
          UsagesListScreen(),
          DispatchListScreen(),
          AccountScreen(),
        ],
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
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _TabButton(
                      spec: _tabs[i],
                      selected: _index == i,
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
  const _TabSpec(this.label, this.icon, this.activeIcon, this.accent);

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Color accent;
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? spec.activeIcon : spec.icon, size: 22, color: color),
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
