import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../utils/responsive_breakpoints.dart';
import '../../features/inbox/presentation/inbox_controller.dart';

/// Navigation latérale (≥600 px) ou barre du bas (<600 px).
class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static bool showsMobileNav(String location) {
    final path = Uri.parse(location).path;
    if (path == '/') return true;
    if (path.startsWith('/stats')) return true;
    if (path == '/inbox') return true;
    if (path == '/settings') return true;
    return false;
  }

  int _selectedIndex(String location) {
    final path = Uri.parse(location).path;
    if (path.startsWith('/stats')) return 1;
    if (path == '/inbox') return 2;
    if (path == '/settings') return 3;
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
    final location = GoRouterState.of(context).uri.toString();
    final inboxCount = ref.watch(inboxControllerProvider).items.length;
    final selectedIndex = _selectedIndex(location);

    if (context.isCompact) {
      final showNav = showsMobileNav(location);
      return Column(
        children: [
          Expanded(child: child),
          if (showNav)
            SafeArea(
              top: false,
              child: NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (i) =>
                    _onDestinationSelected(context, i),
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Accueil',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: 'Analyse',
                  ),
                  NavigationDestination(
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
                    label: 'Inbox',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Paramètres',
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Row(
      children: [
        NavigationRail(
          selectedIndex: selectedIndex,
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
