import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/signup_page.dart';
import '../../features/accounts/presentation/manage_accounts_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/transactions/presentation/add_transaction_page.dart';
import '../../features/recurrences/presentation/manage_recurrences_page.dart';
import '../../features/recurrences/presentation/recurrences_list_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/statistics/presentation/statistics_page.dart';
import '../../features/members/presentation/manage_members_page.dart';
import '../services/database_service.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isLoggedIn = DatabaseService().isValid;
    final isLoggingIn = state.uri.toString() == '/login';

    if (!isLoggedIn && !isLoggingIn) return '/login';
    if (isLoggedIn && isLoggingIn) return '/';

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const DashboardPage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupPage()),
    GoRoute(
      path: '/accounts',
      builder: (context, state) => const ManageAccountsPage(),
    ),
    GoRoute(
      path: '/add-transaction',
      builder: (context, state) => AddTransactionPage(
        transactionToEdit: state.extra as Map<String, dynamic>?,
      ),
    ),
    GoRoute(
      path: '/recurrences',
      builder: (context, state) => const ManageRecurrencesPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/account-recurrences',
      builder: (context, state) {
        final accountId = state.extra as String;
        return RecurrencesListPage(accountId: accountId);
      },
    ),
    GoRoute(
      path: '/statistics',
      builder: (context, state) => const StatisticsPage(),
    ),
    GoRoute(
      path: '/members',
      builder: (context, state) => const ManageMembersPage(),
    ),
  ],
);
