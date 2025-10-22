import 'package:kontinuum/services/bank_api.dart';
import 'package:kontinuum/services/transactions_store.dart';

class TransactionsRepository {
  /// If [itemId] is provided, we’ll ask server to sync (manual refresh / post-link).
  static Future<void> refreshForUser({
    required String userId,
    String? itemId,
    int limit = 500,
  }) async {
    if (itemId != null) {
      await BankApi.syncItem(itemId);
    }
    final list = await BankApi.fetchTransactions(userId, limit: limit);
    await TransactionsStore.ingestNormalized(list);
  }
}
