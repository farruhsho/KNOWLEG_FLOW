import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../network/firebase_service.dart';

/// One bottom-navigation tab.
class ShellTab {
  const ShellTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.screenName,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations l) label;

  /// Analytics screen name logged when the tab is selected.
  final String screenName;
}

/// Tab order must match the branches in `AppRouter`.
final List<ShellTab> kShellTabs = [
  ShellTab(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: (l) => l.shellNavHome,
    screenName: 'home',
  ),
  ShellTab(
    icon: Icons.auto_stories_outlined,
    selectedIcon: Icons.auto_stories_rounded,
    label: (l) => l.shellNavLearn,
    screenName: 'learn',
  ),
  ShellTab(
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment_rounded,
    label: (l) => l.shellNavExams,
    screenName: 'exams',
  ),
  ShellTab(
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights_rounded,
    label: (l) => l.shellNavProgress,
    screenName: 'progress',
  ),
  ShellTab(
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    label: (l) => l.shellNavProfile,
    screenName: 'profile',
  ),
];

/// Bottom-tab scaffold for the [StatefulShellRoute]. Branches are built
/// lazily by go_router (PERF-NAV-01), each keeps its own navigation stack,
/// and the tab index comes from the location, so it resets on sign-out
/// (NAV-07).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _selectTab(int index) {
    FirebaseService.logScreenView(kShellTabs[index].screenName);
    navigationShell.goBranch(
      index,
      // Re-tapping the active tab returns to its root.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Future<void> _handleBack(BuildContext context) async {
    // NAV-05: back on a secondary tab returns to Home; on Home it asks and
    // then really exits (Navigator.pop on the last page only broke the
    // router).
    if (navigationShell.currentIndex != 0) {
      _selectTab(0);
      return;
    }
    final l = AppLocalizations.of(context)!;
    final exit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.shellExitTitle),
        content: Text(l.shellExitMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.shellCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.shellExitConfirm),
          ),
        ],
      ),
    );
    if (exit == true) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack(context);
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _selectTab,
          destinations: [
            for (final tab in kShellTabs)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.selectedIcon),
                label: tab.label(l),
                tooltip: '',
              ),
          ],
        ),
      ),
    );
  }
}
