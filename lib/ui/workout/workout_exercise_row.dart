// lib/ui/workout/workout_exercise_row.dart
import 'package:flutter/material.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/services/exercise_library_service.dart';
import 'package:kontinuum/utils/text_format.dart';

import 'workout_editor_constants.dart';

const double _kSessionActionButtonSize = 54;
const double _kSessionActionBarTopPadding = 4;
const double _kSessionActionBarMinBottomPadding = 8;

double _sessionActionBarBottomPadding(double bottomInset) {
  // Float the action bar above the home indicator / dock with a consistent lift.
  const double lift = 18;
  if (bottomInset <= 0) {
    return _kSessionActionBarMinBottomPadding + lift;
  }
  return bottomInset + lift;
}

/// Height consumed by the session action bar (buttons + padding) for a given
/// safe-area inset.
double sessionActionBarHeight(double bottomInset) {
  return _kSessionActionButtonSize +
      _kSessionActionBarTopPadding +
      _sessionActionBarBottomPadding(bottomInset);
}

class ExerciseRowController {
  ExerciseRowController();

  final ValueNotifier<bool> noteActive = ValueNotifier<bool>(false);
  _ExerciseRowState? _state;

  void _attach(_ExerciseRowState state) {
    _state = state;
    noteActive.value = state._currentNoteActive;
  }

  void _detach(_ExerciseRowState state) {
    if (_state == state) {
      _state = null;
      noteActive.value = false;
    }
  }

  void toggleNote() {
    _state?._toggleNote(fromExternal: true);
  }
}

class ExerciseRow extends StatefulWidget {
  final WorkoutItem item;
  final BlockType? blockType;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback onViewDetails;
  final VoidCallback onEditSets;
  final VoidCallback onEditReps;
  final VoidCallback onEditWork;
  final VoidCallback onEditRest;
  final VoidCallback onEditLoad;
  final WeightUnit loadUnit;
  final ValueChanged<WeightUnit> onLoadUnitChanged;
  final VoidCallback? onQuickIncrementSets;
  final ValueChanged<String?> onNoteChanged;
  final bool showStructureActions;
  final bool isSessionMode;
  final bool showSessionActionBar;
  final ExerciseRowController? sessionController;

  const ExerciseRow({
    super.key,
    required this.item,
    required this.blockType,
    required this.onRemove,
    required this.onDuplicate,
    required this.onViewDetails,
    required this.onEditSets,
    required this.onEditReps,
    required this.onEditWork,
    required this.onEditRest,
    required this.onEditLoad,
    required this.loadUnit,
    required this.onLoadUnitChanged,
    this.onQuickIncrementSets,
    required this.onNoteChanged,
    this.showStructureActions = true,
    this.isSessionMode = false,
    this.showSessionActionBar = true,
    this.sessionController,
  });

  @override
  State<ExerciseRow> createState() => _ExerciseRowState();
}

class _ExerciseRowState extends State<ExerciseRow> {
  bool _expanded = false;
  bool _noteExpanded = false;
  late final TextEditingController _noteCtrl;
  final FocusNode _noteFocus = FocusNode();
  bool _controllerAttached = false;

  ExerciseRowController? get _controller => widget.sessionController;

  bool get _currentNoteActive =>
      _noteExpanded || _noteCtrl.text.trim().isNotEmpty;

  void _attachControllerIfNeeded() {
    final controller = _controller;
    if (controller != null && !_controllerAttached) {
      controller._attach(this);
      _controllerAttached = true;
      controller.noteActive.value = _currentNoteActive;
    }
  }

  void _detachControllerIfNeeded() {
    final controller = _controller;
    if (controller != null && _controllerAttached) {
      controller._detach(this);
      _controllerAttached = false;
    }
  }

  void _publishNoteActive() {
    final controller = _controller;
    if (controller == null) return;
    final bool active = _currentNoteActive;
    if (controller.noteActive.value != active) {
      controller.noteActive.value = active;
    }
  }

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.item.notes ?? '');
    if (_noteCtrl.text.trim().isNotEmpty) {
      _noteExpanded = true;
    }
    if (widget.isSessionMode) {
      _expanded = true;
    }
    _attachControllerIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _publishNoteActive();
    });
  }

  @override
  void didUpdateWidget(covariant ExerciseRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionController != widget.sessionController) {
      oldWidget.sessionController?._detach(this);
      _controllerAttached = false;
      _attachControllerIfNeeded();
      _publishNoteActive();
    }
    if (oldWidget.item.notes != widget.item.notes) {
      final newNote = widget.item.notes ?? '';
      if (newNote != _noteCtrl.text) {
        final selection = _noteCtrl.selection;
        int base = selection.baseOffset;
        int extent = selection.extentOffset;
        if (base > newNote.length) base = newNote.length;
        if (extent > newNote.length) extent = newNote.length;
        _noteCtrl.value = TextEditingValue(
          text: newNote,
          selection: TextSelection(baseOffset: base, extentOffset: extent),
        );
      }
      if (newNote.isNotEmpty && !_noteExpanded) {
        setState(() => _noteExpanded = true);
      }
      if (newNote.isEmpty && !_noteFocus.hasFocus) {
        setState(() => _noteExpanded = false);
      }
      _publishNoteActive();
    }
    if (!oldWidget.isSessionMode && widget.isSessionMode) {
      setState(() => _expanded = true);
    }
  }

  @override
  void dispose() {
    _detachControllerIfNeeded();
    _noteCtrl.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    if (widget.isSessionMode) return;
    setState(() => _expanded = !_expanded);
  }

  void _toggleNote({bool fromExternal = false}) {
    if (widget.isSessionMode && !fromExternal) return;
    final next = !_noteExpanded;
    setState(() => _noteExpanded = next);
    if (next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (!widget.isSessionMode) {
            _noteFocus.requestFocus();
          }
        }
      });
    } else {
      _noteFocus.unfocus();
    }
    _publishNoteActive();
  }

  void _handleNoteChanged(String value) {
    if (widget.isSessionMode) return;
    final trimmed = value.trim();
    widget.onNoteChanged(trimmed.isEmpty ? null : trimmed);
    _publishNoteActive();
  }

  @override
  Widget build(BuildContext context) {
    final WorkoutItem item = widget.item;
    final exercise = ExerciseLibraryService.instance.getById(item.exerciseId);
    final String name = exercise?.name ?? 'Unknown exercise';
    final String displayName = formatTitleCase(name);
    final String? mediaUrl = exercise?.mediaUrl;
    final String musclesLabel = exercise == null
        ? ''
        : exercise.muscles.map(formatTitleCase).take(2).join(', ');
    final bool sessionMode = widget.isSessionMode;

    final Color tileColor = Colors.white.withValues(alpha: 0.05);
    final Color borderColor = Colors.white.withValues(alpha: 0.08);
    final BoxDecoration? tileDecoration = sessionMode
        ? null
        : BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          );
    final BorderRadiusGeometry? radius =
        sessionMode ? null : BorderRadius.circular(20);

    final segments = _buildSegmentData(item);
    final bool hasNote = _noteCtrl.text.trim().isNotEmpty;
    final bool noteActive = _noteExpanded || hasNote;
    final bool showNoteField = _noteExpanded || _noteFocus.hasFocus;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: tileDecoration,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: sessionMode ? Clip.none : Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Builder(
            builder: (context) {
              final Widget header = Column(
                crossAxisAlignment: sessionMode
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    textAlign: sessionMode ? TextAlign.center : TextAlign.left,
                    style: TextStyle(
                      color: kCardText,
                      fontWeight:
                          sessionMode ? FontWeight.w800 : FontWeight.w700,
                      fontSize: sessionMode ? 20 : 17,
                      letterSpacing: sessionMode ? -0.2 : -0.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (musclesLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      musclesLabel,
                      textAlign:
                          sessionMode ? TextAlign.center : TextAlign.left,
                      style: TextStyle(
                        color: Colors.white
                            .withValues(alpha: sessionMode ? 0.6 : 0.55),
                        fontSize: sessionMode ? 13 : 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment:
                        sessionMode ? Alignment.center : Alignment.centerLeft,
                    child: _FrozenGifThumbnail(url: mediaUrl),
                  ),
                ],
              );

              final Widget noteField = AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: showNoteField
                    ? Padding(
                        key: const ValueKey('note-field'),
                        padding: const EdgeInsets.only(top: 12),
                        child: TextField(
                          controller: _noteCtrl,
                          focusNode: _noteFocus,
                          minLines: 2,
                          maxLines: 4,
                          style: const TextStyle(color: kCardText),
                          readOnly: sessionMode,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: _handleNoteChanged,
                          decoration: InputDecoration(
                            hintText: 'Add exercise-specific notes…',
                            hintStyle: TextStyle(
                              color: kCardText.withValues(alpha: 0.35),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: kCardText.withValues(alpha: 0.14),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: kCardText.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: kCardText.withValues(alpha: 0.08),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              );

      if (sessionMode) {
        final double bottomInset = MediaQuery.of(context).padding.bottom;
        final double actionBarHeight = sessionActionBarHeight(bottomInset);

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            const SizedBox(height: 20),
            _buildPrescriptionSection(segments),
            const SizedBox(height: 24),
            noteField,
          ],
        );

        if (!widget.showSessionActionBar) {
          return content;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: actionBarHeight),
              child: content,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SessionActionBar(
                noteActive: noteActive,
                onToggleNote: () => _toggleNote(fromExternal: true),
                onViewDetails: widget.onViewDetails,
              ),
            ),
          ],
        );
      }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  header,
                  const SizedBox(height: 14),
                  _buildPrescriptionSection(segments),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SurfaceIconButton(
                        icon: noteActive
                            ? Icons.sticky_note_2_rounded
                            : Icons.sticky_note_2_outlined,
                        tooltip: noteActive
                            ? 'Hide exercise notes'
                            : 'Add exercise notes',
                        onTap: _toggleNote,
                        active: noteActive,
                        large: false,
                      ),
                      const SizedBox(width: 16),
                      _SurfaceIconButton(
                        icon: Icons.info_outline,
                        tooltip: 'Exercise details',
                        semanticsLabel: 'Exercise details',
                        onTap: widget.onViewDetails,
                        large: false,
                      ),
                      if (widget.showStructureActions) ...[
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
                    ],
                  ),
                  noteField,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPrescriptionSection(List<_SegmentConfig> segments) {
    final bool sessionMode = widget.isSessionMode;
    if (sessionMode) {
      const double cellWidth = 140;
      const double rowGap = 26;
      const double totalRowWidth = cellWidth * 2 + rowGap;

      _SegmentConfig? byKind(_SegmentKind kind) {
        for (final segment in segments) {
          if (segment.kind == kind) return segment;
        }
        return null;
      }

      Widget buildCell(_SegmentConfig? segment) {
        if (segment == null || segment.label.isEmpty) {
          return const SizedBox(width: cellWidth);
        }
        return SizedBox(
          width: cellWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                segment.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kCardText.withValues(alpha: 0.55),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                segment.value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: segment.isPlaceholder
                      ? kCardText.withValues(alpha: 0.6)
                      : kCardText,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.05,
                ),
              ),
            ],
          ),
        );
      }

      Widget buildRow(List<_SegmentConfig?> cells) {
        final children = <Widget>[];
        for (var i = 0; i < cells.length; i++) {
          if (i > 0) {
            children.add(const SizedBox(width: rowGap));
          }
          children.add(buildCell(cells[i]));
        }
        return SizedBox(
          width: totalRowWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        );
      }

      final load = byKind(_SegmentKind.load);
      final sets = byKind(_SegmentKind.sets);
      final reps = byKind(_SegmentKind.reps);
      final work = byKind(_SegmentKind.work);
      final rest = byKind(_SegmentKind.rest);

      return Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Prescription',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kCardText.withValues(alpha: 0.7),
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 18),
            buildRow([load, sets]),
            const SizedBox(height: 20),
            buildRow([reps, work]),
            if (rest != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: totalRowWidth,
                child: Center(child: buildCell(rest)),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
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
            if (!_expanded) ...[
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
              onPressed: _toggleExpanded,
              visualDensity: VisualDensity.compact,
              tooltip: _expanded ? 'Collapse details' : 'Expand details',
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: kCardText.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
        AnimatedCrossFade(
          firstChild: _CollapsedStrip(
            segments: segments,
            onTap: _toggleExpanded,
          ),
          secondChild: _PrescriptionStrip(
            segments: segments,
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
        ),
      ],
    );
  }

  List<_SegmentConfig> _buildSegmentData(WorkoutItem item) {
    final BlockType? type = widget.blockType;
    final order = _segmentOrderFor(type);
    final List<_SegmentConfig> segments = <_SegmentConfig>[];
    final bool allowInteraction = !widget.isSessionMode;

    for (final kind in order) {
      switch (kind) {
        case _SegmentKind.sets:
          final int sets = item.targetSets;
          segments.add(
            _SegmentConfig(
              kind: kind,
              label: 'Sets',
              value: sets > 0 ? sets.toString() : '—',
              onTap: allowInteraction ? widget.onEditSets : null,
              onLongPress:
                  allowInteraction ? widget.onQuickIncrementSets : null,
              enabled: allowInteraction,
              isPlaceholder: sets <= 0,
            ),
          );
          break;
        case _SegmentKind.reps:
          final bool repsRelevant =
              type != BlockType.emom && type != BlockType.amrap;
          final int? reps = item.targetReps;
          segments.add(
            _SegmentConfig(
              kind: kind,
              label: 'Reps',
              value: repsRelevant
                  ? (reps?.toString() ?? '—')
                  : 'Set in block type',
              onTap:
                  allowInteraction && repsRelevant ? widget.onEditReps : null,
              enabled: allowInteraction && repsRelevant,
              isPlaceholder: reps == null,
            ),
          );
          break;
        case _SegmentKind.work:
          final bool workRelevant = type == BlockType.circuit ||
              type == BlockType.emom ||
              type == BlockType.amrap;
          final int? work = item.targetTimeSec;
          segments.add(
            _SegmentConfig(
              kind: kind,
              label: 'Work',
              value: work != null
                  ? _formatDuration(work)
                  : (workRelevant ? 'Set in block type' : '—'),
              onTap:
                  allowInteraction && workRelevant ? widget.onEditWork : null,
              enabled: allowInteraction && workRelevant,
              isPlaceholder: work == null,
            ),
          );
          break;
        case _SegmentKind.rest:
          final bool restRelevant = type == null ||
              type == BlockType.set ||
              type == BlockType.superset ||
              type == BlockType.circuit;
          final int? rest = item.restSec;
          segments.add(
            _SegmentConfig(
              kind: kind,
              label: 'Rest',
              value: rest != null
                  ? _formatDuration(rest)
                  : (restRelevant ? '—' : 'Set in block type'),
              onTap:
                  allowInteraction && restRelevant ? widget.onEditRest : null,
              enabled: allowInteraction && restRelevant,
              isPlaceholder: rest == null,
            ),
          );
          break;
        case _SegmentKind.load:
          final double? load = item.targetLoad;
          segments.add(
            _SegmentConfig(
              kind: kind,
              label: 'Load',
              value: load != null ? _formatLoad(load) : '—',
              onTap: allowInteraction ? widget.onEditLoad : null,
              enabled: allowInteraction,
              isPlaceholder: load == null,
              trailing: allowInteraction
                  ? _WeightUnitToggle(
                      selected: widget.loadUnit,
                      onChanged: widget.onLoadUnitChanged,
                    )
                  : null,
            ),
          );
          break;
      }
    }

    return segments;
  }

  List<_SegmentKind> _segmentOrderFor(BlockType? type) {
    switch (type) {
      case BlockType.emom:
        return const [
          _SegmentKind.load,
          _SegmentKind.sets,
          _SegmentKind.reps,
          _SegmentKind.work,
          _SegmentKind.rest,
        ];
      case BlockType.amrap:
        return const [
          _SegmentKind.load,
          _SegmentKind.sets,
          _SegmentKind.reps,
          _SegmentKind.work,
          _SegmentKind.rest,
        ];
      case BlockType.circuit:
        return const [
          _SegmentKind.load,
          _SegmentKind.sets,
          _SegmentKind.reps,
          _SegmentKind.work,
          _SegmentKind.rest,
        ];
      case BlockType.superset:
      case BlockType.set:
      case null:
        return const [
          _SegmentKind.load,
          _SegmentKind.sets,
          _SegmentKind.reps,
          _SegmentKind.work,
          _SegmentKind.rest,
        ];
    }
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
}

enum _SegmentKind { sets, reps, work, rest, load }

class _SegmentConfig {
  const _SegmentConfig({
    required this.kind,
    required this.label,
    required this.value,
    required this.enabled,
    required this.isPlaceholder,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  final _SegmentKind kind;
  final String label;
  final String value;
  final bool enabled;
  final bool isPlaceholder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
}

class SessionActionBar extends StatelessWidget {
  const SessionActionBar({
    required this.noteActive,
    required this.onToggleNote,
    required this.onViewDetails,
  });

  final bool noteActive;
  final VoidCallback onToggleNote;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double bottomPadding =
        _sessionActionBarBottomPadding(bottomInset);
    return Container(
      padding: EdgeInsets.only(
        top: _kSessionActionBarTopPadding,
        bottom: bottomPadding,
      ),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SurfaceIconButton(
            icon: noteActive
                ? Icons.sticky_note_2_rounded
                : Icons.sticky_note_2_outlined,
            tooltip:
                noteActive ? 'Hide exercise notes' : 'Add exercise notes',
            onTap: onToggleNote,
            active: noteActive,
            large: true,
          ),
          const SizedBox(width: 20),
          const _SessionStartButton(large: true),
          const SizedBox(width: 20),
          _SurfaceIconButton(
            icon: Icons.info_outline,
            tooltip: 'Exercise details',
            semanticsLabel: 'Exercise details',
            onTap: onViewDetails,
            large: true,
          ),
        ],
      ),
    );
  }
}

class _SessionStartButton extends StatelessWidget {
  const _SessionStartButton({this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = large
        ? const EdgeInsets.symmetric(horizontal: 28, vertical: 14)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
    final Size minSize = large ? const Size(0, 48) : const Size(0, 36);
    final TextStyle textStyle = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: large ? 16 : 13,
      letterSpacing: large ? 1.2 : 1.1,
    );
    return FilledButton(
      onPressed: () {},
      style: FilledButton.styleFrom(
        padding: padding,
        minimumSize: minSize,
        backgroundColor: const Color(0xFF34D399),
        foregroundColor: const Color(0xFF052011),
        textStyle: textStyle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(large ? 20 : 14),
        ),
        elevation: large ? 2 : 0,
      ),
      child: const Text('START'),
    );
  }
}

class _SurfaceIconButton extends StatelessWidget {
  const _SurfaceIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.semanticsLabel,
    this.destructive = false,
    this.active = false,
    this.large = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final String? semanticsLabel;
  final bool destructive;
  final bool active;
  final bool large;

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
    final double dimension = large ? 54 : 36;
    final double iconSize = large ? 24 : 18;
    final BorderRadius borderRadius = BorderRadius.circular(large ? 22 : 16);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: Semantics(
        button: true,
        toggled: active ? true : null,
        label: semanticsLabel ?? tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Container(
            width: dimension,
            height: dimension,
            decoration: BoxDecoration(
              color: background,
              borderRadius: borderRadius,
              border: border,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
        ),
      ),
    );
  }
}

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
          for (final unit in WeightUnit.values)
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

    return Semantics(
      container: false,
      button: true,
      toggled: selected,
      label: 'Display load in ${unit.label}',
      child: Padding(
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
                    width: width.clamp(120.0, constraints.maxWidth).toDouble(),
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
            onLongPress: enabled ? widget.config.onLongPress : null,
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) {
            return child;
          }
          if (frame == null) {
            return child;
          }
          _frozenFrame ??= child;
          return _frozenFrame!;
        },
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}
