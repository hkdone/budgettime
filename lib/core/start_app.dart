import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/router/router.dart';
import '../../core/services/database_service.dart';
import '../features/auth/data/auth_repository_impl.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/inbox/application/inbox_service.dart';
import '../features/inbox/data/inbox_repository_impl.dart';
import '../features/inbox/domain/inbox_repository.dart';
import '../features/settings/data/settings_repository_impl.dart';
import '../features/settings/domain/settings_repository.dart';
import '../features/transactions/data/transaction_repository_impl.dart';
import '../features/transactions/domain/transaction_repository.dart';
import '../features/categories/data/category_repository_impl.dart';
import '../features/categories/domain/category_repository.dart';
import '../features/members/data/member_repository_impl.dart';
import '../features/members/domain/member_repository.dart';

// Services
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

// Repositories
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(databaseServiceProvider));
});

// Settings Repository
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(ref.watch(databaseServiceProvider));
});

// Transaction Repository
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl(ref.watch(databaseServiceProvider));
});

// Category Repository
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(ref.watch(databaseServiceProvider));
});

// Inbox Repository
final inboxRepositoryProvider = Provider<InboxRepository>((ref) {
  return InboxRepositoryImpl(ref.watch(databaseServiceProvider));
});

// Member Repository
final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepositoryImpl(ref.watch(databaseServiceProvider));
});

// Inbox Service
final inboxServiceProvider = Provider<InboxService>((ref) {
  return InboxService(
    ref.watch(inboxRepositoryProvider),
    ref.watch(transactionRepositoryProvider),
  );
});

// Router
final routerProvider = Provider((ref) {
  return router;
});
