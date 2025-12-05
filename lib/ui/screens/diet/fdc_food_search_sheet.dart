// lib/ui/screens/diet/fdc_food_search_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/diet_models.dart';
import 'package:kontinuum/providers/diet_provider.dart';
import 'package:kontinuum/services/fdc_service.dart';

/// Shows a bottom sheet to search USDA FoodData Central and add food to a meal.
Future<void> showFdcFoodSearchSheet(
  BuildContext context, {
  required DateTime date,
  required MealSlot mealSlot,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FdcFoodSearchSheet(
      date: date,
      mealSlot: mealSlot,
    ),
  );
}

class FdcFoodSearchSheet extends StatefulWidget {
  final DateTime date;
  final MealSlot mealSlot;

  const FdcFoodSearchSheet({
    super.key,
    required this.date,
    required this.mealSlot,
  });

  @override
  State<FdcFoodSearchSheet> createState() => _FdcFoodSearchSheetState();
}

class _FdcFoodSearchSheetState extends State<FdcFoodSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) return;

    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<DietProvider>().searchFoodsFdc(query);
    });
  }

  Future<void> _addFood(FdcSearchItem item) async {
    // Show servings picker
    final servings = await _showServingsPicker(context, item);
    if (servings == null) return;

    if (!mounted) return;

    final provider = context.read<DietProvider>();
    final entry = provider.toDietEntryFromFdc(
      item,
      date: widget.date,
      mealSlot: widget.mealSlot,
      servings: servings,
    );

    await provider.addEntry(
      date: entry.date,
      slot: entry.mealSlot,
      name: entry.name,
      calories: entry.calories,
      protein: entry.protein,
      carbs: entry.carbs,
      fats: entry.fats,
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // Close sheet
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${entry.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DietProvider>();
    final results = provider.fdcResults;
    final isSearching = provider.isSearchingFdc;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Search USDA Food Database',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search foods...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Results
              Expanded(
                child: isSearching
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.blue),
                      )
                    : results.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isEmpty
                                  ? 'Search for foods above'
                                  : 'No results found',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 16,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  controller: scrollController,
                                  itemCount: results.length,
                                  itemBuilder: (context, index) {
                                    final item = results[index];
                                    return _FoodResultTile(
                                      item: item,
                                      onTap: () => _addFood(item),
                                    );
                                  },
                                ),
                              ),
                              // Attribution footer
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  border: Border(
                                    top: BorderSide(
                                        color: Colors.grey[800]!, width: 1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 14, color: Colors.grey[500]),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Source: USDA FoodData Central',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FoodResultTile extends StatelessWidget {
  final FdcSearchItem item;
  final VoidCallback onTap;

  const _FoodResultTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasNutrition =
        item.calories != null || item.protein != null || item.carbs != null;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Food info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    item.description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Brand (if available)
                  if (item.brandName != null || item.brandOwner != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        item.brandName ?? item.brandOwner ?? '',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                        ),
                      ),
                    ),

                  // Serving size
                  if (item.servingText != null)
                    Text(
                      item.servingText!,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    )
                  else if (item.servingSize != null && item.servingUnit != null)
                    Text(
                      '${item.servingSize}${item.servingUnit}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),

            // Nutrition info
            if (hasNutrition)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.calories != null)
                    Text(
                      '${item.calories!.round()} cal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.protein != null)
                        _MacroChip('P: ${item.protein!.toStringAsFixed(1)}g'),
                      if (item.carbs != null) ...[
                        const SizedBox(width: 4),
                        _MacroChip('C: ${item.carbs!.toStringAsFixed(1)}g'),
                      ],
                      if (item.fat != null) ...[
                        const SizedBox(width: 4),
                        _MacroChip('F: ${item.fat!.toStringAsFixed(1)}g'),
                      ],
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String text;

  const _MacroChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Show a dialog to pick number of servings
Future<double?> _showServingsPicker(
    BuildContext context, FdcSearchItem item) async {
  double servings = 1.0;

  return showDialog<double>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text('Servings',
                style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.description,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.servingText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.servingText!,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.blue),
                      onPressed: () {
                        if (servings > 0.25) {
                          setState(() => servings -= 0.25);
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    Text(
                      servings.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.blue),
                      onPressed: () {
                        if (servings < 20) {
                          setState(() => servings += 0.25);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (item.calories != null)
                  Text(
                    '${(item.calories! * servings).round()} calories',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(servings),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );
}
