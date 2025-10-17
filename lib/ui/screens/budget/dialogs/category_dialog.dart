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

    final existing = widget.existing;

    final String initialName = (existing?['name'] as String?) ?? '';
    final num? capNum = existing?['cap'] is num
        ? existing!['cap'] as num
        : null;
    final String initialCapText = (capNum != null && capNum > 0)
        ? capNum.toString()
        : '';

    // color may be stored as int (preferred) or Color; fall back to first palette color
    final dynamic rawColor = existing?['color'];
    final int initialColor = rawColor is int
        ? rawColor
        : (rawColor is Color ? rawColor.value : widget.palette.first.value);

    _nameCtrl = TextEditingController(text: initialName);
    _capCtrl = TextEditingController(text: initialCapText);
    _colorValue = initialColor;
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
                final selected = _colorValue == c.value;
                return GestureDetector(
                  onTap: () => setState(() => _colorValue = c.value),
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
              'color': _colorValue, // int ARGB32
            });
          },
          child: const Text('Save', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}
