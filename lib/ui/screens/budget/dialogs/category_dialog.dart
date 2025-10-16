import 'package:flutter/material.dart';

class CategoryDialog extends StatefulWidget {
  const CategoryDialog({
    super.key,
    required this.palette,
    required this.accent,
    this.existing,
  });

  final List<Color> palette;
  final Color accent;
  final Map<String, dynamic>? existing;

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _capCtrl;
  late int _colorValue;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?['name'] ?? '');
    _capCtrl = TextEditingController(
      text: (widget.existing != null && (widget.existing!['cap'] ?? 0) > 0)
          ? (widget.existing!['cap']).toString()
          : '',
    );
    _colorValue =
        widget.existing?['color'] as int? ??
        widget.palette.first.toARGB32(); // ⬅️ no .value
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _capCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Category', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Name (e.g., Groceries)',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _capCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Monthly cap (optional)',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.palette.map((c) {
                final selected = _colorValue == c.toARGB32(); // ⬅️ no .value
                return GestureDetector(
                  onTap: () => setState(() => _colorValue = c.toARGB32()),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
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
            if (name.isEmpty) return;
            final cap = int.tryParse(_capCtrl.text.trim()) ?? 0;

            Navigator.pop<Map<String, dynamic>>(context, {
              'name': name,
              'cap': cap,
              'color': _colorValue,
            });
          },
          child: const Text('Save', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}
