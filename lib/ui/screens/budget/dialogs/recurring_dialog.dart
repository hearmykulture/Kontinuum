import 'package:flutter/material.dart';

class RecurringDialog extends StatefulWidget {
  const RecurringDialog({
    super.key,
    required this.categories,
    required this.accent,
    this.existing,
  });

  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? existing;
  final Color accent;

  @override
  State<RecurringDialog> createState() => _RecurringDialogState();
}

class _RecurringDialogState extends State<RecurringDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late int _day;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?['name'] ?? '');
    _amountCtrl = TextEditingController(
      text: (widget.existing != null && (widget.existing!['amount'] ?? 0) > 0)
          ? (widget.existing!['amount']).toString()
          : '',
    );
    _day = (widget.existing?['day'] as int?) ?? 1;
    _categoryId = widget.existing?['categoryId'] as String?;
  }

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
      title: const Text(
        'Recurring Expense',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Name (e.g., Rent, Spotify)',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Amount (e.g., 1200)',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text("Day:", style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _day,
                  dropdownColor: Colors.black,
                  items: List.generate(28, (i) => i + 1)
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                            "$d",
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _day = v ?? _day),
                ),
                const Spacer(),
                const Text(
                  "Category:",
                  style: TextStyle(color: Colors.white70),
                ),
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
            if (name.isEmpty || amt <= 0) return;

            Navigator.pop<Map<String, dynamic>>(context, {
              'name': name,
              'amount': amt,
              'day': _day,
              'categoryId': _categoryId,
            });
          },
          child: const Text('Save', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}
