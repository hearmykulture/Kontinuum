// lib/ui/workout/workout_editor_dialogs.dart
import 'package:flutter/material.dart';
import 'package:kontinuum/models/workout_models.dart';

import 'workout_editor_constants.dart';

class WorkoutEditorDialogs {
  static Future<void> showBatchTool({
    required BuildContext context,
    required WorkoutBlock block,
    required int blockIndex,
    required ValueChanged<List<WorkoutBlock>> onBlocksUpdated,
    required List<WorkoutBlock> allBlocks,
  }) async {
    final setsCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '10');
    final restCtrl = TextEditingController(text: '90');
    final timeCtrl = TextEditingController(text: '60');

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Batch edit block',
                  style: TextStyle(
                    color: kPrimaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 14),
                if (block.type == BlockType.set ||
                    block.type == BlockType.superset) ...[
                  _batchField('Sets', setsCtrl, hint: '3'),
                  const SizedBox(height: 10),
                  _batchField('Reps', repsCtrl, hint: '10'),
                  const SizedBox(height: 10),
                  _batchField('Rest (sec)', restCtrl, hint: '90'),
                ] else if (block.type == BlockType.circuit) ...[
                  _batchField('Rounds', setsCtrl, hint: '3'),
                  const SizedBox(height: 10),
                  _batchField('Work (sec)', timeCtrl, hint: '30'),
                  const SizedBox(height: 10),
                  _batchField('Rest (sec)', restCtrl, hint: '30'),
                ] else if (block.type == BlockType.emom) ...[
                  _batchField('Minutes / rounds', setsCtrl, hint: '10'),
                  const SizedBox(height: 10),
                  _batchField('Interval (sec)', timeCtrl, hint: '60'),
                ] else if (block.type == BlockType.amrap) ...[
                  _batchField('Duration (sec)', timeCtrl, hint: '300'),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () {
                      final blocks = List<WorkoutBlock>.from(allBlocks);
                      final b = blocks[blockIndex];

                      final batchSets = int.tryParse(
                        setsCtrl.text.trim().isEmpty
                            ? '0'
                            : setsCtrl.text.trim(),
                      );
                      final batchReps = int.tryParse(
                        repsCtrl.text.trim().isEmpty
                            ? '0'
                            : repsCtrl.text.trim(),
                      );
                      final batchRest = int.tryParse(
                        restCtrl.text.trim().isEmpty
                            ? '0'
                            : restCtrl.text.trim(),
                      );
                      final batchTime = int.tryParse(
                        timeCtrl.text.trim().isEmpty
                            ? '0'
                            : timeCtrl.text.trim(),
                      );

                      // Batch tool only applies when block type is known.
                      if (b.type == null) {
                        Navigator.of(ctx).maybePop();
                        return;
                      }

                      final newItems = b.items
                          .map(
                            (it) => _applyBatchToItem(
                              it,
                              b.type!,
                              sets: batchSets,
                              reps: batchReps,
                              restSec: batchRest,
                              timeSec: batchTime,
                            ),
                          )
                          .toList();

                      blocks[blockIndex] = WorkoutBlock(
                        type: b.type,
                        title: b.title,
                        items: newItems,
                      );

                      onBlocksUpdated(blocks);
                      Navigator.of(ctx).maybePop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: kCardBg,
                      foregroundColor: kCardText,
                    ),
                    child: const Text('Apply to all'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _batchField(String label, TextEditingController ctrl,
      {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: kSecondaryText, fontSize: 12),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: kPrimaryText),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: kSecondaryText.withValues(alpha: 0.6)),
            enabledBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: kSecondaryText.withValues(alpha: 0.3)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: kPrimaryText),
            ),
            isDense: true,
            filled: true,
            fillColor: kSecondaryText.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }

  static WorkoutItem _applyBatchToItem(
    WorkoutItem it,
    BlockType type, {
    int? sets,
    int? reps,
    int? restSec,
    int? timeSec,
  }) {
    switch (type) {
      case BlockType.set:
      case BlockType.superset:
        return WorkoutItem(
          exerciseId: it.exerciseId,
          targetSets: (sets == null || sets <= 0) ? it.targetSets : sets,
          targetReps: (reps == null || reps <= 0) ? it.targetReps : reps,
          targetTimeSec: null,
          restSec: (restSec == null || restSec <= 0) ? it.restSec : restSec,
          targetLoad: it.targetLoad,
          notes: it.notes,
          cueChips: List<String>.from(it.cueChips),
          formChecks: List<String>.from(it.formChecks),
          consecutiveMisses: it.consecutiveMisses,
          lastSuggestedLoadKg: it.lastSuggestedLoadKg,
          lastTargetReps: it.lastTargetReps,
          lastLoggedRpe: it.lastLoggedRpe,
          adaptiveSetsEnabled: it.adaptiveSetsEnabled,
          adaptivePercent: it.adaptivePercent,
        );
      case BlockType.circuit:
        return WorkoutItem(
          exerciseId: it.exerciseId,
          targetSets: (sets == null || sets <= 0) ? it.targetSets : sets,
          targetTimeSec:
              (timeSec == null || timeSec <= 0) ? it.targetTimeSec : timeSec,
          restSec: (restSec == null || restSec <= 0) ? it.restSec : restSec,
          targetReps: null,
          targetLoad: it.targetLoad,
          notes: it.notes,
          cueChips: List<String>.from(it.cueChips),
          formChecks: List<String>.from(it.formChecks),
          consecutiveMisses: it.consecutiveMisses,
          lastSuggestedLoadKg: it.lastSuggestedLoadKg,
          lastTargetReps: it.lastTargetReps,
          lastLoggedRpe: it.lastLoggedRpe,
          adaptiveSetsEnabled: it.adaptiveSetsEnabled,
          adaptivePercent: it.adaptivePercent,
        );
      case BlockType.emom:
        return WorkoutItem(
          exerciseId: it.exerciseId,
          targetSets: (sets == null || sets <= 0) ? it.targetSets : sets,
          targetTimeSec:
              (timeSec == null || timeSec <= 0) ? it.targetTimeSec : timeSec,
          restSec: null,
          targetReps: null,
          targetLoad: it.targetLoad,
          notes: it.notes,
          cueChips: List<String>.from(it.cueChips),
          formChecks: List<String>.from(it.formChecks),
          consecutiveMisses: it.consecutiveMisses,
          lastSuggestedLoadKg: it.lastSuggestedLoadKg,
          lastTargetReps: it.lastTargetReps,
          lastLoggedRpe: it.lastLoggedRpe,
          adaptiveSetsEnabled: it.adaptiveSetsEnabled,
          adaptivePercent: it.adaptivePercent,
        );
      case BlockType.amrap:
        return WorkoutItem(
          exerciseId: it.exerciseId,
          targetSets: 1,
          targetTimeSec:
              (timeSec == null || timeSec <= 0) ? it.targetTimeSec : timeSec,
          restSec: null,
          targetReps: null,
          targetLoad: it.targetLoad,
          notes: it.notes,
          cueChips: List<String>.from(it.cueChips),
          formChecks: List<String>.from(it.formChecks),
          consecutiveMisses: it.consecutiveMisses,
          lastSuggestedLoadKg: it.lastSuggestedLoadKg,
          lastTargetReps: it.lastTargetReps,
          lastLoggedRpe: it.lastLoggedRpe,
          adaptiveSetsEnabled: it.adaptiveSetsEnabled,
          adaptivePercent: it.adaptivePercent,
        );
    }
  }
}
