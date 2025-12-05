// lib/ui/workout/workout_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/models/workout_models.dart';

import 'workout_editor_constants.dart';
import 'workout_editor_widgets.dart';
import 'workout_editor_dialogs.dart';
import 'workout_block_card.dart';
import 'add_exercise_popup_route.dart';

class WorkoutEditorArgs {
  /// if null → create new workout (optionally attach to routine)
  final String? workoutId;
  final String? attachToRoutineId;

  const WorkoutEditorArgs({
    this.workoutId,
    this.attachToRoutineId,
  });
}

class WorkoutEditorScreen extends StatefulWidget {
  const WorkoutEditorScreen({super.key});

  @override
  State<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends State<WorkoutEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _titleFocus = FocusNode();

  bool _saving = false;

  Workout? _workout;
  String? _attachToRoutineId;

  double _titleFontSize = 44;
  bool _showContent = false;

  void _recalcTitleSize(String text) {
    final len = text.length;
    double size;
    if (len <= 14) {
      size = 44;
    } else if (len <= 26) {
      size = 38;
    } else {
      size = 30;
    }
    if (size != _titleFontSize) {
      setState(() => _titleFontSize = size);
    }
  }

  void _handleTitleChanged() => _recalcTitleSize(_titleCtrl.text);

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_handleTitleChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_workout != null) return;

    final args =
        ModalRoute.of(context)?.settings.arguments as WorkoutEditorArgs?;
    final wp = context.read<WorkoutProvider>();

    _attachToRoutineId = args?.attachToRoutineId;

    if (args?.workoutId != null) {
      final existing = wp.getWorkoutById(args!.workoutId!);
      if (existing != null) {
        _workout = Workout(
          id: existing.id,
          title: existing.title,
          notes: existing.notes,
          blocks: existing.blocks
              .map(
                (b) => WorkoutBlock(
                  type: b.type,
                  title: b.title,
                  items: b.items
                      .map(
                        (it) => WorkoutItem(
                          exerciseId: it.exerciseId,
                          targetSets: it.targetSets,
                          targetReps: it.targetReps,
                          targetTimeSec: it.targetTimeSec,
                          restSec: it.restSec,
                          targetLoad: it.targetLoad,
                          notes: it.notes,
                          cueChips: List<String>.from(it.cueChips),
                          formChecks: List<String>.from(it.formChecks),
                          consecutiveMisses: it.consecutiveMisses,
                          lastSuggestedLoadKg: it.lastSuggestedLoadKg,
                          lastTargetReps: it.lastTargetReps,
                          lastLoggedRpe: it.lastLoggedRpe,
                        ),
                      )
                      .toList(),
                ),
              )
              .toList(),
        );
      }
    }

    // new workout
    _workout ??= Workout(
      id: '',
      title: '',
      notes: '',
      blocks: <WorkoutBlock>[],
    );

    final initialTitle = _workout!.title;
    if (_workout!.id.isEmpty ||
        initialTitle.trim().toLowerCase() == 'new workout') {
      _titleCtrl.clear();
    } else {
      _titleCtrl.text = initialTitle;
    }
    _notesCtrl.text = _workout!.notes ?? '';
    _recalcTitleSize(_titleCtrl.text);

    if (!_showContent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _titleFocus.requestFocus();
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) setState(() => _showContent = true);
        });
      });
    }

    setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_handleTitleChanged);
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _close() {
    FocusScope.of(context).unfocus();
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) {
      nav.pop();
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    // Validation: ensure all blocks have a type selected
    final blocksWithoutType = <int>[];
    for (int i = 0; i < _workout!.blocks.length; i++) {
      if (_workout!.blocks[i].type == null) {
        blocksWithoutType.add(i + 1);
      }
    }

    if (blocksWithoutType.isNotEmpty) {
      if (!mounted) return;
      final blocksList = blocksWithoutType.length == 1
          ? 'Block ${blocksWithoutType.first}'
          : 'Blocks ${blocksWithoutType.join(', ')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$blocksList must have a type selected'),
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFFFF6B81),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final wp = context.read<WorkoutProvider>();

    final updated = Workout(
      id: _workout!.id,
      title: _titleCtrl.text.trim().isEmpty
          ? 'Untitled workout'
          : _titleCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      blocks: _workout!.blocks,
    );

    if (updated.id.isEmpty) {
      final created = await wp.createWorkout(
        title: updated.title,
        notes: updated.notes,
        blocks: updated.blocks,
        attachToRoutineId: _attachToRoutineId,
      );
      _workout = created;
    } else {
      await wp.updateWorkout(updated);
      _workout = updated;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  void _setBlocks(List<WorkoutBlock> blocks) {
    setState(() {
      _workout = Workout(
        id: _workout!.id,
        title: _workout!.title,
        notes: _workout!.notes,
        blocks: blocks,
      );
    });
  }

  // =========================
  // BLOCK ADD / PICK TYPE
  // =========================
  Future<void> _addBlock() async {
    final blocks = List<WorkoutBlock>.from(_workout!.blocks);
    blocks.add(
      WorkoutBlock(
        type: null,
        title: null,
        items: <WorkoutItem>[],
      ),
    );
    _setBlocks(blocks);
  }

  void _duplicateBlock(int index) {
    final blocks = List<WorkoutBlock>.from(_workout!.blocks);
    if (index < 0 || index >= blocks.length) return;
    final src = blocks[index];

    final cloned = WorkoutBlock(
      type: src.type,
      title: src.title,
      items: src.items
          .map(
            (it) => WorkoutItem(
              exerciseId: it.exerciseId,
              targetSets: it.targetSets,
              targetReps: it.targetReps,
              targetTimeSec: it.targetTimeSec,
              restSec: it.restSec,
              targetLoad: it.targetLoad,
              notes: it.notes,
              cueChips: List<String>.from(it.cueChips),
              formChecks: List<String>.from(it.formChecks),
              consecutiveMisses: it.consecutiveMisses,
              lastSuggestedLoadKg: it.lastSuggestedLoadKg,
              lastTargetReps: it.lastTargetReps,
              lastLoggedRpe: it.lastLoggedRpe,
            ),
          )
          .toList(),
    );

    blocks.insert(index + 1, cloned);
    _setBlocks(blocks);
  }

  void _removeBlock(int index) {
    final blocks = List<WorkoutBlock>.from(_workout!.blocks);
    if (index < 0 || index >= blocks.length) return;
    blocks.removeAt(index);
    _setBlocks(blocks);
  }

  // =========================
  // EXERCISE OPS
  // =========================
  void _addExercisesToBlock(int blockIndex, List<Exercise> exercises) {
    if (exercises.isEmpty) return;
    final blocks = List<WorkoutBlock>.from(_workout!.blocks);
    final block = blocks[blockIndex];

    // Safety: don't add exercise if type not yet chosen
    if (block.type == null) return;

    final items = List<WorkoutItem>.from(block.items);

    for (final exercise in exercises) {
      items.add(_makeDefaultItemFor(block.type!, exercise));
    }

    blocks[blockIndex] = WorkoutBlock(
      type: block.type,
      title: block.title,
      items: items,
    );

    _setBlocks(blocks);
  }

  Future<void> _duplicateExerciseInBlock(int blockIndex, int itemIndex) async {
    final blocks = List<WorkoutBlock>.from(_workout!.blocks);
    final block = blocks[blockIndex];
    final items = List<WorkoutItem>.from(block.items);
    if (itemIndex < 0 || itemIndex >= items.length) return;

    final src = items[itemIndex];
    final cloned = WorkoutItem(
      exerciseId: src.exerciseId,
      targetSets: src.targetSets,
      targetReps: src.targetReps,
      targetTimeSec: src.targetTimeSec,
      restSec: src.restSec,
      targetLoad: src.targetLoad,
      notes: src.notes,
      cueChips: List<String>.from(src.cueChips),
      formChecks: List<String>.from(src.formChecks),
      consecutiveMisses: src.consecutiveMisses,
      lastSuggestedLoadKg: src.lastSuggestedLoadKg,
      lastTargetReps: src.lastTargetReps,
      lastLoggedRpe: src.lastLoggedRpe,
    );

    items.insert(itemIndex + 1, cloned);

    blocks[blockIndex] = WorkoutBlock(
      type: block.type,
      title: block.title,
      items: items,
    );

    _setBlocks(blocks);
  }

  Future<void> _viewExerciseDetails(int blockIndex, int itemIndex) async {
    final blocks = _workout?.blocks;
    if (blocks == null || blockIndex < 0 || blockIndex >= blocks.length) {
      return;
    }
    final WorkoutBlock block = blocks[blockIndex];
    if (itemIndex < 0 || itemIndex >= block.items.length) {
      return;
    }

    final WorkoutItem item = block.items[itemIndex];
    await Navigator.of(context).push(
      ExerciseDetailsPopupRoute(
        exerciseId: item.exerciseId,
      ),
    );
  }

  String _intentKeyFromEnum(ExerciseIntent? intent) {
    if (intent == null) return '';
    return intent.name.toLowerCase();
  }

  WorkoutItem _makeDefaultItemFor(BlockType type, Exercise ex) {
    final intentKey = _intentKeyFromEnum(ex.intent);
    final baseCues = ex.cues.take(2).toList();

    WorkoutItem strengthLike() => WorkoutItem(
          exerciseId: ex.id,
          targetSets: 5,
          targetReps: 5,
          targetTimeSec: null,
          restSec: 120,
          targetLoad: null,
          notes: null,
          cueChips: baseCues,
          formChecks: const [],
          consecutiveMisses: 0,
          lastSuggestedLoadKg: null,
          lastTargetReps: null,
          lastLoggedRpe: null,
        );

    WorkoutItem hyperLike() => WorkoutItem(
          exerciseId: ex.id,
          targetSets: 3,
          targetReps: 10,
          targetTimeSec: null,
          restSec: 90,
          targetLoad: null,
          notes: null,
          cueChips: baseCues,
          formChecks: const [],
          consecutiveMisses: 0,
          lastSuggestedLoadKg: null,
          lastTargetReps: null,
          lastLoggedRpe: null,
        );

    WorkoutItem mobilityLike({int work = 30, int rest = 30}) => WorkoutItem(
          exerciseId: ex.id,
          targetSets: 3,
          targetTimeSec: work,
          restSec: rest,
          targetReps: null,
          targetLoad: null,
          notes: null,
          cueChips: baseCues,
          formChecks: const [],
          consecutiveMisses: 0,
          lastSuggestedLoadKg: null,
          lastTargetReps: null,
          lastLoggedRpe: null,
        );

    switch (type) {
      case BlockType.set:
      case BlockType.superset:
        if (intentKey == 'strength' || intentKey == 'power') {
          return strengthLike();
        }
        if (intentKey == 'hypertrophy' ||
            intentKey == 'bodybuilding' ||
            intentKey == 'muscle') {
          return hyperLike();
        }
        if (intentKey == 'mobility' || intentKey == 'rehab') {
          return mobilityLike();
        }
        return hyperLike();

      case BlockType.circuit:
        return mobilityLike(work: 30, rest: 30);

      case BlockType.emom:
        return WorkoutItem(
          exerciseId: ex.id,
          targetSets: 10,
          targetTimeSec: 60,
          restSec: null,
          targetReps: null,
          targetLoad: null,
          notes: null,
          cueChips: baseCues,
          formChecks: const [],
          consecutiveMisses: 0,
          lastSuggestedLoadKg: null,
          lastTargetReps: null,
          lastLoggedRpe: null,
        );

      case BlockType.amrap:
        return WorkoutItem(
          exerciseId: ex.id,
          targetSets: 1,
          targetTimeSec: 300,
          restSec: null,
          targetReps: null,
          targetLoad: null,
          notes: null,
          cueChips: baseCues,
          formChecks: const [],
          consecutiveMisses: 0,
          lastSuggestedLoadKg: null,
          lastTargetReps: null,
          lastLoggedRpe: null,
        );
    }
  }

  void _removeExerciseFromBlock(int blockIndex, int itemIndex) {
    final blocks = List<WorkoutBlock>.from(_workout!.blocks);
    final block = blocks[blockIndex];
    final items = List<WorkoutItem>.from(block.items);
    if (itemIndex < 0 || itemIndex >= items.length) return;
    items.removeAt(itemIndex);

    blocks[blockIndex] = WorkoutBlock(
      type: block.type,
      title: block.title,
      items: items,
    );

    _setBlocks(blocks);
  }

  void _moveExerciseInBlock(int blockIndex, int from, int to) {
    final blocks = List<WorkoutBlock>.from(_workout!.blocks);
    final block = blocks[blockIndex];
    final items = List<WorkoutItem>.from(block.items);
    if (from < 0 || from >= items.length) return;
    if (to < 0 || to >= items.length) return;

    final item = items.removeAt(from);
    items.insert(to, item);

    blocks[blockIndex] = WorkoutBlock(
      type: block.type,
      title: block.title,
      items: items,
    );

    _setBlocks(blocks);
  }

  void _updateExerciseInBlock(
      int blockIndex, int itemIndex, WorkoutItem updated) {
    final blocks = List<WorkoutBlock>.from(_workout!.blocks);
    final block = blocks[blockIndex];
    final items = List<WorkoutItem>.from(block.items);
    if (itemIndex < 0 || itemIndex >= items.length) return;
    items[itemIndex] = updated;
    blocks[blockIndex] = WorkoutBlock(
      type: block.type,
      title: block.title,
      items: items,
    );
    _setBlocks(blocks);
  }

  // =========================
  // BLOCK META (title/type)
  // =========================
  Future<void> _updateBlockMeta({
    required int index,
    String? title,
    BlockType? type,
  }) async {
    final blocks = List<WorkoutBlock>.from(_workout!.blocks);
    final old = blocks[index];
    final newType = type ?? old.type;

    final normalizedItems = (newType != null && newType != old.type)
        ? old.items.map((it) => _normalizeItemForNewType(it, newType)).toList()
        : old.items;

    blocks[index] = WorkoutBlock(
      type: newType,
      title: title ?? old.title,
      items: normalizedItems,
    );
    _setBlocks(blocks);
  }

  WorkoutItem _normalizeItemForNewType(WorkoutItem it, BlockType newType) {
    switch (newType) {
      case BlockType.set:
      case BlockType.superset:
        return WorkoutItem(
          exerciseId: it.exerciseId,
          targetSets: it.targetSets == 0 ? 3 : it.targetSets,
          targetReps: it.targetReps ?? 10,
          targetTimeSec: null,
          restSec: it.restSec ?? 90,
          targetLoad: it.targetLoad,
          notes: it.notes,
          cueChips: List<String>.from(it.cueChips),
          formChecks: List<String>.from(it.formChecks),
          consecutiveMisses: it.consecutiveMisses,
          lastSuggestedLoadKg: it.lastSuggestedLoadKg,
          lastTargetReps: it.lastTargetReps,
          lastLoggedRpe: it.lastLoggedRpe,
        );
      case BlockType.circuit:
        return WorkoutItem(
          exerciseId: it.exerciseId,
          targetSets: it.targetSets == 0 ? 3 : it.targetSets,
          targetTimeSec: it.targetTimeSec ?? 30,
          restSec: it.restSec ?? 30,
          targetReps: null,
          targetLoad: it.targetLoad,
          notes: it.notes,
          cueChips: List<String>.from(it.cueChips),
          formChecks: List<String>.from(it.formChecks),
          consecutiveMisses: it.consecutiveMisses,
          lastSuggestedLoadKg: it.lastSuggestedLoadKg,
          lastTargetReps: it.lastTargetReps,
          lastLoggedRpe: it.lastLoggedRpe,
        );
      case BlockType.emom:
        return WorkoutItem(
          exerciseId: it.exerciseId,
          targetSets: it.targetSets == 0 ? 10 : it.targetSets,
          targetTimeSec: it.targetTimeSec ?? 60,
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
        );
      case BlockType.amrap:
        return WorkoutItem(
          exerciseId: it.exerciseId,
          targetSets: 1,
          targetTimeSec: it.targetTimeSec ?? 300,
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
        );
    }
  }

  // =========================
  // BATCH TOOL (per block)
  // =========================
  Future<void> _openBatchTool(int blockIndex) async {
    final block = _workout!.blocks[blockIndex];
    await WorkoutEditorDialogs.showBatchTool(
      context: context,
      block: block,
      blockIndex: blockIndex,
      allBlocks: _workout!.blocks,
      onBlocksUpdated: _setBlocks,
    );
  }

  // ----- REORDER BLOCKS -----
  void _onReorderBlocks(int oldIndex, int newIndex) {
    if (_workout == null) return;
    final blocks = List<WorkoutBlock>.from(_workout!.blocks);
    if (oldIndex < 0 || oldIndex >= blocks.length) return;
    if (newIndex < 0 || newIndex > blocks.length) return;

    final block = blocks.removeAt(oldIndex);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    blocks.insert(newIndex, block);
    _setBlocks(blocks);
  }

  @override
  Widget build(BuildContext context) {
    final workout = _workout;
    if (workout == null) {
      return const Scaffold(
        backgroundColor: kEditorBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final mq = MediaQuery.of(context);
    final insets = mq.viewInsets;
    final pad = mq.padding;
    final double baseTop = pad.top + 12.0;
    final double closeTop = baseTop;
    const double closeRight = 8.0;

    return Scaffold(
      backgroundColor: kEditorBg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // MAIN (matches create-routine layout)
          Positioned.fill(
            bottom: insets.bottom + kFooterH,
            child: SafeArea(
              top: true,
              bottom: false,
              child: AnimatedOpacity(
                opacity: _showContent ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: ScrollConfiguration(
                  behavior: const NoGlowBehavior(),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            const SizedBox(height: 160),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 32),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 520),
                                  child: TextField(
                                    controller: _titleCtrl,
                                    focusNode: _titleFocus,
                                    textAlign: TextAlign.center,
                                    cursorColor: kPrimaryText,
                                    cursorWidth: 3,
                                    maxLines: 2,
                                    minLines: 1,
                                    style: TextStyle(
                                      color: kPrimaryText,
                                      fontSize: _titleFontSize,
                                      fontWeight: FontWeight.w600,
                                      height: 1.05,
                                    ),
                                    decoration: InputDecoration(
                                      isCollapsed: true,
                                      border: InputBorder.none,
                                      hintText: 'Workout name',
                                      hintStyle: TextStyle(
                                        color: kSecondaryText
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _save(),
                                    inputFormatters: [
                                      FilteringTextInputFormatter
                                          .singleLineFormatter,
                                      LengthLimitingTextInputFormatter(
                                        kMaxWorkoutTitleChars,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            onReorder: _onReorderBlocks,
                            itemCount: workout.blocks.length,
                            itemBuilder: (context, index) {
                              final block = workout.blocks[index];
                              return BlockCard(
                                key: ValueKey('block_$index'),
                                index: index,
                                block: block,
                                onAddExercises: (exercises) =>
                                    _addExercisesToBlock(index, exercises),
                                onRemove: () => _removeBlock(index),
                                onDuplicate: () => _duplicateBlock(index),
                                onRemoveExercise: (i) =>
                                    _removeExerciseFromBlock(index, i),
                                onDuplicateExercise: (i) =>
                                    _duplicateExerciseInBlock(index, i),
                                onViewExerciseDetails: (i) =>
                                    _viewExerciseDetails(index, i),
                                onBlockMetaChanged: (title, type) =>
                                    _updateBlockMeta(
                                  index: index,
                                  title: title,
                                  type: type,
                                ),
                                onBatch: () => _openBatchTool(index),
                              );
                            },
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
                        sliver: SliverToBoxAdapter(
                          child: AddBlockFooter(
                            onAdd: _addBlock,
                            key: const ValueKey('footer'),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        sliver: SliverToBoxAdapter(
                          child: EditorHeader(
                            notesCtrl: _notesCtrl,
                            key: const ValueKey('header'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // FOOTER (Cancel / Done like create-routine)
          Positioned(
            left: 0,
            right: 0,
            bottom: insets.bottom,
            child: Container(
              height: kFooterH + pad.bottom,
              color: kEditorBg,
              padding: EdgeInsets.only(left: 16, right: 16, bottom: pad.bottom),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _close,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: kPrimaryText, fontSize: 16),
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _saving ? null : _save,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 4),
                      child: Text(
                        _saving ? 'Saving…' : 'Done',
                        style: TextStyle(
                          color: kPrimaryText,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // TOP-RIGHT CLOSE (single inline X like create-routine)
          Positioned(
            top: closeTop,
            right: closeRight,
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.close_rounded,
                  color: kPrimaryText,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
