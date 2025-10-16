import 'package:flutter/material.dart';
import '../../models/text_block.dart';
import '../block_editor.dart';
import 'dart:ui' show Rect, Offset;

class SimileEditor implements BlockEditor {
  @override
  Future<BlockEditResult?> show(
    BuildContext context, {
    required TextBlock block,
    Rect? sourceRect,
  }) {
    final m1 = TextEditingController(text: block.meanings[0]);
    final m2 = TextEditingController(text: block.meanings[1]);
    int current = block.currentMeaning;

    final media = MediaQuery.of(context);
    final screenSize = media.size;
    final startRect = (sourceRect == null || sourceRect == Rect.zero)
        ? Rect.fromCenter(
            center: screenSize.center(Offset.zero),
            width: 60,
            height: 32,
          )
        : sourceRect;

    return showGeneralDialog<BlockEditResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SimileEditor',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, __, child) {
        final t = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);

        const targetWidth = 520.0;
        const targetHeight = 520.0;
        final endRect = Rect.fromCenter(
          center: screenSize.center(Offset.zero),
          width: targetWidth.clamp(280.0, screenSize.width * 0.92),
          height: targetHeight.clamp(280.0, screenSize.height * 0.92),
        );

        final rect = Rect.lerp(startRect, endRect, t.value)!;
        final radius = BorderRadius.lerp(
          const BorderRadius.all(Radius.circular(8)),
          const BorderRadius.all(Radius.circular(16)),
          t.value,
        )!;

        return Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: Material(
                color: const Color(0xFF111111),
                elevation: 12.0 * t.value,
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const SizedBox.shrink(),
                    AnimatedOpacity(
                      opacity: t.value >= 0.25 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 120),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints.tightFor(
                            width: 520,
                            height: 520,
                          ),
                          child: _EditorBody(
                            title: 'Edit Simile',
                            m1: m1,
                            m2: m2,
                            current: current,
                            onSetCurrent: (v) => current = v,
                            onDelete: () => Navigator.pop(
                              ctx,
                              const BlockEditResult(delete: true),
                            ),
                            onCancel: () => Navigator.pop(ctx, null),
                            onSave: () {
                              final updated = block.copyWith(
                                meanings: [m1.text, m2.text],
                                currentMeaning: current,
                              );
                              Navigator.pop(
                                ctx,
                                BlockEditResult(updatedBlock: updated),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EditorBody extends StatefulWidget {
  final String title;
  final TextEditingController m1;
  final TextEditingController m2;
  final int current;
  final ValueChanged<int> onSetCurrent;
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _EditorBody({
    required this.title,
    required this.m1,
    required this.m2,
    required this.current,
    required this.onSetCurrent,
    required this.onDelete,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends State<_EditorBody> {
  late int current = widget.current;

  @override
  Widget build(BuildContext context) {
    final preview = (current == 0 ? widget.m1.text : widget.m2.text).isEmpty
        ? 'Simile'
        : (current == 0 ? widget.m1.text : widget.m2.text);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(preview, style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ChoiceChip(
                label: const Text('#1'),
                selected: current == 0,
                onSelected: (_) => setState(() {
                  current = 0;
                  widget.onSetCurrent(0);
                }),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('#2'),
                selected: current == 1,
                onSelected: (_) => setState(() {
                  current = 1;
                  widget.onSetCurrent(1);
                }),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() {
                  final t = widget.m1.text;
                  widget.m1.text = widget.m2.text;
                  widget.m2.text = t;
                }),
                icon: const Icon(
                  Icons.swap_horiz,
                  color: Colors.white70,
                  size: 18,
                ),
                label: const Text(
                  'Swap',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: widget.m1,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Meaning #1'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: widget.m2,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Meaning #2'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                label: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onCancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: widget.onSave,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
