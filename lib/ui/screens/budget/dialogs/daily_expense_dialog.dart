import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DailyExpenseDialog extends StatefulWidget {
  const DailyExpenseDialog({
    super.key,
    required this.date,
    required this.categories,
    required this.accent,
  });

  final DateTime date;
  final List<Map<String, dynamic>> categories;
  final Color accent;

  @override
  State<DailyExpenseDialog> createState() => _DailyExpenseDialogState();
}

class _DailyExpenseDialogState extends State<DailyExpenseDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  String? _categoryId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Track Expense', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              DateFormat.yMMMMEEEEd().format(widget.date),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Name (e.g., Coffee, Groceries)',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Amount (e.g., 12)',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text("Category:", style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _categoryId,
                dropdownColor: Colors.black,
                hint: const Text(
                  "Unassigned",
                  style: TextStyle(color: Colors.white54),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text(
                      "Unassigned",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  ...widget.categories.map(
                    (c) => DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text(
                        c['name'] as String,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: widget.accent),
          onPressed: () {
            final name = _nameCtrl.text.trim();
            final amt = int.tryParse(_amountCtrl.text.trim()) ?? 0;
            if (amt <= 0) return;

            Navigator.pop<Map<String, dynamic>>(context, {
              'name': name,
              'amount': amt,
              'categoryId': _categoryId,
            });
          },
          child: const Text('Save', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}
