// lib/services/fdc_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Data Transfer Object for USDA FoodData Central search results.
class FdcSearchItem {
  final int fdcId;
  final String description; // e.g., "IHOP, Sirloin Steak Tips (Entrée)"
  final String dataType; // "Branded", "Survey (FNDDS)", "SR Legacy", "Foundation"
  final String? brandOwner; // for Branded
  final String? brandName; // for Branded
  final String? gtinUpc; // barcode if available
  final double? servingSize; // label serving amount (if provided)
  final String? servingUnit; // "g", "ml", etc.
  final String? servingText; // householdServingFullText (e.g., "1 sandwich (140 g)")
  // Macros (prefer labelNutrients; fallback to foodNutrients)
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;

  const FdcSearchItem({
    required this.fdcId,
    required this.description,
    required this.dataType,
    this.brandOwner,
    this.brandName,
    this.gtinUpc,
    this.servingSize,
    this.servingUnit,
    this.servingText,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
  });

  /// Build from a single item in /foods/search results.
  factory FdcSearchItem.fromSearchJson(Map<String, dynamic> j) {
    // 1) Prefer labelNutrients (per serving for branded foods)
    final ln = j['labelNutrients'] as Map<String, dynamic>?;
    double? getLabelNutrient(String key) {
      final v = ln?[key];
      if (v is Map && v['value'] is num) return v['value'] as num.toDouble();
      return null;
    }

    // 2) Fallback to foodNutrients (often per 100 g for non-branded)
    double? fromFoodNutrients(List<dynamic> fns, List<String> wantedNames) {
      for (final fn in fns) {
        final nutrient = (fn as Map)['nutrient'] as Map?;
        // Some responses use flattened fields (name/unitName) directly on fn
        final name = nutrient?['name'] ?? fn['nutrientName'])?.toString();
        final value = fn['amount'] ?? fn['value']);
        if (name != null &&
            wantedNames
                .map((s) => s.toLowerCase())
                .contains(name.toLowerCase()) &&
            value is num) {
          return value.toDouble();
        }
      }
      return null;
    }

    final foodNutrients = j['foodNutrients'] is List
        ? (j['foodNutrients'] as List).cast<dynamic>()
        : <dynamic>[];

    // Try label first, then fallback to common nutrient names.
    final calories = getLabelNutrient('calories') ??
        fromFoodNutrients(
            foodNutrients, const ['Energy', 'Energy (Atwater General Factors)']);
    final protein = getLabelNutrient('protein') ??
        fromFoodNutrients(foodNutrients, const ['Protein']);
    final carbs = getLabelNutrient('carbohydrates') ??
        fromFoodNutrients(
            foodNutrients, const ['Carbohydrate, by difference']);
    final fat = getLabelNutrient('fat') ??
        fromFoodNutrients(foodNutrients, const ['Total lipid (fat)']);

    return FdcSearchItem(
      fdcId: (j['fdcId'] as num).toInt(),
      description: (j['description'] ?? '').toString(),
      dataType: (j['dataType'] ?? '').toString(),
      brandOwner: (j['brandOwner'] as String?)?.trim(),
      brandName: (j['brandName'] as String?)?.trim(),
      gtinUpc: (j['gtinUpc'] as String?)?.trim(),
      servingSize:
          (j['servingSize'] is num) ? (j['servingSize'] as num).toDouble() : null,
      servingUnit: (j['servingSizeUnit'] as String?)?.trim(),
      servingText: (j['householdServingFullText'] as String?)?.trim(),
      calories: calories?.toDouble(),
      protein: protein?.toDouble(),
      carbs: carbs?.toDouble(),
      fat: fat?.toDouble(),
    );
  }
}

/// Service for USDA FoodData Central API integration.
/// Docs: https://fdc.nal.usda.gov/api-guide.html
class FdcService {
  static const _base = 'https://api.nal.usda.gov/fdc/v1';
  final String apiKey;
  final http.Client _client;

  FdcService({
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Keyword search. dataTypes default to Branded + Survey + SR Legacy + Foundation.
  Future<List<FdcSearchItem>> searchFoods(
    String query, {
    int pageSize = 25,
    int pageNumber = 1,
    List<String> dataTypes = const [
      'Branded',
      'Survey (FNDDS)',
      'SR Legacy',
      'Foundation'
    ],
    String? brandOwner,
    String? brandName,
    String? sortBy, // e.g., "dataType", "description", "fdcId", "publishedDate"
    String? sortOrder, // "asc" | "desc"
  }) async {
    final uri = Uri.parse('$_base/foods/search').replace(queryParameters: {
      'api_key': apiKey,
      'query': query,
      'pageSize': '$pageSize',
      'pageNumber': '$pageNumber',
      if (brandOwner != null && brandOwner.isNotEmpty)
        'brandOwner': brandOwner,
      if (brandName != null && brandName.isNotEmpty) 'brandName': brandName,
      if (sortBy != null) 'sortBy': sortBy,
      if (sortOrder != null) 'sortOrder': sortOrder,
      // Per API Guide, dataType can be provided as GET (comma-separated) or POST (array)
      'dataType': dataTypes.join(','),
    });

    final res = await _client.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode == 429) {
      throw Exception(
          'FDC rate limit hit (429). Try later or reduce request rate.');
    }
    if (res.statusCode != 200) {
      throw Exception('FDC search failed (${res.statusCode}): ${res.body}');
    }

    final body = json.decode(res.body) as Map<String, dynamic>;
    final foods = body['foods'] is List
        ? (body['foods'] as List).cast<dynamic>()
        : <dynamic>[];
    return foods
        .map((e) => FdcSearchItem.fromSearchJson(e as Map<String, dynamic>))
        .toList();
  }

  /// UPC/GTIN barcode lookup. FDC does not have a separate /gtin endpoint;
  /// using search with the UPC exact query works well for Branded data.
  Future<FdcSearchItem?> searchByBarcode(String gtinUpc) async {
    final results = await searchFoods(
      gtinUpc,
      dataTypes: const ['Branded'],
      pageSize: 1,
    );
    return results.isEmpty ? null : results.first;
  }

  /// Fetch full food details by FDC ID (if you want deeper nutrient panels).
  Future<Map<String, dynamic>> getFood(int fdcId) async {
    final uri = Uri.parse('$_base/food/$fdcId').replace(queryParameters: {
      'api_key': apiKey,
    });
    final res = await _client.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode == 429) {
      throw Exception(
          'FDC rate limit hit (429). Try later or reduce request rate.');
    }
    if (res.statusCode != 200) {
      throw Exception('FDC food fetch failed (${res.statusCode}): ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  void dispose() {
    _client.close();
  }
}
