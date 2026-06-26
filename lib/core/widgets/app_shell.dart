import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../utils/responsive_breakpoints.dart';
import '../../features/inbox/presentation/inbox_controller.dart';

/// Navigation latérale sur grand écran ; invisible sur mobile.
class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _selectedIndex(String location) {
    if (location.startsWith('/stats')) return 1;
    if (location.startsWith('/inbox')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/stats');
      case 2:
        context.go('/inbox');
      case 3:
        context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (context.isCompact) {
      return child;
    }

    final location = GoRouterState.of(context).uri.toString();
    final inboxCount = ref.watch(inboxControllerProvider).items.length;

    return Row(
      children: [
        NavigationRail(
          selectedIndex: _selectedIndex(location),
          onDestinationSelected: (i) => _onDestinationSelected(context, i),
          labelType: context.isExpanded
              ? NavigationRailLabelType.all
              : NavigationRailLabelType.selected,
          destinations: [
            const NavigationRailDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: Text('Accueil'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: Text('Analyse'),
            ),
            NavigationRailDestination(
              icon: Badge.count(
                count: inboxCount,
                isLabelVisible: inboxCount > 0,
                child: const Icon(Icons.inbox_outlined),
              ),
              selectedIcon: Badge.count(
                count: inboxCount,
                isLabelVisible: inboxCount > 0,
                child: const Icon(Icons.inbox),
              ),
              label: const Text('Inbox'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: Text('Paramètres'),
            ),
          ],
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: child),
      ],
    );
  }
}
