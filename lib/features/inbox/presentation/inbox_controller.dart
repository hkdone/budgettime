import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/inbox_item.dart';
import '../domain/inbox_match_preview.dart';
import '../domain/inbox_repository.dart';
import '../application/inbox_service.dart';
import '../../transactions/application/reconciliation_service.dart';
import '../../transactions/domain/transaction_repository.dart';
import '../../../core/start_app.dart';
import '../../../core/services/pwa_service.dart';

class InboxState {
  final List<InboxItem> items;
  final Map<String, InboxMatchPreview> matchPreviews;
  final bool isLoading;
  final String? error;

  InboxState({
    this.items = const [],
    this.matchPreviews = const {},
    this.isLoading = false,
    this.error,
  });

  InboxState copyWith({
    List<InboxItem>? items,
    Map<String, InboxMatchPreview>? matchPreviews,
    bool? isLoading,
    String? error,
  }) {
    return InboxState(
      items: items ?? this.items,
      matchPreviews: matchPreviews ?? this.matchPreviews,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class InboxController extends StateNotifier<InboxState> {
  final InboxRepository _repository;
  final InboxService _service;
  final PwaService _pwaService;
  final TransactionRepository _transactionRepo;
  final ReconciliationService _reconciliationService;

  InboxController(
    this._repository,
    this._service,
    this._pwaService,
    this._transactionRepo,
    this._reconciliationService,
  ) : super(InboxState()) {
    refresh();
    _setupRealtime();
  }

  Future<void> _setupRealtime() async {
    _pwaService.requestNotificationPermission();
    await _repository.subscribe(_onNewItem);
  }

  void _onNewItem(Map<String, dynamic> itemData) {
    final item = InboxItem.fromMap(itemData);
    if (state.items.any((i) => i.id == item.id)) return;
    state = state.copyWith(items: [item, ...state.items]);
    _enrichMatchesForItems([item]);
    final label = item.label.isNotEmpty ? item.label : 'Nouveau message';
    _pwaService.showNotification('BudgetTime — Boîte de réception', label);
  }

  @override
  void dispose() {
    _repository.unsubscribe();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final rawItems = await _repository.getUnprocessedItems();
      var items = rawItems.map((e) => InboxItem.fromMap(e)).toList();
      final previews = await _buildMatchPreviews(items);
      items = _sortItems(items, previews);
      state = state.copyWith(
        items: items,
        matchPreviews: previews,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _enrichMatchesForItems(List<InboxItem> newItems) async {
    final previews = Map<String, InboxMatchPreview>.from(state.matchPreviews);
    for (final item in newItems) {
      final preview = await _matchPreviewForItem(item);
      if (preview != null) {
        previews[item.id] = preview;
      }
    }
    final sorted = _sortItems([...state.items], previews);
    state = state.copyWith(items: sorted, matchPreviews: previews);
  }

  Future<Map<String, InboxMatchPreview>> _buildMatchPreviews(
    List<InboxItem> items,
  ) async {
    final previews = <String, InboxMatchPreview>{};
    for (final item in items) {
      final preview = await _matchPreviewForItem(item);
      if (preview != null) {
        previews[item.id] = preview;
      }
    }
    return previews;
  }

  Future<InboxMatchPreview?> _matchPreviewForItem(InboxItem item) async {
    final accountId = item.metadata?['local_account_id'] as String?;
    final amount = item.amount.abs();
    if (accountId == null || amount <= 0) return null;

    final previewData = getPreview(item);
    final type =
        previewData?['type'] as String? ??
        (item.amount >= 0 ? 'income' : 'expense');

    final candidates = await _transactionRepo.getTransactionsForReconciliation(
      accountId: accountId,
      type: type,
      inboxDate: item.date,
    );

    final ranked = _reconciliationService.rankMatches(
      candidates: candidates,
      actualAmount: amount,
      actualDate: item.date,
    );

    if (ranked.isEmpty) return null;

    final best = ranked.first;
    return InboxMatchPreview(
      projectedLabel: best.label,
      projectedAmount: best.projectedAmount,
      amountDelta: best.amountDelta,
      matchCount: ranked.length,
    );
  }

  List<InboxItem> _sortItems(
    List<InboxItem> items,
    Map<String, InboxMatchPreview> previews,
  ) {
    final sorted = [...items];
    sorted.sort((a, b) {
      final aMatch = previews.containsKey(a.id);
      final bMatch = previews.containsKey(b.id);
      if (aMatch != bMatch) return aMatch ? -1 : 1;
      return b.date.compareTo(a.date);
    });
    return sorted;
  }

  Map<String, dynamic>? getPreview(InboxItem item) {
    final map = {
      'id': item.id,
      'date': item.date.toIso8601String(),
      'label': item.label,
      'amount': item.amount,
      'user': item.user,
      'is_processed': item.isProcessed,
      'raw_payload': item.rawPayload,
      'metadata': item.metadata,
    };
    return _service.previewItem(map);
  }

  Future<void> deleteItem(String id) async {
    final previousItems = state.items;
    final previousPreviews = state.matchPreviews;

    // Retrait immédiat de l'UI (évite les double-clics pendant le refresh).
    state = state.copyWith(
      items: state.items.where((i) => i.id != id).toList(),
      matchPreviews: Map<String, InboxMatchPreview>.from(state.matchPreviews)
        ..remove(id),
    );

    try {
      await _repository.markAsProcessed(id);
      // Rafraîchit en arrière-plan pour resynchroniser proprement la liste
      // (utile si d'autres items ont changé côté serveur).
      Future.microtask(() => refresh());
    } catch (e) {
      state = state.copyWith(
        items: previousItems,
        matchPreviews: previousPreviews,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteAll() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _repository.deleteAll();
      await refresh();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final inboxControllerProvider =
    StateNotifierProvider<InboxController, InboxState>((ref) {
      final repo = ref.watch(inboxRepositoryProvider);
      final service = ref.watch(inboxServiceProvider);
      final pwaService = ref.watch(pwaServiceProvider);
      final transactionRepo = ref.watch(transactionRepositoryProvider);
      final reconciliationService = ref.watch(reconciliationServiceProvider);
      return InboxController(
        repo,
        service,
        pwaService,
        transactionRepo,
        reconciliationService,
      );
    });
