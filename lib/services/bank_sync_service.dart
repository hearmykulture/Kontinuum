import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kontinuum/services/budget_boxes.dart';

class BankSyncService {
  BankSyncService({required this.baseUrl, required this.userId});
  final String baseUrl;
  final String userId;

  String get _lastKey => 'lastSyncAt:$userId';

  /// Returns number of items requested to sync.
  Future<int> syncAll() async {
    // 1) discover itemIds from accounts
    final accRes = await http.get(Uri.parse(
      '$baseUrl/finance/accounts?userId=$userId&includeBalances=false',
    ));
    if (accRes.statusCode != 200) {
      throw 'GET /finance/accounts ${accRes.statusCode}: ${accRes.body}';
    }
    final accJson = json.decode(accRes.body) as Map<String, dynamic>;
    final accounts = (accJson['accounts'] as List? ?? const []);
    final itemIds = <String>{};
    for (final a in accounts) {
      final j = (a as Map).cast<String, dynamic>();
      final id = j['itemId'] as String?;
      if (id != null && id.isNotEmpty) itemIds.add(id);
    }
    if (itemIds.isEmpty) return 0;

    // 2) POST /plaid/sync for each
    for (final id in itemIds) {
      await http.post(
        Uri.parse('$baseUrl/plaid/sync'),
        headers: {'content-type': 'application/json'},
        body: json.encode({'itemId': id}),
      );
    }

    // 3) remember last sync
    BudgetBoxes.meta.put(_lastKey, DateTime.now().toIso8601String());
    return itemIds.length;
  }

  static DateTime? lastSyncAt(String userId) {
    final raw = BudgetBoxes.meta.get('lastSyncAt:$userId') as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }
}
