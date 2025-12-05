// lib/ui/screens/diet/diet_log_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/diet_models.dart';
import 'package:kontinuum/providers/diet_provider.dart';
import 'package:kontinuum/ui/screens/diet/fdc_food_search_sheet.dart';
import 'package:kontinuum/core/time/app_clock.dart';

class DietLogSheet extends StatefulWidget {
  const DietLogSheet({
    super.key,
    this.defaultDate,
    this.defaultSlot,
    this.editingEntryId,
  });

  /// if editing, we ignore these and load from entry
  final DateTime? defaultDate;
  final MealSlot? defaultSlot;

  /// if non-null → edit mode
  final String? editingEntryId;

  @override
  State<DietLogSheet> createState() => _DietLogSheetState();
}

class _DietLogSheetState extends State<DietLogSheet> {
  late DateTime _date;
  late MealSlot _slot;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _kcalCtrl = TextEditingController();
  final TextEditingController _pCtrl = TextEditingController();
  final TextEditingController _cCtrl = TextEditingController();
  final TextEditingController _fCtrl = TextEditingController();

  DietEntry? _editingEntry;

  @override
  void initState() {
    super.initState();
    final diet = context.read<DietProvider>();

    if (widget.editingEntryId != null) {
      final entry = diet.getEntryById(widget.editingEntryId!);
      _editingEntry = entry;
      if (entry != null) {
        _date = entry.date;
        _slot = entry.mealSlot;
        _nameCtrl.text = entry.name;
        _kcalCtrl.text = entry.calories.toString();
        _pCtrl.text = entry.protein == 0 ? '' : entry.protein.toString();
        _cCtrl.text = entry.carbs == 0 ? '' : entry.carbs.toString();
        _fCtrl.text = entry.fats == 0 ? '' : entry.fats.toString();
      } else {
        _date = widget.defaultDate ?? AppClock.now();
        _slot = widget.defaultSlot ?? MealSlot.lunch;
      }
    } else {
      _date = widget.defaultDate ?? AppClock.now();
      _slot = widget.defaultSlot ?? MealSlot.lunch;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _kcalCtrl.dispose();
    _pCtrl.dispose();
    _cCtrl.dispose();
    _fCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _editingEntry != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 14,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .22),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              isEditing ? 'Edit entry' : 'Log meal',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 14),
            _dateAndSlotRow(context),
            const SizedBox(height: 12),
            // USDA Database Search Button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // Close this sheet
                showFdcFoodSearchSheet(
                  context,
                  date: _date,
                  mealSlot: _slot,
                );
              },
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Search USDA Database'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB59BFF),
                side: const BorderSide(color: Color(0xFFB59BFF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            _foodsQuickPick(),
            const SizedBox(height: 12),
            _textField('Name', _nameCtrl),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    'Calories (kcal)',
                    _kcalCtrl,
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _textField(
                    'Protein (g)',
                    _pCtrl,
                    keyboard: TextInputType.number,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    'Carbs (g)',
                    _cCtrl,
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _textField(
                    'Fats (g)',
                    _fCtrl,
                    keyboard: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (isEditing)
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        await context
                            .read<DietProvider>()
                            .deleteEntry(_editingEntry!.id);
                        if (mounted) Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                if (isEditing) const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB59BFF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: _onSave,
                    child: Text(isEditing ? 'Save' : 'Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateAndSlotRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date picker
        GestureDetector(
          onTap: () async {
            final now = AppClock.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 1),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Color(0xFFB59BFF),
                      surface: Color(0xFF0E1320),
                      onSurface: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                _date = DateTime(picked.year, picked.month, picked.day);
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF141927),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  DateFormat.yMMMMd().format(_date),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Meal slot chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: MealSlot.values.map((m) {
            final sel = m == _slot;
            return GestureDetector(
              onTap: () => setState(() => _slot = m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFFB59BFF) : const Color(0xFF141927),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  m.label,
                  style: TextStyle(
                    color: sel ? Colors.black : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// small horizontal list of saved foods to auto-fill
  Widget _foodsQuickPick() {
    return Consumer<DietProvider>(
      builder: (context, diet, _) {
        final foods = diet.foods;
        if (foods.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF141927),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'No saved foods yet. Add some in the Foods tab.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          );
        }

        return SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: foods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final f = foods[index];
              return GestureDetector(
                onTap: () => _applyFood(f),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141927),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${f.calories} kcal',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _applyFood(DietFood f) {
    setState(() {
      _nameCtrl.text = f.name;
      _kcalCtrl.text = f.calories.toString();
      _pCtrl.text = f.protein == 0 ? '' : f.protein.toStringAsFixed(0);
      _cCtrl.text = f.carbs == 0 ? '' : f.carbs.toStringAsFixed(0);
      _fCtrl.text = f.fats == 0 ? '' : f.fats.toStringAsFixed(0);
    });
  }

  Widget _textField(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: .55),
          ),
          filled: true,
          fillColor: const Color(0xFF141927),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    final name = _nameCtrl.text.trim();
    final kcal = int.tryParse(_kcalCtrl.text.trim()) ?? 0;
    final p = double.tryParse(_pCtrl.text.trim()) ?? 0;
    final c = double.tryParse(_cCtrl.text.trim()) ?? 0;
    final f = double.tryParse(_fCtrl.text.trim()) ?? 0;

    if (name.isEmpty) return;

    final diet = context.read<DietProvider>();

    if (_editingEntry != null) {
      final updated = DietEntry(
        id: _editingEntry!.id,
        date: _date,
        mealSlot: _slot,
        name: name,
        calories: kcal,
        protein: p,
        carbs: c,
        fats: f,
      );
      await diet.updateEntry(updated);
    } else {
      await diet.addEntry(
        date: _date,
        slot: _slot,
        name: name,
        calories: kcal,
        protein: p,
        carbs: c,
        fats: f,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }
}
