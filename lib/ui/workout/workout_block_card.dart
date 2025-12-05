// lib/ui/workout/workout_block_card.dart
import 'package:flutter/material.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'add_exercise_popup_route.dart';
import 'workout_editor_constants.dart';
import 'workout_exercise_row.dart';

class BlockCard extends StatefulWidget {
  final int index;
  final WorkoutBlock block;
  final ValueChanged<List<Exercise>> onAddExercises;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback onBatch;
  final void Function(int itemIndex) onRemoveExercise;
  final void Function(int itemIndex) onDuplicateExercise;
  final void Function(int itemIndex) onViewExerciseDetails;
  final void Function(int itemIndex) onEditExerciseSets;
  final void Function(int itemIndex) onEditExerciseReps;
  final void Function(int itemIndex) onEditExerciseWork;
  final void Function(int itemIndex) onEditExerciseRest;
  final void Function(int itemIndex) onEditExerciseLoad;
  final void Function(int itemIndex)? onQuickIncrementSets;
  final void Function(int oldIndex, int newIndex) onReorderExercise;
  final void Function(String? title, BlockType? type) onBlockMetaChanged;
  final WeightUnit loadUnit;
  final ValueChanged<WeightUnit> onLoadUnitChanged;
  final bool showStructureControls;
  final bool titleEditable;
  final bool isSessionMode;
  final EdgeInsets margin;
  final void Function(int itemIndex, String? note) onEditExerciseNote;
  final Widget? reorderHandle;

  const BlockCard({
    super.key,
    required this.index,
    required this.block,
    required this.onAddExercises,
    required this.onRemove,
    required this.onDuplicate,
    required this.onRemoveExercise,
    required this.onDuplicateExercise,
    required this.onViewExerciseDetails,
    required this.onEditExerciseSets,
    required this.onEditExerciseReps,
    required this.onEditExerciseWork,
    required this.onEditExerciseRest,
    required this.onEditExerciseLoad,
    this.onQuickIncrementSets,
    required this.onReorderExercise,
    required this.onBlockMetaChanged,
    required this.loadUnit,
    required this.onLoadUnitChanged,
    this.showStructureControls = true,
    this.titleEditable = true,
    this.isSessionMode = false,
    required this.onBatch,
    this.margin = const EdgeInsets.only(bottom: 14),
    required this.onEditExerciseNote,
    this.reorderHandle,
  });

  @override
  State<BlockCard> createState() => _BlockCardState();
}

class _BlockCardState extends State<BlockCard> with TickerProviderStateMixin {
  bool _typeExpanded = false;
  bool _collapsed = false;

  late final AnimationController _pickerCtrl;
  late final Animation<double> _expandCurve;
  late final TextEditingController _titleCtrl;
  late final AnimationController _contentCtrl;
  late final CurvedAnimation _contentCurve;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;
  late final Animation<double> _contentScale;
  final FocusNode _titleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.block.title ?? '');
    _titleCtrl.selection =
        TextSelection.collapsed(offset: _titleCtrl.text.length);
    _pickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _expandCurve = CurvedAnimation(
      parent: _pickerCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _contentCurve = CurvedAnimation(
      parent: _contentCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0, 0.8, curve: Curves.easeOutCubic),
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(_contentCurve);
    _contentScale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _contentCtrl.value = _collapsed ? 0.0 : 1.0;
  }

  @override
  void didUpdateWidget(BlockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.title != widget.block.title) {
      final newTitle = widget.block.title ?? '';
      if (newTitle != _titleCtrl.text) {
        final oldSelection = _titleCtrl.selection;
        int base = oldSelection.baseOffset;
        int extent = oldSelection.extentOffset;
        if (base > newTitle.length) base = newTitle.length;
        if (extent > newTitle.length) extent = newTitle.length;
        _titleCtrl.value = TextEditingValue(
          text: newTitle,
          selection: TextSelection(
            baseOffset: base,
            extentOffset: extent,
          ),
        );
      }
    }
    if (!oldWidget.isSessionMode && widget.isSessionMode) {
      bool needsSetState = false;
      if (_typeExpanded) {
        _typeExpanded = false;
        _pickerCtrl.reverse();
        needsSetState = true;
      }
      if (_collapsed) {
        _collapsed = false;
        _contentCtrl.forward();
        needsSetState = true;
      }
      if (needsSetState && mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _pickerCtrl.dispose();
    _contentCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _toggleTypePicker() {
    setState(() => _typeExpanded = !_typeExpanded);
    if (_typeExpanded) {
      _pickerCtrl.forward();
    } else {
      _pickerCtrl.reverse();
    }
  }

  void _selectType(BlockType bt) {
    widget.onBlockMetaChanged(null, bt);
    setState(() => _typeExpanded = false);
    _pickerCtrl.reverse();
  }

  Widget _buildExerciseRow(WorkoutBlock block, int i) {
    final item = block.items[i];
    return ExerciseRow(
      key: ValueKey('${item.exerciseId}-$i'),
      item: item,
      blockType: block.type,
      onRemove: () => widget.onRemoveExercise(i),
      onDuplicate: () => widget.onDuplicateExercise(i),
      onViewDetails: () => widget.onViewExerciseDetails(i),
      onEditSets: () => widget.onEditExerciseSets(i),
      onEditReps: () => widget.onEditExerciseReps(i),
      onEditWork: () => widget.onEditExerciseWork(i),
      onEditRest: () => widget.onEditExerciseRest(i),
      onEditLoad: () => widget.onEditExerciseLoad(i),
      loadUnit: widget.loadUnit,
      onLoadUnitChanged: widget.onLoadUnitChanged,
      onQuickIncrementSets: widget.onQuickIncrementSets == null
          ? null
          : () => widget.onQuickIncrementSets!(i),
      onNoteChanged: (note) => widget.onEditExerciseNote(i, note),
      showStructureActions:
          widget.showStructureControls && !widget.isSessionMode,
      isSessionMode: widget.isSessionMode,
    );
  }

  void _toggleCollapsed() {
    setState(() {
      _collapsed = !_collapsed;
      if (_collapsed && _typeExpanded) {
        _typeExpanded = false;
        _pickerCtrl.reverse();
      }
    });
    if (_collapsed) {
      _contentCtrl.reverse();
    } else {
      _contentCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;

    // NOTE: Treat type as nullable for "required" UX.
    // If your model currently uses a non-nullable BlockType,
    // make it `BlockType?` and initialize to null when creating a block.
    final BlockType? type = block.type;
    final bool hasType = type != null;
    final BlockTypeInfo? typeInfo = hasType ? blockTypeInfo[type] : null;

    final bool sessionMode = widget.isSessionMode;
    final bool allowStructureControls =
        widget.showStructureControls && !sessionMode;
    final Color surface =
        sessionMode ? Colors.transparent : kCardText.withValues(alpha: 0.12);
    final heroTag = 'add-exercise-hero-${widget.index}';

    final EdgeInsets contentPadding = sessionMode
        ? const EdgeInsets.symmetric(horizontal: 0, vertical: 12)
        : const EdgeInsets.all(16);

    final Widget contentBody = Padding(
      padding: contentPadding,
      child: Column(
        crossAxisAlignment:
            sessionMode ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (sessionMode)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    (_titleCtrl.text.trim().isEmpty
                        ? 'Untitled block'
                        : _titleCtrl.text.trim()),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Block ${widget.index + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kCardText.withValues(alpha: 0.6),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (allowStructureControls && widget.reorderHandle != null) ...[
                  widget.reorderHandle!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.titleEditable)
                        TextField(
                          controller: _titleCtrl,
                          focusNode: _titleFocus,
                          maxLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            letterSpacing: -0.1,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Untitled block',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              letterSpacing: -0.1,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          cursorColor: Colors.white,
                          onChanged: (val) {
                            final trimmed = val.trim();
                            widget.onBlockMetaChanged(
                              trimmed.isEmpty ? null : trimmed,
                              null,
                            );
                          },
                        )
                      else
                        Text(
                          (_titleCtrl.text.trim().isEmpty
                              ? 'Untitled block'
                              : _titleCtrl.text.trim()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            letterSpacing: -0.1,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        'Block ${widget.index + 1}',
                        style: TextStyle(
                          color: kCardText.withValues(alpha: 0.55),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Transform.translate(
                        offset: const Offset(-4, 0),
                        child: _InfoChip(
                          icon: Icons.list_alt_rounded,
                          label:
                              "${block.items.length} ${block.items.length == 1 ? 'Exercise' : 'Exercises'}",
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _HeaderActionBar(
                  onDuplicate: widget.onDuplicate,
                  onDelete: widget.onRemove,
                  onToggleCollapsed: _toggleCollapsed,
                  collapsed: _collapsed,
                  showStructureActions: widget.showStructureControls,
                ),
              ],
            ),
          SizeTransition(
            sizeFactor: _contentCurve,
            axisAlignment: -1.0,
            child: FadeTransition(
              opacity: _contentFade,
              child: SlideTransition(
                position: _contentSlide,
                child: ScaleTransition(
                  scale: _contentScale,
                  child: Column(
                    crossAxisAlignment: sessionMode
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: sessionMode ? 12 : 14),
                      Container(
                        decoration: sessionMode
                            ? null
                            : BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(18),
                              ),
                        padding: EdgeInsets.symmetric(
                          horizontal: sessionMode ? 0 : 12,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: sessionMode
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: sessionMode ? 6 : 12),
                            if (sessionMode)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: Text(
                                  hasType
                                      ? typeInfo!.label.toUpperCase()
                                      : 'SELECT BLOCK TYPE',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: hasType
                                        ? Colors.white
                                        : const Color(0xFFFF6B81)
                                            .withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              )
                            else ...[
                              InkWell(
                                onTap: _toggleTypePicker,
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kCardText.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(18),
                                    border: hasType
                                        ? null
                                        : Border.all(
                                            color: const Color(0xFFFF6B81)
                                                .withValues(alpha: 0.75),
                                            width: 1,
                                          ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          transitionBuilder: (child, anim) =>
                                              FadeTransition(
                                            opacity: anim,
                                            child: SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(0, 0.2),
                                                end: Offset.zero,
                                              ).animate(anim),
                                              child: child,
                                            ),
                                          ),
                                          child: hasType
                                              ? Text(
                                                  typeInfo!.label.toUpperCase(),
                                                  key: const ValueKey(
                                                      'type-set'),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                    letterSpacing: -0.1,
                                                  ),
                                                )
                                              : const Row(
                                                  key:
                                                      ValueKey('type-required'),
                                                  children: [
                                                    Text(
                                                      'BLOCK TYPE',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 16,
                                                        letterSpacing: -0.1,
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    _RequiredBadge(),
                                                  ],
                                                ),
                                        ),
                                      ),
                                      AnimatedRotation(
                                        duration:
                                            const Duration(milliseconds: 240),
                                        curve: Curves.easeOutCubic,
                                        turns: _typeExpanded ? 0.5 : 0.0,
                                        child: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 20,
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: hasType
                                    ? const SizedBox(
                                        height: 8, key: ValueKey('ok-spacer'))
                                    : Padding(
                                        key: const ValueKey('err'),
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline,
                                                size: 16,
                                                color: Color(0xFFFF6B81)),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Select a block type to continue',
                                              style: TextStyle(
                                                color: const Color(0xFFFF6B81)
                                                    .withValues(alpha: 0.9),
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              ClipRect(
                                child: SizeTransition(
                                  sizeFactor: _expandCurve,
                                  axisAlignment: -1.0,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Column(
                                      children: _buildAnimatedTypePills(type),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (sessionMode && !hasType)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'No block type selected',
                                  style: TextStyle(
                                    color: const Color(0xFFFF6B81)
                                        .withValues(alpha: 0.85),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            if (block.items.isEmpty)
                              Text(
                                'No exercises',
                                style: TextStyle(
                                  color: kCardText.withValues(alpha: 0.55),
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            else ...[
                              if (allowStructureControls)
                                ReorderableListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: block.items.length,
                                  onReorder: (oldIndex, newIndex) {
                                    if (oldIndex < newIndex) {
                                      newIndex -= 1;
                                    }
                                    widget.onReorderExercise(
                                        oldIndex, newIndex);
                                  },
                                  itemBuilder: (context, i) =>
                                      _buildExerciseRow(block, i),
                                )
                              else
                                Column(
                                  children: List.generate(
                                    block.items.length,
                                    (i) => _buildExerciseRow(block, i),
                                  ),
                                ),
                            ],
                            if (!sessionMode) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                label: 'Add exercise',
                                button: true,
                                enabled: hasType,
                                child: GestureDetector(
                                  onTap: hasType
                                      ? () {
                                          Navigator.of(context)
                                              .push<List<Exercise>>(
                                            AddExercisePopupRoute(
                                                heroTag: heroTag),
                                          )
                                              .then((exercises) {
                                            if (exercises != null &&
                                                exercises.isNotEmpty) {
                                              widget.onAddExercises(exercises);
                                            }
                                          });
                                        }
                                      : null,
                                  behavior: HitTestBehavior.opaque,
                                  child: Opacity(
                                    opacity: hasType ? 1.0 : 0.55,
                                    child: Hero(
                                      tag: heroTag,
                                      child: _buildAddExercisePill(),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: widget.onDuplicate,
                                    icon: Icon(
                                      Icons.copy_outlined,
                                      color: kCardText.withValues(alpha: 0.75),
                                      size: 20,
                                    ),
                                    tooltip: 'Duplicate block',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: widget.onRemove,
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Color(0xFFFF6B81),
                                    ),
                                    tooltip: 'Remove block',
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final Widget content = sessionMode
        ? Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: contentBody,
            ),
          )
        : contentBody;

    if (sessionMode) {
      return Padding(
        key: widget.key,
        padding: widget.margin,
        child: content,
      );
    }

    return Container(
      key: widget.key,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }

  List<Widget> _buildAnimatedTypePills(BlockType? current) {
    final types = BlockType.values;
    return List<Widget>.generate(types.length, (i) {
      final double start = (0.05 + i * 0.08).clamp(0.0, 1.0);
      final double end = (start + 0.55).clamp(0.0, 1.0);

      final fade = CurvedAnimation(
        parent: _pickerCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
        reverseCurve: Curves.easeInCubic,
      );

      final slide = Tween<Offset>(
        begin: const Offset(0, -0.25),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _pickerCtrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
          reverseCurve: Curves.easeInCubic,
        ),
      );

      final scale = Tween<double>(begin: 0.94, end: 1.0).animate(
        CurvedAnimation(
          parent: _pickerCtrl,
          curve: Interval(start, end, curve: Curves.easeOutBack),
          reverseCurve: Curves.easeIn,
        ),
      );

      final t = types[i];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(
              scale: scale,
              child: BlockTypePill(
                type: t,
                selected: current == t,
                info: blockTypeInfo[t]!,
                onTap: () => _selectType(t),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildAddExercisePill() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kCardText.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 16, color: kCardText),
          SizedBox(width: 8),
          Text(
            'Add exercise',
            style: TextStyle(
              color: kCardText,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class BlockDragHandle extends StatelessWidget {
  const BlockDragHandle({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final Color border = kCardText.withValues(alpha: 0.14);
    final Color background = kCardText.withValues(alpha: 0.08);

    return Tooltip(
      message: 'Drag to reorder block',
      waitDuration: const Duration(milliseconds: 320),
      child: ReorderableDelayedDragStartListener(
        index: index,
        child: Semantics(
          button: true,
          label: 'Reorder block ${index + 1}',
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.drag_indicator_rounded,
              size: 16,
              color: kCardText.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequiredBadge extends StatelessWidget {
  const _RequiredBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFFF6B81).withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: const Text(
        'REQUIRED',
        style: TextStyle(
          color: Color(0xFFFF6B81),
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color textColor = Colors.white.withValues(alpha: 0.85);
    final Color iconColor = Colors.white.withValues(alpha: 0.7);
    final Color background = kCardText.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActionBar extends StatelessWidget {
  const _HeaderActionBar({
    required this.onDuplicate,
    required this.onDelete,
    required this.onToggleCollapsed,
    required this.collapsed,
    this.showStructureActions = true,
  });

  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onToggleCollapsed;
  final bool collapsed;
  final bool showStructureActions;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (showStructureActions) {
      children.addAll([
        _HeaderIconChip(
          icon: Icons.copy_rounded,
          tooltip: 'Duplicate block',
          onTap: onDuplicate,
        ),
        _HeaderIconChip(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Remove block',
          onTap: onDelete,
          destructive: true,
        ),
      ]);
    }
    children.add(
      _HeaderIconChip(
        icon: collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
        tooltip: collapsed ? 'Expand block' : 'Collapse block',
        onTap: onToggleCollapsed,
      ),
    );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: children,
    );
  }
}

class _HeaderIconChip extends StatelessWidget {
  const _HeaderIconChip({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = destructive
        ? const Color(0xFFFF6B81)
        : Colors.white.withValues(alpha: 0.85);
    final Color background = destructive
        ? const Color(0xFFFF6B81).withValues(alpha: 0.12)
        : kCardText.withValues(alpha: 0.08);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 320),
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

class BlockTypePill extends StatelessWidget {
  final BlockType type;
  final bool selected;
  final BlockTypeInfo info;
  final VoidCallback onTap;

  const BlockTypePill({
    super.key,
    required this.type,
    required this.selected,
    required this.info,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = selected
        ? kCardText.withValues(alpha: 0.22)
        : kCardText.withValues(alpha: 0.12);
    final Color labelColor =
        selected ? Colors.white : kCardText.withValues(alpha: 0.85);
    final Color hintColor =
        selected ? Colors.white70 : kCardText.withValues(alpha: 0.5);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              info.label,
              style: TextStyle(
                color: labelColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              info.hint,
              style: TextStyle(
                color: hintColor,
                fontSize: 13,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
