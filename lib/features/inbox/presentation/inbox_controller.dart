import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/inbox_item.dart';
import '../domain/inbox_repository.dart';
import '../application/inbox_service.dart';
import '../../../core/start_app.dart';

class InboxState {
  final List<InboxItem> items;
  final bool isLoading;
  final String? error;

  InboxState({this.items = const [], this.isLoading = false, this.error});

  InboxState copyWith({
    List<InboxItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return InboxState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class InboxController extends StateNotifier<InboxState> {
  final InboxRepository _repository;
  final InboxService _service;

  InboxController(this._repository, this._service) : super(InboxState()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final rawItems = await _repository.getUnprocessedItems();
      final items = rawItems.map((e) => InboxItem.fromMap(e)).toList();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Map<String, dynamic>? getPreview(InboxItem item) {
    // Convert InboxItem back to map for the service
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
    try {
      await _repository.markAsProcessed(id);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final inboxControllerProvider =
    StateNotifierProvider<InboxController, InboxState>((ref) {
      final repo = ref.watch(inboxRepositoryProvider);
      final service = ref.watch(inboxServiceProvider);
      return InboxController(repo, service);
    });
