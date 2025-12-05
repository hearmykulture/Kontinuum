// lib/ui/workout/special_block_cards.dart
import 'package:flutter/material.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/services/exercise_library_service.dart';
import 'package:kontinuum/utils/text_format.dart';
import 'package:kontinuum/ui/common/safe_network_image.dart';
import 'workout_editor_constants.dart';
import 'workout_editor_widgets.dart';
import 'add_exercise_popup_route.dart';

/// Break block card with duration selector and notes
class BreakBlockCard extends StatefulWidget {
  const BreakBlockCard({
    super.key,
    required this.block,
    required this.index,
    required this.onUpdate,
    required this.onRemove,
    this.reorderHandle,
  });

  final WorkoutBlock block;
  final int index;
  final void Function(WorkoutBlock updated) onUpdate;
  final VoidCallback onRemove;
  final Widget? reorderHandle;

  @override
  State<BreakBlockCard> createState() => _BreakBlockCardState();
}

class _BreakBlockCardState extends State<BreakBlockCard>
    with SingleTickerProviderStateMixin {
  late TextEditingController _notesCtrl;
  late TextEditingController _titleCtrl;
  String _breakType = 'standard'; // quick, standard, extended, custom
  int _durationSec = 300; // default 5 minutes
  String _notesText = '';
  bool _collapsed = false;
  bool _noteExpanded = false;
  bool _typeExpanded = false;
  final FocusNode _noteFocus = FocusNode();
  final FocusNode _titleFocus = FocusNode();
  late final AnimationController _pickerCtrl;
  late final Animation<double> _expandCurve;

  @override
  void initState() {
    super.initState();
    _parseBlockData();
    _notesCtrl = TextEditingController(text: _notesText);
    // Initialize with empty text if title is null, empty, or the default placeholder
    final initialTitle = widget.block.title;
    final isEmpty = initialTitle == null || initialTitle.isEmpty || initialTitle == 'Break';
    _titleCtrl = TextEditingController(text: isEmpty ? '' : initialTitle);
    // Always expand notes by default for break blocks
    _noteExpanded = true;
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
    // Listen for focus changes to save when user leaves the field
    _titleFocus.addListener(_onTitleFocusChange);
  }

  void _onTitleFocusChange() {
    if (!_titleFocus.hasFocus) {
      // User left the field - apply trimming and save (allow empty)
      final trimmed = _titleCtrl.text.trim();

      if (trimmed != widget.block.title) {
        widget.onUpdate(widget.block.copyWith(
          title: trimmed.isEmpty ? null : trimmed,
        ));
      }
    }
  }

  @override
  void didUpdateWidget(BreakBlockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync title controller if title changed from outside
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
  }

  void _parseBlockData() {
    // Parse duration from note field (format: "duration:300|type:standard|notes:...")
    final note = widget.block.note ?? '';
    final parts = note.split('|');
    for (final part in parts) {
      if (part.startsWith('duration:')) {
        _durationSec = int.tryParse(part.substring(9)) ?? 300;
      } else if (part.startsWith('type:')) {
        _breakType = part.substring(5);
      } else if (part.startsWith('notes:')) {
        _notesText = part.substring(6);
      }
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _titleCtrl.dispose();
    _noteFocus.dispose();
    _titleFocus.dispose();
    _pickerCtrl.dispose();
    super.dispose();
  }

  void _toggleCollapsed() {
    setState(() => _collapsed = !_collapsed);
  }

  void _toggleNote() {
    final next = !_noteExpanded;
    setState(() => _noteExpanded = next);
    if (next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _noteFocus.requestFocus();
        }
      });
    }
  }

  void _toggleTypePicker() {
    setState(() => _typeExpanded = !_typeExpanded);
    if (_typeExpanded) {
      _pickerCtrl.forward();
    } else {
      _pickerCtrl.reverse();
    }
  }

  void _selectBreakType(String type) {
    _updateBreakType(type);
    setState(() => _typeExpanded = false);
    _pickerCtrl.reverse();
  }

  void _updateBreakType(String type) {
    setState(() {
      _breakType = type;
      // Auto-set duration based on type
      switch (type) {
        case 'quick':
          _durationSec = 45;
          break;
        case 'standard':
          _durationSec = 300;
          break;
        case 'extended':
          _durationSec = 600;
          break;
        case 'custom':
          // Keep current duration
          break;
      }
    });
    _saveChanges();
  }

  void _updateDuration(int seconds) {
    setState(() {
      _durationSec = seconds;
      // Switch to custom if user manually edits duration
      if (_breakType != 'custom') {
        _breakType = 'custom';
      }
    });
    _saveChanges();
  }

  void _saveChanges() {
    final noteData =
        'duration:$_durationSec|type:$_breakType|notes:${_notesCtrl.text}';
    widget.onUpdate(widget.block.copyWith(note: noteData));
  }

  void _duplicateBlock() {
    // TODO: Implement block duplication
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (secs == 0) return '${mins}m';
    return '${mins}m ${secs}s';
  }

  String _getBreakTypeLabel(String type) {
    switch (type) {
      case 'quick':
        return 'Quick';
      case 'standard':
        return 'Standard';
      case 'extended':
        return 'Extended';
      case 'custom':
        return 'Custom';
      default:
        return 'Standard';
    }
  }

  List<Widget> _buildAnimatedBreakTypePills(String current) {
    final types = [
      {'id': 'quick', 'label': 'Quick', 'duration': '45 seconds'},
      {'id': 'standard', 'label': 'Standard', 'duration': '5 minutes'},
      {'id': 'extended', 'label': 'Extended', 'duration': '10 minutes'},
      {'id': 'custom', 'label': 'Custom', 'duration': 'Set your own duration'},
    ];

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

      final type = types[i];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(
              scale: scale,
              child: BreakTypePill(
                typeId: type['id']!,
                label: type['label']!,
                duration: type['duration']!,
                selected: current == type['id'],
                onTap: () => _selectBreakType(type['id']!),
              ),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool noteActive = _noteExpanded || (_notesCtrl.text.trim().isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: WorkoutAccordionGroup(
        radius: 16,
        children: [
          // Header row (mission-style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                if (widget.reorderHandle != null) ...[
                  widget.reorderHandle!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _titleCtrl,
                        focusNode: _titleFocus,
                        maxLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Untitled break',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        cursorColor: Colors.white,
                        onSubmitted: (val) {
                          // On submit, unfocus to trigger save
                          _titleFocus.unfocus();
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDuration(_durationSec),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xB3FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Icon pill on right (mission-style)
                InkWell(
                  onTap: _toggleCollapsed,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.pause_circle_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Collapsible content
          WorkoutAccordionInlineDrop(
            expanded: !_collapsed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF232323),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0x22FFFFFF),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Break type picker
                    InkWell(
                      onTap: _toggleTypePicker,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B1B),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _getBreakTypeLabel(_breakType).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            AnimatedRotation(
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              turns: _typeExpanded ? 0.5 : 0.0,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRect(
                      child: SizeTransition(
                        sizeFactor: _expandCurve,
                        axisAlignment: -1.0,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            children: _buildAnimatedBreakTypePills(_breakType),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Duration display pill (always visible, editable only for custom)
                    InkWell(
                      onTap: _breakType == 'custom'
                          ? () => _showDurationEditor(context)
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B1B),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatDuration(_durationSec),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            if (_breakType == 'custom')
                              Icon(
                                Icons.edit,
                                size: 18,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notes button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SurfaceIconButton(
                          icon: noteActive
                              ? Icons.sticky_note_2_rounded
                              : Icons.sticky_note_2_outlined,
                          tooltip: noteActive ? 'Hide notes' : 'Add notes',
                          onTap: _toggleNote,
                          active: noteActive,
                        ),
                      ],
                    ),

                    // Notes field (collapsible)
                    if (_noteExpanded) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _notesCtrl,
                        focusNode: _noteFocus,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => _saveChanges(),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Hydration, stretching, equipment setup...',
                          hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFF1B1B1B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        cursorColor: Colors.white,
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Structure controls (duplicate/delete)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _duplicateBlock,
                          icon: Icon(
                            Icons.copy_outlined,
                            color: Colors.white.withValues(alpha: 0.75),
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDurationEditor(BuildContext context) async {
    final controller = TextEditingController(
      text: (_durationSec ~/ 60).toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text(
          'Custom Duration',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Minutes',
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            enabledBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
          cursorColor: Colors.white,
          onSubmitted: (val) {
            final mins = int.tryParse(val);
            if (mins != null && mins > 0) {
              Navigator.of(ctx).pop(mins * 60);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () {
              final mins = int.tryParse(controller.text);
              if (mins != null && mins > 0) {
                Navigator.of(ctx).pop(mins * 60);
              }
            },
            child: const Text(
              'Set',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      _updateDuration(result);
    }
  }
}

class BreakTypePill extends StatelessWidget {
  final String typeId;
  final String label;
  final String duration;
  final bool selected;
  final VoidCallback onTap;

  const BreakTypePill({
    super.key,
    required this.typeId,
    required this.label,
    required this.duration,
    required this.selected,
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
              label,
              style: TextStyle(
                color: labelColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              duration,
              style: TextStyle(
                color: hintColor,
                fontSize: 13,
                height: 1.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Warmup/Cooldown block card with exercise list with full prescription
class WarmupCooldownBlockCard extends StatefulWidget {
  const WarmupCooldownBlockCard({
    super.key,
    required this.block,
    required this.index,
    required this.onUpdate,
    required this.onRemove,
    required this.onAddExercises,
    required this.loadUnit,
    required this.onLoadUnitChanged,
    this.reorderHandle,
  });

  final WorkoutBlock block;
  final int index;
  final void Function(WorkoutBlock updated) onUpdate;
  final VoidCallback onRemove;
  final void Function(List<Exercise> exercises) onAddExercises;
  final WeightUnit loadUnit;
  final ValueChanged<WeightUnit> onLoadUnitChanged;
  final Widget? reorderHandle;

  @override
  State<WarmupCooldownBlockCard> createState() =>
      _WarmupCooldownBlockCardState();
}

class _WarmupCooldownBlockCardState extends State<WarmupCooldownBlockCard> {
  bool _isWarmup = true; // true = warmup, false = cooldown
  bool _collapsed = false;
  late TextEditingController _titleCtrl;
  final FocusNode _titleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Parse from note field (format: "type:warmup" or "type:cooldown")
    // Fall back to parsing title for backwards compatibility
    final note = widget.block.note ?? '';
    if (note.startsWith('type:')) {
      _isWarmup = note == 'type:warmup';
    } else {
      _isWarmup = widget.block.title?.toLowerCase().contains('warmup') ?? true;
    }
    // Initialize with empty text if title is null, empty, or the default placeholder
    final initialTitle = widget.block.title;
    final defaultTitle = _isWarmup ? 'Warmup' : 'Cooldown';
    final isEmpty = initialTitle == null || initialTitle.isEmpty || initialTitle == defaultTitle;
    _titleCtrl = TextEditingController(text: isEmpty ? '' : initialTitle);
    // Listen for focus changes to save when user leaves the field
    _titleFocus.addListener(_onFocusChange);
  }

  String? _normalizedTitle() {
    final trimmed = _titleCtrl.text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _onFocusChange() {
    if (!_titleFocus.hasFocus) {
      final normalized = _normalizedTitle();
      if (normalized != widget.block.title) {
        widget.onUpdate(widget.block.copyWith(
          title: normalized,
        ));
      }
    }
  }

  @override
  void didUpdateWidget(WarmupCooldownBlockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync title controller if title changed from outside
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
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _toggleType() {
    final nextIsWarmup = !_isWarmup;
    final normalizedTitle = _normalizedTitle();
    setState(() => _isWarmup = nextIsWarmup);
    widget.onUpdate(widget.block.copyWith(
      title: normalizedTitle,
      note: nextIsWarmup ? 'type:warmup' : 'type:cooldown',
    ));
  }

  void _toggleCollapsed() {
    setState(() => _collapsed = !_collapsed);
  }

  void _openExercisePicker(BuildContext context) {
    final heroTag = 'warmup_cooldown_add_${widget.index}';
    Navigator.of(context).push<List<Exercise>>(
      AddExercisePopupRoute(heroTag: heroTag),
    ).then((exercises) {
      if (exercises != null && exercises.isNotEmpty) {
        widget.onAddExercises(exercises);
      }
    });
  }

  void _duplicateBlock() {
    // TODO: Implement block duplication
  }

  @override
  Widget build(BuildContext context) {
    final String exerciseCount =
        "${widget.block.items.length} ${widget.block.items.length == 1 ? 'Exercise' : 'Exercises'}";
    final String subtitle = exerciseCount;
    final heroTag = 'add-exercise-hero-warmup-cooldown-${widget.index}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: WorkoutAccordionGroup(
        radius: 16,
        children: [
          // Header row (mission-style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                if (widget.reorderHandle != null) ...[
                  widget.reorderHandle!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _titleCtrl,
                        focusNode: _titleFocus,
                        maxLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: _isWarmup ? 'Untitled warmup' : 'Untitled cooldown',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        cursorColor: Colors.white,
                        onSubmitted: (val) {
                          // On submit, unfocus to trigger save
                          _titleFocus.unfocus();
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xB3FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Icon pill on right (mission-style)
                InkWell(
                  onTap: _toggleCollapsed,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isWarmup ? Icons.whatshot : Icons.self_improvement,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Collapsible content
          WorkoutAccordionInlineDrop(
            expanded: !_collapsed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF232323),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0x22FFFFFF),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Toggle warmup/cooldown button
                    InkWell(
                      onTap: _toggleType,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B1B),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isWarmup ? Icons.whatshot : Icons.self_improvement,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isWarmup ? 'WARMUP' : 'COOLDOWN',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.swap_horiz,
                              color: Color(0xB3FFFFFF),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Exercise list
                    if (widget.block.items.isEmpty)
                      Text(
                        'No exercises',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      Column(
                        children: List.generate(
                          widget.block.items.length,
                          (i) => _WarmupExerciseRow(
                            key: ValueKey('${widget.block.items[i].exerciseId}-$i'),
                            item: widget.block.items[i],
                            loadUnit: widget.loadUnit,
                            onLoadUnitChanged: widget.onLoadUnitChanged,
                            onItemUpdated: (updated) {
                              final items = List<WorkoutItem>.from(widget.block.items);
                              items[i] = updated;
                              widget.onUpdate(widget.block.copyWith(items: items));
                            },
                            onRemove: () {
                              final items = List<WorkoutItem>.from(widget.block.items);
                              items.removeAt(i);
                              widget.onUpdate(widget.block.copyWith(items: items));
                            },
                            onDuplicate: () {
                              final items = List<WorkoutItem>.from(widget.block.items);
                              items.insert(i + 1, widget.block.items[i]);
                              widget.onUpdate(widget.block.copyWith(items: items));
                            },
                            onViewDetails: () {
                              // Show exercise detail popup
                              final exercise = ExerciseLibraryService.instance
                                  .getById(widget.block.items[i].exerciseId);
                              if (exercise != null) {
                                Navigator.of(context).push(
                                  ExerciseDetailsPopupRoute(
                                    exerciseId: exercise.id,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    // Add exercise button
                    GestureDetector(
                      onTap: () => _openExercisePicker(context),
                      behavior: HitTestBehavior.opaque,
                      child: Hero(
                        tag: heroTag,
                        child: Container(
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
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Structure controls (duplicate/delete)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _duplicateBlock,
                          icon: Icon(
                            Icons.copy_outlined,
                            color: Colors.white.withValues(alpha: 0.75),
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarmupExerciseRow extends StatefulWidget {
  const _WarmupExerciseRow({
    super.key,
    required this.item,
    required this.loadUnit,
    required this.onLoadUnitChanged,
    required this.onItemUpdated,
    required this.onRemove,
    required this.onDuplicate,
    required this.onViewDetails,
  });

  final WorkoutItem item;
  final WeightUnit loadUnit;
  final ValueChanged<WeightUnit> onLoadUnitChanged;
  final ValueChanged<WorkoutItem> onItemUpdated;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback onViewDetails;

  @override
  State<_WarmupExerciseRow> createState() => _WarmupExerciseRowState();
}

enum _SegmentKind { sets, reps, duration, rest, load }

class _SegmentConfig {
  const _SegmentConfig({
    required this.kind,
    required this.label,
    required this.value,
    required this.enabled,
    required this.isPlaceholder,
    this.onTap,
    this.trailing,
  });

  final _SegmentKind kind;
  final String label;
  final String value;
  final bool enabled;
  final bool isPlaceholder;
  final VoidCallback? onTap;
  final Widget? trailing;
}

class _WarmupExerciseRowState extends State<_WarmupExerciseRow> {
  bool _noteExpanded = false;
  bool _prescriptionExpanded = false;
  late final TextEditingController _noteCtrl;
  final FocusNode _noteFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.item.notes ?? '');
    if (_noteCtrl.text.trim().isNotEmpty) {
      _noteExpanded = true;
    }
  }

  @override
  void didUpdateWidget(covariant _WarmupExerciseRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.notes != widget.item.notes) {
      final newNote = widget.item.notes ?? '';
      if (newNote != _noteCtrl.text) {
        _noteCtrl.text = newNote;
      }
      if (newNote.isNotEmpty && !_noteExpanded) {
        setState(() => _noteExpanded = true);
      }
      if (newNote.isEmpty && !_noteFocus.hasFocus) {
        setState(() => _noteExpanded = false);
      }
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _toggleNote() {
    final next = !_noteExpanded;
    setState(() => _noteExpanded = next);
    if (next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _noteFocus.requestFocus();
        }
      });
    }
  }

  void _togglePrescription() {
    setState(() => _prescriptionExpanded = !_prescriptionExpanded);
  }

  Future<void> _editSets() async {
    final controller = TextEditingController(
      text: widget.item.targetSets.toString(),
    );
    final result = await _showNumberEditor(
      title: 'Target Sets',
      controller: controller,
      hint: 'e.g., 3',
    );
    if (result != null && result > 0) {
      _updateItem(targetSets: result);
    }
  }

  Future<void> _editReps() async {
    final controller = TextEditingController(
      text: (widget.item.targetReps ?? 10).toString(),
    );
    final result = await _showNumberEditor(
      title: 'Target Reps',
      controller: controller,
      hint: 'e.g., 10',
    );
    if (result != null && result > 0) {
      _updateItem(targetReps: result);
    }
  }

  Future<void> _editDuration() async {
    final controller = TextEditingController(
      text: (widget.item.targetTimeSec ?? 30).toString(),
    );
    final result = await _showNumberEditor(
      title: 'Duration (seconds)',
      controller: controller,
      hint: 'e.g., 30',
    );
    if (result != null && result > 0) {
      _updateItem(targetTimeSec: result);
    }
  }

  Future<void> _editRest() async {
    final controller = TextEditingController(
      text: (widget.item.restSec ?? 60).toString(),
    );
    final result = await _showNumberEditor(
      title: 'Rest Time (seconds)',
      controller: controller,
      hint: 'e.g., 60',
    );
    if (result != null && result >= 0) {
      _updateItem(restSec: result);
    }
  }

  Future<void> _editLoad() async {
    final displayValue = widget.item.targetLoad ?? 0;
    final displayUnit = widget.loadUnit == WeightUnit.kg ? displayValue : _kgToLb(displayValue);

    final controller = TextEditingController(
      text: displayUnit.toStringAsFixed(displayUnit == displayValue ? 0 : 1),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: Text(
          'Target Load (${widget.loadUnit.label})',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: widget.loadUnit.label.toUpperCase(),
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            hintText: 'e.g., 45',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
          cursorColor: Colors.white,
          onSubmitted: (val) {
            final load = double.tryParse(val);
            if (load != null && load >= 0) {
              // Convert to kg if needed
              final loadKg = widget.loadUnit == WeightUnit.kg ? load : load / 2.2046226218;
              Navigator.of(ctx).pop(loadKg);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () {
              final load = double.tryParse(controller.text);
              if (load != null && load >= 0) {
                // Convert to kg if needed
                final loadKg = widget.loadUnit == WeightUnit.kg ? load : load / 2.2046226218;
                Navigator.of(ctx).pop(loadKg);
              }
            },
            child: const Text(
              'Set',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      _updateItem(targetLoad: result);
    }
  }

  Future<int?> _showNumberEditor({
    required String title,
    required TextEditingController controller,
    required String hint,
  }) async {
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
          cursorColor: Colors.white,
          onSubmitted: (val) {
            final value = int.tryParse(val);
            if (value != null) {
              Navigator.of(ctx).pop(value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null) {
                Navigator.of(ctx).pop(value);
              }
            },
            child: const Text(
              'Set',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _updateItem({
    int? targetSets,
    int? targetReps,
    int? targetTimeSec,
    int? restSec,
    double? targetLoad,
    String? notes,
  }) {
    final updated = WorkoutItem(
      exerciseId: widget.item.exerciseId,
      targetSets: targetSets ?? widget.item.targetSets,
      targetReps: targetReps ?? widget.item.targetReps,
      targetTimeSec: targetTimeSec ?? widget.item.targetTimeSec,
      restSec: restSec ?? widget.item.restSec,
      targetLoad: targetLoad ?? widget.item.targetLoad,
      notes: notes ?? widget.item.notes,
      cueChips: widget.item.cueChips,
      formChecks: widget.item.formChecks,
      consecutiveMisses: widget.item.consecutiveMisses,
      lastSuggestedLoadKg: widget.item.lastSuggestedLoadKg,
      lastTargetReps: widget.item.lastTargetReps,
      lastLoggedRpe: widget.item.lastLoggedRpe,
      adaptiveSetsEnabled: widget.item.adaptiveSetsEnabled,
      adaptivePercent: widget.item.adaptivePercent,
    );
    widget.onItemUpdated(updated);
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    if (seconds < 60) return '${seconds}s';

    final int minutes = seconds ~/ 60;
    final int remaining = seconds % 60;
    if (remaining == 0) {
      return '${minutes}m';
    }
    return '${minutes}m ${remaining}s';
  }

  String _formatLoad(double load) {
    final double display =
        widget.loadUnit == WeightUnit.kg ? load : _kgToLb(load);
    final double absDisplay = display.abs();
    final bool isWhole = (absDisplay - absDisplay.round()).abs() < 0.01;
    final int precision = isWhole ? 0 : (absDisplay < 10 ? 2 : 1);
    final String value = display.toStringAsFixed(precision);
    return '$value ${widget.loadUnit.label}';
  }

  double _kgToLb(double kg) => kg * 2.2046226218;

  List<_SegmentConfig> _buildSegmentData() {
    return [
      _SegmentConfig(
        kind: _SegmentKind.load,
        label: 'Load',
        value: widget.item.targetLoad != null
            ? _formatLoad(widget.item.targetLoad!)
            : '—',
        onTap: _editLoad,
        enabled: true,
        isPlaceholder: widget.item.targetLoad == null,
        trailing: _WeightUnitToggle(
          selected: widget.loadUnit,
          onChanged: widget.onLoadUnitChanged,
        ),
      ),
      _SegmentConfig(
        kind: _SegmentKind.sets,
        label: 'Sets',
        value: widget.item.targetSets > 0 ? widget.item.targetSets.toString() : '—',
        onTap: _editSets,
        enabled: true,
        isPlaceholder: widget.item.targetSets <= 0,
      ),
      _SegmentConfig(
        kind: _SegmentKind.reps,
        label: 'Reps',
        value: widget.item.targetReps?.toString() ?? '—',
        onTap: _editReps,
        enabled: true,
        isPlaceholder: widget.item.targetReps == null,
      ),
      _SegmentConfig(
        kind: _SegmentKind.duration,
        label: 'Duration',
        value: widget.item.targetTimeSec != null
            ? _formatDuration(widget.item.targetTimeSec!)
            : '—',
        onTap: _editDuration,
        enabled: true,
        isPlaceholder: widget.item.targetTimeSec == null,
      ),
      _SegmentConfig(
        kind: _SegmentKind.rest,
        label: 'Rest',
        value: widget.item.restSec != null
            ? _formatDuration(widget.item.restSec!)
            : '—',
        onTap: _editRest,
        enabled: true,
        isPlaceholder: widget.item.restSec == null,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Look up exercise
    final exercise = ExerciseLibraryService.instance.getById(widget.item.exerciseId);
    final String name = exercise?.name ?? 'Unknown exercise';
    final String displayName = formatTitleCase(name);
    final String? mediaUrl = exercise?.mediaUrl;
    final String musclesLabel = exercise == null
        ? ''
        : exercise.muscles.map(formatTitleCase).take(2).join(', ');

    final bool noteActive = _noteExpanded || (_noteCtrl.text.trim().isNotEmpty);
    final segments = _buildSegmentData();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardText.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise info section (name, muscles, gif)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (musclesLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        musclesLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _FrozenGifThumbnail(url: mediaUrl),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Prescription section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Prescription',
                    style: TextStyle(
                      color: kCardText.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (!_prescriptionExpanded) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Tap to expand',
                      style: TextStyle(
                        color: kCardText.withValues(alpha: 0.35),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    onPressed: _togglePrescription,
                    visualDensity: VisualDensity.compact,
                    tooltip: _prescriptionExpanded ? 'Collapse details' : 'Expand details',
                    icon: Icon(
                      _prescriptionExpanded ? Icons.expand_less : Icons.expand_more,
                      color: kCardText.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: _CollapsedStrip(
                  segments: segments,
                  onTap: _togglePrescription,
                ),
                secondChild: _PrescriptionStrip(
                  segments: segments,
                ),
                crossFadeState: _prescriptionExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
                sizeCurve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SurfaceIconButton(
                icon: noteActive
                    ? Icons.sticky_note_2_rounded
                    : Icons.sticky_note_2_outlined,
                tooltip: noteActive ? 'Hide exercise notes' : 'Add exercise notes',
                onTap: _toggleNote,
                active: noteActive,
              ),
              const SizedBox(width: 16),
              _SurfaceIconButton(
                icon: Icons.info_outline,
                tooltip: 'Exercise details',
                onTap: widget.onViewDetails,
              ),
              const SizedBox(width: 16),
              _SurfaceIconButton(
                icon: Icons.copy_rounded,
                tooltip: 'Duplicate exercise',
                onTap: widget.onDuplicate,
              ),
              const SizedBox(width: 16),
              _SurfaceIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Remove exercise',
                onTap: widget.onRemove,
                destructive: true,
              ),
            ],
          ),
          // Notes field (collapsible)
          if (_noteExpanded) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              focusNode: _noteFocus,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Exercise notes...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: const Color(0xFF1B1B1B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              cursorColor: Colors.white,
              onChanged: (val) {
                final trimmed = val.trim();
                _updateItem(notes: trimmed.isEmpty ? null : trimmed);
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Surface icon button matching the standard exercise row style
class _SurfaceIconButton extends StatelessWidget {
  const _SurfaceIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.destructive = false,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool destructive;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = destructive
        ? const Color(0xFFFF6B81)
        : Colors.white.withValues(alpha: active ? 0.98 : 0.9);
    final Color background = destructive
        ? const Color(0xFFFF6B81).withValues(alpha: 0.12)
        : (active
            ? kCardText.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.08));
    final Border border = destructive
        ? Border.all(color: const Color(0xFFFF6B81).withValues(alpha: 0.35))
        : Border.all(
            color: active
                ? kCardText.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.12),
          );

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: border,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

const List<WeightUnit> _weightToggleOrder = [WeightUnit.lb, WeightUnit.kg];

class _WeightUnitToggle extends StatelessWidget {
  const _WeightUnitToggle({
    required this.selected,
    required this.onChanged,
  });

  final WeightUnit selected;
  final ValueChanged<WeightUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = kCardText.withValues(alpha: 0.18);
    final Color background = kCardText.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final unit in _weightToggleOrder)
            _WeightUnitChip(
              unit: unit,
              selected: unit == selected,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _WeightUnitChip extends StatelessWidget {
  const _WeightUnitChip({
    required this.unit,
    required this.selected,
    required this.onChanged,
  });

  final WeightUnit unit;
  final bool selected;
  final ValueChanged<WeightUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color selectedBg = kCardText.withValues(alpha: 0.24);
    final Color selectedFg = kCardBg;
    final Color unselectedFg = kCardText.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => onChanged(unit),
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            unit.label.toUpperCase(),
            style: TextStyle(
              color: selected ? selectedFg : unselectedFg,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedStrip extends StatelessWidget {
  const _CollapsedStrip({
    required this.segments,
    required this.onTap,
  });

  final List<_SegmentConfig> segments;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = kCardText.withValues(alpha: 0.06);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kCardText.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final segment in segments)
                _CollapsedSegmentPreview(segment: segment),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsedSegmentPreview extends StatelessWidget {
  const _CollapsedSegmentPreview({required this.segment});

  final _SegmentConfig segment;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = TextStyle(
      color: kCardText.withValues(alpha: 0.45),
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    );
    final TextStyle valueStyle = TextStyle(
      color:
          segment.isPlaceholder ? kCardText.withValues(alpha: 0.55) : kCardText,
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.05,
    );

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${segment.label.toUpperCase()}: ',
            style: labelStyle,
          ),
          TextSpan(
            text: segment.value,
            style: valueStyle,
          ),
        ],
      ),
    );
  }
}

class _PrescriptionStrip extends StatelessWidget {
  const _PrescriptionStrip({required this.segments});

  final List<_SegmentConfig> segments;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();

    final Color bg = kCardText.withValues(alpha: 0.06);
    final Color divider = kCardText.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kCardText.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool useWrap = constraints.maxWidth < 420;

          if (useWrap) {
            final double spacing = 8;
            final double runSpacing = 6;
            final double width = constraints.maxWidth < 280
                ? constraints.maxWidth
                : (constraints.maxWidth < 520
                    ? (constraints.maxWidth - spacing) / 2
                    : constraints.maxWidth / segments.length);

            return Wrap(
              spacing: spacing,
              runSpacing: runSpacing,
              children: [
                for (final config in segments)
                  SizedBox(
                    width: width.clamp(0.0, constraints.maxWidth).toDouble(),
                    child: _PrescriptionSegment(
                      config: config,
                      compactLayout: constraints.maxWidth < 360,
                    ),
                  ),
              ],
            );
          }

          return IntrinsicHeight(
            child: Row(
              children: [
                for (int i = 0; i < segments.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: divider,
                    ),
                  Expanded(
                    child: _PrescriptionSegment(
                      config: segments[i],
                      compactLayout: false,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PrescriptionSegment extends StatefulWidget {
  const _PrescriptionSegment({
    required this.config,
    required this.compactLayout,
  });

  final _SegmentConfig config;
  final bool compactLayout;

  @override
  State<_PrescriptionSegment> createState() => _PrescriptionSegmentState();
}

class _PrescriptionSegmentState extends State<_PrescriptionSegment> {
  bool _hovering = false;

  void _updateHover(bool value) {
    if (!mounted) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.config.enabled && widget.config.onTap != null;
    final TextStyle labelStyle = TextStyle(
      color: kCardText.withValues(alpha: 0.48),
      fontSize: widget.compactLayout ? 10.5 : 11.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );
    final TextStyle valueStyle = TextStyle(
      color: widget.config.isPlaceholder
          ? kCardText.withValues(alpha: 0.65)
          : kCardText,
      fontSize: widget.compactLayout ? 13 : 14,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
    );

    return MouseRegion(
      onEnter: (_) => _updateHover(true),
      onExit: (_) => _updateHover(false),
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (value) => _updateHover(value),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? widget.config.onTap : null,
            borderRadius: BorderRadius.circular(9),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: _hovering && enabled
                    ? kCardText.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              constraints: const BoxConstraints(minHeight: 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.config.label.toUpperCase(), style: labelStyle),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          widget.config.value,
                          style: valueStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.config.trailing != null) ...[
                        const SizedBox(width: 8),
                        widget.config.trailing!,
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frozen GIF thumbnail for exercise preview
class _FrozenGifThumbnail extends StatefulWidget {
  const _FrozenGifThumbnail({
    required this.url,
  });

  final String? url;

  @override
  State<_FrozenGifThumbnail> createState() => _FrozenGifThumbnailState();
}

class _FrozenGifThumbnailState extends State<_FrozenGifThumbnail> {
  Widget? _frozenFrame;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.fitness_center,
        size: 22,
        color: Colors.black.withValues(alpha: 0.4),
      ),
    );

    final url = widget.url;
    if (url == null || url.trim().isEmpty) {
      return placeholder;
    }

    return SafeNetworkImage(
      url: url,
      width: 56,
      height: 56,
      radius: 12,
      fit: BoxFit.cover,
      backgroundColor: Colors.black.withValues(alpha: 0.1),
      placeholder: placeholder,
      loadingPlaceholder: placeholder,
      errorPlaceholder: placeholder,
    );
  }
}
