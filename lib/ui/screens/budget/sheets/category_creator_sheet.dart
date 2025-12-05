import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/budget_models.dart';
import '../theme/budget_theme.dart';
import '../widgets/common_widgets.dart';

class CategoryCreatorSheet extends StatefulWidget {
  const CategoryCreatorSheet({super.key, required this.onSubmit, this.initial});
  final ValueChanged<BudgetCategory> onSubmit;
  final BudgetCategory? initial;

  @override
  State<CategoryCreatorSheet> createState() => _CategoryCreatorSheetState();
}

class _CategoryCreatorSheetState extends State<CategoryCreatorSheet> {
  late final TextEditingController _nameCtrl;
  late IconData _selectedIcon;
  late Color _selectedColor;

  static const _icons = <IconData>[
    Icons.shopping_bag_outlined,
    Icons.fastfood_outlined,
    Icons.directions_bus_filled_outlined,
    Icons.sports_esports_outlined,
    Icons.movie_outlined,
    Icons.music_note_outlined,
    Icons.pets_outlined,
    Icons.home_outlined,
    Icons.school_outlined,
    Icons.work_outline,
    Icons.local_gas_station_outlined,
    Icons.health_and_safety_outlined,
    Icons.spa_outlined,
    Icons.coffee_outlined,
  ];

  static const _swatches = <Color>[
    Color(0xFFBB86FC),
    Color(0xFFFF8A65),
    Color(0xFFA5D6A7),
    Color(0xFF80CBC4),
    Color(0xFF64B5F6),
    Color(0xFFBA68C8),
    Color(0xFFFFF176),
    Color(0xFF8EB69B),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _selectedIcon = widget.initial?.icon ?? Icons.category_outlined;
    _selectedColor = widget.initial?.color ?? const Color(0xFF8EB69B);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      HapticFeedback.heavyImpact();
      return;
    }
    widget.onSubmit(
      BudgetCategory(name: name, icon: _selectedIcon, color: _selectedColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.initial == null ? 'New category' : 'Edit category',
                  style: const TextStyle(
                    color: BudgetTheme.mintDim,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 12),

                // Name
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  cursorColor: BudgetTheme.mint,
                  style: const TextStyle(
                    color: BudgetTheme.text,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Category name',
                    hintStyle: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: BudgetTheme.mint, width: 1.2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),

                const SizedBox(height: 14),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Icon',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _icons.map((ic) {
                    final sel = ic == _selectedIcon;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedIcon = ic);
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: sel ? 0.12 : 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: sel
                                ? BudgetTheme.mint
                                : Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Icon(ic, color: BudgetTheme.mint, size: 24),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Color',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                ColorRail(
                  colors: _swatches,
                  selected: _selectedColor,
                  onPick: (c) => setState(() => _selectedColor = c),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: BudgetTheme.mint,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _submit,
                        child: Text(
                          widget.initial == null ? 'Create' : 'Save',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
