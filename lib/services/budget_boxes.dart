import 'package:hive_flutter/hive_flutter.dart';
import 'package:kontinuum/models/budget_transaction.dart';
import 'package:kontinuum/models/merchant_override.dart';

class BudgetBoxes {
  static const txBoxName = 'budgetTransactionsBox';
  static const overrideBoxName = 'budgetCategoryOverridesBox';

  // NEW: meta box for lightweight flags/timestamps
  static const metaBoxName = 'budgetBankMetaBox';

  /// Call after `Hive.initFlutter()`.
  static Future<void> init() async {
    // Adapters
    if (!Hive.isAdapterRegistered(40)) {
      Hive.registerAdapter<BudgetTransaction>(BudgetTransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(41)) {
      Hive.registerAdapter<MerchantOverride>(MerchantOverrideAdapter());
    }

    // Boxes
    if (!Hive.isBoxOpen(txBoxName)) {
      await Hive.openBox<BudgetTransaction>(txBoxName);
    }
    if (!Hive.isBoxOpen(overrideBoxName)) {
      await Hive.openBox<MerchantOverride>(overrideBoxName);
    }
    if (!Hive.isBoxOpen(metaBoxName)) {
      await Hive.openBox(metaBoxName); // dynamic values ok
    }
  }

  static Box<BudgetTransaction> get tx =>
      Hive.box<BudgetTransaction>(txBoxName);

  static Box<MerchantOverride> get overrides =>
      Hive.box<MerchantOverride>(overrideBoxName);

  // NEW
  static Box get meta => Hive.box(metaBoxName);
}
