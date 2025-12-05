// lib/ui/workout/workout_editor_widgets.dart

import 'package:flutter/material.dart';
import 'workout_editor_constants.dart';

/// ===============================
/// Core group (supports custom radii + clipping)
/// ===============================
class WorkoutAccordionGroup extends StatelessWidget {
  const WorkoutAccordionGroup({
    super.key,
    required this.children,
    this.radius = 16,
    this.borderRadius,
  });

  final List<Widget> children;
  final double radius;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: r,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1B1B1B), // Mission-style dark background
        ),
        child: Column(children: children),
      ),
    );
  }
}

/// ===============================
/// Row tile (header/add-row)
/// ===============================
class WorkoutAccordionRowTile extends StatelessWidget {
  const WorkoutAccordionRowTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.trailingIcon,
    this.onTap,
    this.radius = const BorderRadius.all(Radius.circular(16)),
  });

  final String title;
  final String? subtitle;
  final IconData trailingIcon;
  final VoidCallback? onTap;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xB3FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(trailingIcon, color: Colors.white, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===============================
/// Inline dropdown
/// ===============================
class WorkoutAccordionInlineDrop extends StatelessWidget {
  const WorkoutAccordionInlineDrop({
    super.key,
    required this.expanded,
    required this.child,
  });

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 240),
      crossFadeState:
          expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstCurve: Curves.easeInCubic,
      secondCurve: Curves.easeOutCubic,
      sizeCurve: Curves.easeOutCubic,
      firstChild: const SizedBox.shrink(),
      secondChild: child,
    );
  }
}

/// ===============================
/// Notes header (TextField is fully rounded; group bottom can be flat)
/// ===============================
class EditorHeader extends StatefulWidget {
  const EditorHeader({
    super.key,
    required this.notesCtrl,
    this.onChanged,
    this.hasBelow = true, // default seamless join to the next section
  });

  final TextEditingController notesCtrl;
  final ValueChanged<String>? onChanged;
  final bool hasBelow;

  @override
  State<EditorHeader> createState() => _EditorHeaderState();
}

class _EditorHeaderState extends State<EditorHeader> {
  bool _open = false; // Start collapsed

  @override
  void initState() {
    super.initState();
    widget.notesCtrl.addListener(_onNotesChanged);
  }

  @override
  void didUpdateWidget(covariant EditorHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notesCtrl != widget.notesCtrl) {
      oldWidget.notesCtrl.removeListener(_onNotesChanged);
      widget.notesCtrl.addListener(_onNotesChanged);
    }
  }

  @override
  void dispose() {
    widget.notesCtrl.removeListener(_onNotesChanged);
    super.dispose();
  }

  void _onNotesChanged() {
    if (!mounted) return;
    setState(() {}); // update subtitle live
  }

  void _toggleOpen() {
    FocusScope.of(context).unfocus();
    Future.microtask(() {
      if (!mounted) return;
      setState(() => _open = !_open);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.notesCtrl.text;
    final String subtitle =
        text.trim().isEmpty ? 'Optional' : _trimOneLine(text);

    // Outer group: rounded top; FLAT bottom if there’s content below.
    final BorderRadius groupRadius = widget.hasBelow
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(0),
            bottomRight: Radius.circular(0),
          )
        : BorderRadius.circular(16);

    return WorkoutAccordionGroup(
      borderRadius: groupRadius,
      children: [
        // Header row (rounded at top; no bottom rounding to prevent double curves)
        WorkoutAccordionRowTile(
          title: 'Notes',
          subtitle: subtitle,
          trailingIcon: Icons.notes_rounded,
          onTap: _toggleOpen,
          radius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),

        // Collapsible body
        WorkoutAccordionInlineDrop(
          expanded: _open,
          child: const Padding(
            // keep the body off the edges; a bit more bottom to breathe before the seam
            padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: _RoundedNotesField(),
          ),
        ),
      ],
    );
  }
}

class _RoundedNotesField extends StatelessWidget {
  const _RoundedNotesField({
    super.key,
    this.controller,
    this.onChanged,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    // Pull controller/onChanged from nearest EditorHeader if not provided.
    // (Allows usage as a standalone widget if desired.)
    TextEditingController? ctrl = controller;
    ValueChanged<String>? onCh = onChanged;

    // In our EditorHeader, the controller is the parent's notesCtrl.
    // If null here, try to find it via context (kept simple: expect provided).
    // Fallback: make a temp controller to avoid crashes in preview.
    ctrl ??= (context.findAncestorStateOfType<_EditorHeaderState>()?.widget
            as EditorHeader?)
        ?.notesCtrl;
    onCh ??= (context.findAncestorStateOfType<_EditorHeaderState>()?.widget
            as EditorHeader?)
        ?.onChanged;

    ctrl ??= TextEditingController();

    // ShapeDecoration + RoundedRectangleBorder gives crisp corners on high-DPI.
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: const Color(0xFF232323),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(
            color: Color(0x22FFFFFF),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: TextField(
          controller: ctrl,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          minLines: 3,
          maxLines: 3,
          onChanged: onCh,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Tempo work, RPE 8 cap',
            hintStyle: TextStyle(color: Color(0x66FFFFFF)),
            isCollapsed: true,
          ),
        ),
      ),
    );
  }
}

String _trimOneLine(String t) {
  final s = t.trim();
  return s.length <= 64 ? s : '${s.substring(0, 64)}…';
}

/// ===============================
/// Add Block (embeddable row; no outer group when embedded)
/// ===============================
class AddBlockFooter extends StatefulWidget {
  const AddBlockFooter({
    super.key,
    required this.onAdd,
    this.embedded = false,
  });

  final void Function(String blockType) onAdd;
  final bool embedded;

  @override
  State<AddBlockFooter> createState() => _AddBlockFooterState();
}

class _AddBlockFooterState extends State<AddBlockFooter> {
  bool _expanded = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  void _selectBlockType(String type) {
    widget.onAdd(type);
    setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      // Used inside the Blocks group
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main "Add block" button
          WorkoutAccordionRowTile(
            title: 'Add block',
            subtitle: '',
            trailingIcon:
                _expanded ? Icons.expand_less_rounded : Icons.add_rounded,
            onTap: _toggle,
            radius: _expanded
                ? const BorderRadius.only(
                    topLeft: Radius.circular(0),
                    topRight: Radius.circular(0),
                  )
                : const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
          ),
          // Dropdown options with animation
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstCurve: Curves.easeInCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(
                    height: 1, thickness: 1, color: Color(0x14FFFFFF)),
                _BlockTypeOption(
                  icon: Icons.fitness_center,
                  title: 'Block',
                  subtitle: 'Standard exercise block',
                  onTap: () => _selectBlockType('block'),
                ),
                const Divider(
                    height: 1, thickness: 1, color: Color(0x14FFFFFF)),
                _BlockTypeOption(
                  icon: Icons.whatshot,
                  title: 'Warmup/Cooldown',
                  subtitle: 'Preparation or recovery',
                  onTap: () => _selectBlockType('warmup'),
                ),
                const Divider(
                    height: 1, thickness: 1, color: Color(0x14FFFFFF)),
                _BlockTypeOption(
                  icon: Icons.pause_circle,
                  title: 'Break',
                  subtitle: 'Rest period',
                  onTap: () => _selectBlockType('break'),
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Legacy standalone usage (kept for compatibility)
    return Container(
      margin: const EdgeInsets.only(bottom: 72),
      child: WorkoutAccordionGroup(
        children: [
          WorkoutAccordionRowTile(
            title: 'Add block',
            subtitle: '',
            trailingIcon: Icons.add_rounded,
            onTap: () => widget.onAdd('block'),
          ),
        ],
      ),
    );
  }
}

class _BlockTypeOption extends StatelessWidget {
  const _BlockTypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            )
          : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF242424),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: kCardText, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: kCardText,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: kCardText.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// No-glow scroll behavior
/// ===============================
class NoGlowBehavior extends ScrollBehavior {
  const NoGlowBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

/// ===============================
/// Blocks Section (Notes + Blocks + Add Block as one seamless card)
/// ===============================
class WorkoutBlocksSection extends StatelessWidget {
  const WorkoutBlocksSection({
    super.key,
    required this.notesCtrl,
    this.onNotesChanged,
    required this.blockCards,
    required this.onAddBlock,
    this.connectorGap = 28,
  });

  final TextEditingController notesCtrl;
  final ValueChanged<String>? onNotesChanged;
  final List<Widget> blockCards;
  final void Function(String blockType) onAddBlock;
  final double connectorGap;

  @override
  Widget build(BuildContext context) {
    final hasBlocks = blockCards.isNotEmpty;

    return Column(
      children: [
        // ========== NOTES GROUP ==========
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          child: EditorHeader(
            notesCtrl: notesCtrl,
            onChanged: onNotesChanged,
            hasBelow: true, // forces flat bottom to merge into blocks group
          ),
        ),

        // No gap here so the two groups touch perfectly

        // ========== BLOCKS + ADD GROUP ==========
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          child: WorkoutAccordionGroup(
            // Flat top to butt against EditorHeader; rounded bottom.
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(0),
              topRight: Radius.circular(0),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            children: [
              // Inner padding to align with notes' field padding
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                child: Column(
                  children: [
                    for (int i = 0; i < blockCards.length; i++) ...[
                      if (i > 0)
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Center(
                              child: Container(
                                width: 6,
                                height: connectorGap,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF6A4CFF),
                                      Color(0xFF8C5BFF),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: connectorGap),
                          ],
                        ),
                      blockCards[i],
                      if (i < blockCards.length - 1)
                        SizedBox(height: connectorGap),
                    ],

                    // Space before Add Block if there were blocks
                    if (hasBlocks) const SizedBox(height: 28),

                    // Add Block row (embedded so it gets the rounded bottom corners)
                    AddBlockFooter(onAdd: onAddBlock, embedded: true),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bottom breathing room (outside the rounded card)
        const SizedBox(height: 72),
      ],
    );
  }
}

/// ===============================
/// Schedule pattern model + picker (weekly toggles + every-X days)
/// Reusable between dashboard, routine detail, and editor flows.
/// ===============================

enum SchedulePatternMode {
  weekly,
  interval,
}

/// UI config for a schedule pattern.
/// - weekly: [weeklyDays] contains 1=Mon … 7=Sun.
/// - interval: [intervalDays] is the gap between repeats.
class SchedulePatternConfig {
  final SchedulePatternMode mode;
  final Set<int> weeklyDays; // 1=Mon..7=Sun
  final int intervalDays;

  const SchedulePatternConfig({
    required this.mode,
    required this.weeklyDays,
    required this.intervalDays,
  });

  const SchedulePatternConfig.weekly(Set<int> days)
      : mode = SchedulePatternMode.weekly,
        weeklyDays = days,
        intervalDays = 1;

  const SchedulePatternConfig.interval(int everyDays)
      : mode = SchedulePatternMode.interval,
        weeklyDays = const <int>{},
        intervalDays = everyDays;

  SchedulePatternConfig copyWith({
    SchedulePatternMode? mode,
    Set<int>? weeklyDays,
    int? intervalDays,
  }) {
    return SchedulePatternConfig(
      mode: mode ?? this.mode,
      weeklyDays: weeklyDays ?? this.weeklyDays,
      intervalDays: intervalDays ?? this.intervalDays,
    );
  }

  bool get isValid {
    switch (mode) {
      case SchedulePatternMode.weekly:
        return weeklyDays.isNotEmpty;
      case SchedulePatternMode.interval:
        return intervalDays >= 1;
    }
  }
}

class SchedulePatternPicker extends StatelessWidget {
  const SchedulePatternPicker({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.weeklyLabel = 'By weekday',
    this.intervalLabel = 'Every X days',
    this.minIntervalDays = 1,
    this.maxIntervalDays = 7,
  });

  final String title;
  final String? subtitle;
  final SchedulePatternConfig value;
  final ValueChanged<SchedulePatternConfig> onChanged;
  final String weeklyLabel;
  final String intervalLabel;
  final int minIntervalDays;
  final int maxIntervalDays;

  @override
  Widget build(BuildContext context) {
    final bool isWeekly = value.mode == SchedulePatternMode.weekly;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kCardText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: kCardText.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _ScheduleModeChip(
                label: weeklyLabel,
                selected: isWeekly,
                onTap: () {
                  if (!isWeekly) {
                    onChanged(
                      value.copyWith(mode: SchedulePatternMode.weekly),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              _ScheduleModeChip(
                label: intervalLabel,
                selected: !isWeekly,
                onTap: () {
                  if (isWeekly) {
                    onChanged(
                      value.copyWith(mode: SchedulePatternMode.interval),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isWeekly)
            _WeeklyDaysRow(
              selectedDays: value.weeklyDays,
              onChanged: (days) {
                onChanged(
                  value.copyWith(
                    mode: SchedulePatternMode.weekly,
                    weeklyDays: days,
                  ),
                );
              },
            )
          else
            _IntervalRow(
              value: value.intervalDays,
              min: minIntervalDays,
              max: maxIntervalDays,
              onChanged: (days) {
                onChanged(
                  value.copyWith(
                    mode: SchedulePatternMode.interval,
                    intervalDays: days,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ScheduleModeChip extends StatelessWidget {
  const _ScheduleModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg =
        selected ? const Color(0xFF2C2C2C) : const Color(0xFF252525);
    final Color border = selected
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.16);
    final Color text = kCardText.withValues(alpha: selected ? 0.95 : 0.7);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
              ),
            ],
            Text(
              label,
              style: TextStyle(
                color: text,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyDaysRow extends StatelessWidget {
  const _WeeklyDaysRow({
    required this.selectedDays,
    required this.onChanged,
  });

  final Set<int> selectedDays;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (index) {
        final dayIndex = index + 1; // 1..7
        final bool selected = selectedDays.contains(dayIndex);
        return _ScheduleDayChip(
          label: labels[index],
          selected: selected,
          onTap: () {
            final next = Set<int>.from(selectedDays);
            if (selected) {
              next.remove(dayIndex);
            } else {
              next.add(dayIndex);
            }
            onChanged(next);
          },
        );
      }),
    );
  }
}

class _ScheduleDayChip extends StatelessWidget {
  const _ScheduleDayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color text = kCardText.withValues(alpha: selected ? 0.95 : 0.75);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: text,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _IntervalRow extends StatelessWidget {
  const _IntervalRow({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    int clamped = value;
    if (clamped < min) clamped = min;
    if (clamped > max) clamped = max;

    void changeBy(int delta) {
      int next = clamped + delta;
      if (next < min) next = min;
      if (next > max) next = max;
      if (next != clamped) {
        onChanged(next);
      }
    }

    return Row(
      children: [
        _IntervalIconButton(
          icon: Icons.remove_rounded,
          enabled: clamped > min,
          onTap: () => changeBy(-1),
        ),
        const SizedBox(width: 8),
        Text(
          '$clamped',
          style: const TextStyle(
            color: kCardText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'day${clamped == 1 ? '' : 's'} between repeats',
          style: TextStyle(
            color: kCardText.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        _IntervalIconButton(
          icon: Icons.add_rounded,
          enabled: clamped < max,
          onTap: () => changeBy(1),
        ),
      ],
    );
  }
}

class _IntervalIconButton extends StatelessWidget {
  const _IntervalIconButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = enabled
        ? kCardText.withValues(alpha: 0.9)
        : kCardText.withValues(alpha: 0.35);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: enabled
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: fg,
        ),
      ),
    );
  }
}
