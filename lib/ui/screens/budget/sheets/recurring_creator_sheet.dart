import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/budget_models.dart';
import '../theme/budget_theme.dart';
import '../widgets/common_widgets.dart';

class RecurringCreatorSheet extends StatefulWidget {
  const RecurringCreatorSheet({
    super.key,
    required this.onSubmit,
    this.initial,
    required this.categories,
  });
  final ValueChanged<RecurringExpense> onSubmit;
  final RecurringExpense? initial;
  final List<BudgetCategory> categories;

  @override
  State<RecurringCreatorSheet> createState() => _RecurringCreatorSheetState();
}

class _RecurringCreatorSheetState extends State<RecurringCreatorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late Recurrence _cadence;
  late IconData _selectedIcon;
  late Color _selectedColor;
  BudgetCategory? _selectedCategory;

  static const _icons = <IconData>[
    Icons.receipt_long_outlined,
    Icons.subscriptions_outlined,
    Icons.wifi_outlined,
    Icons.electric_bolt_outlined,
    Icons.water_drop_outlined,
    Icons.local_phone_outlined,
    Icons.tv_outlined,
    Icons.home_outlined,
    Icons.car_rental_outlined,
    Icons.music_note_outlined,
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
    _amountCtrl = TextEditingController(
      text: widget.initial == null
          ? ''
          : (widget.initial!.amountCents / 100).toStringAsFixed(2),
    );
    _cadence = widget.initial?.cadence ?? Recurrence.monthly;
    _selectedIcon = widget.initial?.icon ?? Icons.subscriptions_outlined;
    _selectedColor = widget.initial?.color ?? const Color(0xFF8EB69B);
    _selectedCategory = widget.initial?.category;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (_selectedCategory == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.black.withOpacity(0.9),
          content: const Text(
            'Please choose a category for this expense.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
      return;
    }

    final raw = _amountCtrl.text.replaceAll(RegExp(r'[^\d.]'), '');
    final parsed = double.tryParse(raw) ?? 0.0;
    final cents = (parsed * 100).round();

    widget.onSubmit(
      RecurringExpense(
        name: name,
        amountCents: cents,
        cadence: _cadence,
        icon: _selectedIcon,
        color: _selectedColor,
        category: _selectedCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final money = NumberFormat.currency(symbol: '\$');

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
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.initial == null
                      ? 'New recurring expense'
                      : 'Edit recurring expense',
                  style: const TextStyle(
                    color: BudgetTheme.mintDim,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  cursorColor: BudgetTheme.mint,
                  style: const TextStyle(
                    color: BudgetTheme.text,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: _inputDecoration('Name (e.g., Phone bill)'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  cursorColor: BudgetTheme.mint,
                  style: const TextStyle(
                    color: BudgetTheme.text,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: _inputDecoration('Amount (e.g., 49.99)')
                      .copyWith(prefixText: '\$'),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d\.\,]')),
                  ],
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 14),
                _label('Cadence'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in Recurrence.values)
                      _chip(
                        label: labelForRecurrence(c),
                        selected: _cadence == c,
                        onTap: () => setState(() => _cadence = c),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _label('Category (required)'),
                if (widget.categories.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No categories yet',
                      style: TextStyle(color: Colors.white60),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in widget.categories)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedCategory = c);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                  _selectedCategory?.name == c.name
                                      ? 0.18
                                      : 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedCategory?.name == c.name
                                    ? c.color
                                    : Colors.white.withOpacity(0.12),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: c.color,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(c.icon, size: 16, color: BudgetTheme.mint),
                                const SizedBox(width: 6),
                                Text(
                                  c.name,
                                  style: const TextStyle(
                                    color: BudgetTheme.mintDim,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                _label('Icon'),
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
                          color: Colors.white.withOpacity(sel ? 0.12 : 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: sel
                                ? BudgetTheme.mint
                                : Colors.white.withOpacity(0.12),
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
                _label('Color'),
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
                if (widget.initial != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Preview: ${_nameCtrl.text.isEmpty ? '—' : _nameCtrl.text}  •  ${money.format((_amountCtrl.text.isEmpty ? 0 : double.tryParse(_amountCtrl.text.replaceAll(RegExp(r"[^\d.]"), "")) ?? 0))}  •  ${labelForRecurrence(_cadence)}${_selectedCategory == null ? '' : ' • ${_selectedCategory!.name}'}',
                    style: const TextStyle(
                        color: Colors.white60, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(selected ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? BudgetTheme.mint : Colors.white.withOpacity(0.12),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: BudgetTheme.mintDim,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: BudgetTheme.mint, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _label(String s) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            s,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}
