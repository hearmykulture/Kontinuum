import 'package:kontinuum/models/budget_transaction.dart';
import 'package:kontinuum/models/manual_transaction_draft.dart';
import 'package:kontinuum/services/budget_boxes.dart';
import 'package:kontinuum/services/category_map.dart';

class TransactionsStore {
  /// Upsert a batch of normalized transactions (idempotent).
  /// - Merges `reviewed` from existing entries
  /// - Applies merchant overrides, then API category, then heuristic
  static Future<void> ingestNormalized(List<Map<String, dynamic>> items) async {
    final box = BudgetBoxes.tx;

    // Build id -> existing key map (O(n))
    final keys = box.keys.toList(growable: false);
    final vals = box.values.toList(growable: false);
    final Map<String, dynamic> idToKey = {};
    for (var i = 0; i < vals.length; i++) {
      idToKey[vals[i].id] = keys[i];
    }

    final Map<dynamic, BudgetTransaction> updates = {};
    final List<BudgetTransaction> adds = [];

    for (final j in items) {
      final incoming = BudgetTransaction.fromApi(j);
      final prevKey = idToKey[incoming.id];
      final prev = prevKey != null ? box.get(prevKey) : null;

      final reviewed = prev?.reviewed ?? incoming.reviewed;
      final override = CategoryMap.overrideFor(incoming.merchant);
      final category = override ??
          incoming.category ??
          CategoryMap.heuristic(
            incoming.merchant,
            ((j['categoryPath'] as List?) ?? const [])
                .map((e) => e.toString())
                .toList(),
          );

      final upsert = incoming.copyWith(category: category, reviewed: reviewed);

      if (prevKey != null) {
        updates[prevKey] = upsert;
      } else {
        adds.add(upsert);
      }
    }

    if (updates.isNotEmpty) await box.putAll(updates);
    if (adds.isNotEmpty) await box.addAll(adds);
  }

  /// Mark a transaction reviewed and optionally set a category and persist a merchant override.
  static Future<void> markReviewed({
    required String txnId,
    String? setCategory,
    String? merchantForOverride,
  }) async {
    final box = BudgetBoxes.tx;

    // id -> key lookup (O(n) over current values; acceptable for UI tap)
    final keys = box.keys.toList(growable: false);
    final vals = box.values.toList(growable: false);
    dynamic hitKey;
    for (var i = 0; i < vals.length; i++) {
      if (vals[i].id == txnId) {
        hitKey = keys[i];
        break;
      }
    }
    if (hitKey == null) return;

    final current = box.get(hitKey)!;
    final next = current.copyWith(
      reviewed: true,
      category: setCategory ?? current.category,
    );
    await box.put(hitKey, next);

    if (merchantForOverride != null && setCategory != null) {
      await CategoryMap.setOverride(merchantForOverride, setCategory);
    }
  }

  /// Returns non-removed, unreviewed txns newest first
  static List<BudgetTransaction> unreviewedNewestFirst() {
    final all = BudgetBoxes.tx.values.where((t) => !t.removed && !t.reviewed);
    final list = all.toList()
      ..sort((a, b) {
        final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    return list;
  }

  /// Add a manual transaction created by the user locally
  static Future<BudgetTransaction> addManualTransaction(
    ManualTransactionDraft draft,
  ) async {
    final box = BudgetBoxes.tx;

    // Generate a unique ID for this manual transaction
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = 'manual_${timestamp}_${(0 + 1).toString().padLeft(5, '0')}';

    // Determine isExpense based on flow
    final isExpense = draft.isExpense;

    // Create the BudgetTransaction
    final transaction = BudgetTransaction(
      id: id,
      accountId: draft.accountId ?? 'manual',
      date: draft.date,
      amountCents: draft.amountCents.abs(),
      isExpense: isExpense,
      status: 'posted',
      category: draft.category,
      merchant: draft.title,
      memo: draft.description,
      currency: draft.currency,
      reviewed: true,
      manual: true,
      flow: draft.normalizedFlow,
      accountType: draft.accountType ?? 'manual',
      accountName: draft.accountName,
    );

    // Add to the box and return
    await box.add(transaction);
    return transaction;
  }
}
