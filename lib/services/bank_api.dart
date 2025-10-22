import 'dart:convert';
import 'package:http/http.dart' as http;

/// NOTE:
/// - iOS Simulator can use http://localhost:4001
/// - Android Emulator should use http://10.0.2.2:4001
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:4001',
);

class BankApi {
  static Future<void> syncItem(String itemId) async {
    final uri = Uri.parse('$apiBaseUrl/plaid/sync');
    final res = await http.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'itemId': itemId}),
    );
    if (res.statusCode >= 300) {
      throw Exception('syncItem failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchTransactions(
    String userId, {
    int limit = 500,
  }) async {
    final uri = Uri.parse(
      '$apiBaseUrl/finance/transactions?userId=$userId&limit=$limit',
    );
    final res = await http.get(uri);
    if (res.statusCode >= 300) {
      throw Exception(
          'fetchTransactions failed: ${res.statusCode} ${res.body}');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (j['transactions'] as List? ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    return list;
  }
}
