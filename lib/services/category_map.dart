import 'package:kontinuum/models/merchant_override.dart';
import 'package:kontinuum/services/budget_boxes.dart';

class CategoryMap {
  /// O(1) lookup by normalized merchant key.
  static String? overrideFor(String? merchant) {
    final key = MerchantOverride.keyFor(merchant);
    if (key.isEmpty) return null;
    return BudgetBoxes.overrides.get(key)?.category;
  }

  /// Upsert override under the merchantKey as the Hive key.
  static Future<void> setOverride(String merchant, String category) async {
    final key = MerchantOverride.keyFor(merchant);
    if (key.isEmpty) return;
    final obj = MerchantOverride(
      merchantKey: key,
      category: category,
      updatedAt: DateTime.now(),
    );
    await BudgetBoxes.overrides.put(key, obj);
  }

  /// Fallback heuristic if no override and API didn't pick a category.
  static String? heuristic(String? merchant, List<String> categoryPath) {
    final m = (merchant ?? '').toLowerCase();
    if (m.contains('uber') || m.contains('lyft')) return 'Transportation';
    if (m.contains('starbucks') || m.contains('coffee'))
      return 'Food and Drink';
    if (m.contains('united') || m.contains('delta') || m.contains('airlines')) {
      return 'Travel';
    }
    if (categoryPath.isNotEmpty) return categoryPath.first;
    return null;
  }
}
