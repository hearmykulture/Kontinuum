import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kontinuum/models/budget_transaction.dart';
import 'package:kontinuum/models/manual_transaction_draft.dart';
import 'package:kontinuum/services/budget_boxes.dart';
import 'package:kontinuum/services/transactions_repository.dart';
import 'package:kontinuum/services/transactions_store.dart';

class TransactionsProvider extends ChangeNotifier {
  bool _loading = false;
  bool get loading => _loading;

  late final StreamSubscription _sub;

  TransactionsProvider() {
    // Re-emit when the tx box changes so UI auto-updates.
    _sub = BudgetBoxes.tx.watch().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  List<BudgetTransaction> get unreviewed =>
      TransactionsStore.unreviewedNewestFirst();

  Future<BudgetTransaction> addManualTransaction(
      ManualTransactionDraft draft) async {
    final txn = await TransactionsStore.addManualTransaction(draft);
    notifyListeners();
    return txn;
  }

  Future<void> refresh({required String userId, String? itemId}) async {
    _loading = true;
    notifyListeners();
    try {
      await TransactionsRepository.refreshForUser(
          userId: userId, itemId: itemId);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
