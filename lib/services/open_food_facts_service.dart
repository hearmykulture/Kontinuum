import 'dart:convert';
import 'package:http/http.dart' as http;

/// Super light wrapper over Open Food Facts.
/// Docs: https://world.openfoodfacts.org/data
class OpenFoodFactsService {
  OpenFoodFactsService._();
  static final OpenFoodFactsService instance = OpenFoodFactsService._();

  static const String _base = 'https://world.openfoodfacts.org';

  /// Text search (name, brand, etc.)
  Future<List<OffProduct>> search(String query, {int page = 1}) async {
    final uri = Uri.parse('$_base/cgi/search.pl').replace(queryParameters: {
      'search_terms': query,
      'search_simple': '1',
      'action': 'process',
      'page_size': '20',
      'page': '$page',
      'json': '1',
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final products = (data['products'] as List? ?? [])
        .map((p) => OffProduct.fromJson(p as Map<String, dynamic>))
        .where((p) => p.name.isNotEmpty)
        .toList();
    return products;
  }

  /// Barcode lookup
  Future<OffProduct?> fetchByBarcode(String barcode) async {
    final uri = Uri.parse('$_base/api/v0/product/$barcode.json');
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 1) return null;
    return OffProduct.fromJson(data['product'] as Map<String, dynamic>);
  }
}

class OffProduct {
  final String name;
  final String? brand;
  final int? kcal; // per 100g
  final double protein;
  final double carbs;
  final double fats;

  OffProduct({
    required this.name,
    this.brand,
    this.kcal,
    this.protein = 0,
    this.carbs = 0,
    this.fats = 0,
  });

  factory OffProduct.fromJson(Map<String, dynamic> json) {
    final nutriments = json['nutriments'] as Map<String, dynamic>?;

    int? kcal;
    double protein = 0.0;
    double carbs = 0.0;
    double fats = 0.0;

    if (nutriments != null) {
      final dynamic kcalDyn = nutriments['energy-kcal_100g'] ??
          nutriments['energy-kcal_serving'] ??
          nutriments['energy-kcal'];
      if (kcalDyn is num) {
        kcal = kcalDyn.toInt();
      }

      final dynamic pDyn = nutriments['proteins_100g'];
      final dynamic cDyn = nutriments['carbohydrates_100g'];
      final dynamic fDyn = nutriments['fat_100g'];

      protein = pDyn is num ? pDyn.toDouble() : 0.0;
      carbs = cDyn is num ? cDyn.toDouble() : 0.0;
      fats = fDyn is num ? fDyn.toDouble() : 0.0;
    }

    final name = (json['product_name'] ??
            json['generic_name'] ??
            json['generic_name_en'] ??
            '')
        .toString();

    return OffProduct(
      name: name,
      brand: (json['brands'] ?? '').toString(),
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fats: fats,
    );
  }
}
