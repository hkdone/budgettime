import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/signup_page.dart';
import '../../features/accounts/presentation/manage_accounts_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/transactions/presentation/add_transaction_page.dart';
import '../../features/recurrences/presentation/manage_recurrences_page.dart';
import '../../features/recurrences/presentation/recurrences_list_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/members/presentation/manage_members_page.dart';
import '../../features/dashboard/presentation/stats_page.dart';
import '../../features/dashboard/presentation/stats_trend_page.dart';
import '../services/database_service.dart';

/// Notifie GoRouter à chaque changement d'état d'authentification PocketBase.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier() {
    DatabaseService().pb.authStore.onChange.listen((_) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final isLoggedIn = DatabaseService().isValid;
    final isLoggingIn = state.uri.toString() == '/login';
    if (!isLoggedIn && !isLoggingIn) return '/login';
    if (isLoggedIn && isLoggingIn) return '/';
    return null;
  }
}

final _routerNotifier = RouterNotifier();

/// Transition par défaut : fade + glissement vers le haut (150 ms).
Page<void> _buildPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeOut).animate(animation),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(CurveTween(curve: Curves.easeOut).animate(animation)),
          child: child,
        ),
      );
    },
  );
}

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: _routerNotifier,
  redirect: _routerNotifier.redirect,
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => _buildPage(state, const DashboardPage()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _buildPage(state, const LoginPage()),
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (context, state) => _buildPage(state, const SignupPage()),
    ),
    GoRoute(
      path: '/accounts',
      pageBuilder: (context, state) =>
          _buildPage(state, const ManageAccountsPage()),
    ),
    GoRoute(
      path: '/add-transaction',
      pageBuilder: (context, state) => _buildPage(
        state,
        AddTransactionPage(
          transactionToEdit: state.extra as Map<String, dynamic>?,
        ),
      ),
    ),
    GoRoute(
      path: '/recurrences',
      pageBuilder: (context, state) =>
          _buildPage(state, const ManageRecurrencesPage()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => _buildPage(state, const SettingsPage()),
    ),
    GoRoute(
      path: '/account-recurrences',
      pageBuilder: (context, state) {
        final accountId = state.extra as String;
        return _buildPage(state, RecurrencesListPage(accountId: accountId));
      },
    ),
    GoRoute(
      path: '/members',
      pageBuilder: (context, state) =>
          _buildPage(state, const ManageMembersPage()),
    ),
    GoRoute(
      path: '/stats',
      pageBuilder: (context, state) => _buildPage(state, const StatsPage()),
    ),
    GoRoute(
      path: '/stats-trend',
      pageBuilder: (context, state) =>
          _buildPage(state, const StatsTrendPage()),
    ),
  ],
);
