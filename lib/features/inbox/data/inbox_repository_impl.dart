import '../../../core/services/database_service.dart';
import '../domain/inbox_repository.dart';

class InboxRepositoryImpl implements InboxRepository {
  final DatabaseService _dbService;

  InboxRepositoryImpl(this._dbService);

  @override
  Future<List<dynamic>> getUnprocessedItems() async {
    final user = _dbService.pb.authStore.record;
    if (user == null) return [];

    final records = await _dbService.pb
        .collection('raw_inbox')
        .getFullList(
          filter: 'user = "${user.id}" && is_processed = false',
          sort: '-received_at',
        );

    return records.map((e) => e.data..['id'] = e.id).toList();
  }

  @override
  Future<void> markAsProcessed(String id) async {
    await _dbService.pb
        .collection('raw_inbox')
        .update(
          id,
          body: {
            'is_processed': true,
            'error_message': null, // Clear error if any
          },
        );
  }

  @override
  Future<void> markAsError(String id, String errorMessage) async {
    await _dbService.pb
        .collection('raw_inbox')
        .update(
          id,
          body: {
            'is_processed':
                false, // Keep it unprocessed ? Or maybe processed but with error?
            // Strategy: Keep unprocessed so we can retry or manual fix, but add error tag.
            // Actually, simple flows usually want to stop retrying infinitely.
            // Let's flagging it but maybe keep is_processed false for now to allow manual review.
            'error_message': errorMessage,
          },
        );
  }
}
