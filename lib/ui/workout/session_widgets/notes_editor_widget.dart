// lib/ui/workout/session_widgets/notes_editor_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show LengthLimitingTextInputFormatter, MaxLengthEnforcement;
import 'package:kontinuum/ui/workout/workout_editor_constants.dart';

/// Per-exercise notes character cap (UI + hard limit)
const int kMaxExerciseNoteChars = 240;

/// Inline notes editor widget (compact, not overlay)
class InlineNotesEditor extends StatelessWidget {
  const InlineNotesEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSave,
    required this.onClear,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function() onSave;
  final Future<void> Function() onClear;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardText.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: kCardText.withValues(alpha: 0.12),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Writing notes',
                style: TextStyle(
                  color: kPrimaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close notes',
                onPressed: onClose,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                splashRadius: 16,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: 2,
            minLines: 1,
            maxLength: kMaxExerciseNoteChars,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            inputFormatters: [
              LengthLimitingTextInputFormatter(kMaxExerciseNoteChars),
            ],
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: kCardText, fontSize: 12.5),
            decoration: InputDecoration(
              hintText: 'Add coaching cues or reminders…',
              hintStyle: TextStyle(
                color: kCardText.withValues(alpha: 0.45),
                fontSize: 12.5,
              ),
              isDense: true,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.03),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: kCardText.withValues(alpha: 0.10)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: kCardText.withValues(alpha: 0.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: kCardText.withValues(alpha: 0.22)),
              ),
              counterText: '',
            ),
            onSubmitted: (_) => onSave(),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  foregroundColor: kSecondaryText,
                  textStyle: const TextStyle(fontSize: 12.5),
                ),
                child: const Text('Clear'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimaryText,
                  foregroundColor: kCardBg,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
