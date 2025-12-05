// lib/ui/workout/workout_routine_editor_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/core/analytics/analytics_events.dart';
import 'package:kontinuum/services/analytics_service.dart';

const _kRoutineBg = Color(0xFF090A0E);
const _kFooterH = 44;
const int _kMaxTitleChars = 48;

class WorkoutRoutineEditorPage extends StatefulWidget {
  const WorkoutRoutineEditorPage({
    super.key,
    this.onRequestClose,
    this.onSaved,
    this.closeTopOverride,
  });

  final VoidCallback? onRequestClose;
  final ValueChanged<String>? onSaved;
  final double? closeTopOverride;

  @override
  State<WorkoutRoutineEditorPage> createState() =>
      _WorkoutRoutineEditorPageState();
}

class _WorkoutRoutineEditorPageState extends State<WorkoutRoutineEditorPage> {
  final _titleCtrl = TextEditingController();
  final _titleFocus = FocusNode();

  DietGoal _goal = DietGoal.cut;
  DietStrictness _strict = DietStrictness.soft;
  int _kcal = 2100;
  int _protein = 180;
  bool _poEnabled = true;
  bool _saving = false;
  bool _showContent = false;

  double _titleFontSize = 44;

  bool get _embedded => widget.onRequestClose != null;
  bool get _showInlineClose => !_embedded;

  void _close() {
    FocusScope.of(context).unfocus();
    if (_embedded) {
      widget.onRequestClose!.call();
    }
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) {
      nav.pop();
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final wp = context.read<WorkoutProvider>();
    final name =
        _titleCtrl.text.trim().isEmpty ? 'New Routine' : _titleCtrl.text.trim();

    final diet = DietSettings(
      goal: _goal,
      kcalPerDay: _kcal,
      proteinTargetG: _protein,
      strictness: _strict,
    );

    final routine = await wp.createRoutine(
      name: name,
      diet: diet,
      poEnabled: _poEnabled,
    );

    AnalyticsService.instance.log(
      WorkoutAnalyticsEvents.routineOpened,
      {'routineId': routine.id, 'created': true},
    );

    if (widget.onSaved != null) {
      widget.onSaved!(routine.id);
      _close();
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(routine.id);
  }

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
      setState(() {
        _titleFontSize = size;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _titleCtrl.addListener(() {
      _recalcTitleSize(_titleCtrl.text);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _titleFocus.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');

      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _showContent = true);
      });
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final insets = mq.viewInsets;
    final pad = mq.padding;

    final double baseTop = pad.top + 12.0;
    final double closeTop =
        widget.closeTopOverride != null ? widget.closeTopOverride! : baseTop;
    const double closeRight = 8.0;

    return Scaffold(
      backgroundColor: _kRoutineBg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // MAIN
          Positioned.fill(
            bottom: insets.bottom + _kFooterH,
            child: SafeArea(
              top: true,
              bottom: false,
              child: LayoutBuilder(
                builder: (context, box) {
                  final caretY = box.maxHeight * 0.20;
                  final contentTop = caretY + 110;

                  return Stack(
                    children: [
                      // TITLE
                      Positioned(
                        top: caretY,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: TextField(
                              controller: _titleCtrl,
                              focusNode: _titleFocus,
                              textAlign: TextAlign.center,
                              cursorColor: Colors.white,
                              cursorWidth: 3,
                              maxLines: 2,
                              minLines: 1,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _titleFontSize,
                                fontWeight: FontWeight.w600,
                                height: 1.05,
                              ),
                              decoration: const InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: 'Routine name',
                                hintStyle: TextStyle(color: Colors.white24),
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _save(),
                              inputFormatters: [
                                FilteringTextInputFormatter.singleLineFormatter,
                                LengthLimitingTextInputFormatter(
                                    _kMaxTitleChars),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // CONTENT
                      Positioned.fill(
                        top: contentTop,
                        child: AnimatedOpacity(
                          opacity: _showContent ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: ScrollConfiguration(
                            behavior: const _NoGlowBehavior(),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _AddItemTile(
                                    icon: Icons.local_fire_department_outlined,
                                    label: 'Goal • kcal • protein',
                                    onTap: () {},
                                  ),
                                  const SizedBox(height: 12),
                                  _RoutineDataPanel(
                                    goal: _goal,
                                    strict: _strict,
                                    kcal: _kcal,
                                    protein: _protein,
                                    po: _poEnabled,
                                    onGoalChanged: (g) =>
                                        setState(() => _goal = g),
                                    onStrictChanged: (s) =>
                                        setState(() => _strict = s),
                                    onKcalChanged: (k) =>
                                        setState(() => _kcal = k),
                                    onProteinChanged: (p) =>
                                        setState(() => _protein = p),
                                    onPoChanged: (v) =>
                                        setState(() => _poEnabled = v),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // FOOTER
          Positioned(
            left: 0,
            right: 0,
            bottom: insets.bottom,
            child: Container(
              height: _kFooterH + pad.bottom,
              color: _kRoutineBg,
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
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _save,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 4),
                      child: Text(
                        _saving ? 'Saving…' : 'Done',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // INLINE X (only for standalone route)
          if (_showInlineClose)
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
                    color: Colors.white,
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

// ===== panels =====

class _AddItemTile extends StatelessWidget {
  const _AddItemTile({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1C1F),
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineDataPanel extends StatelessWidget {
  const _RoutineDataPanel({
    required this.goal,
    required this.strict,
    required this.kcal,
    required this.protein,
    required this.po,
    required this.onGoalChanged,
    required this.onStrictChanged,
    required this.onKcalChanged,
    required this.onProteinChanged,
    required this.onPoChanged,
  });

  final DietGoal goal;
  final DietStrictness strict;
  final int kcal;
  final int protein;
  final bool po;

  final ValueChanged<DietGoal> onGoalChanged;
  final ValueChanged<DietStrictness> onStrictChanged;
  final ValueChanged<int> onKcalChanged;
  final ValueChanged<int> onProteinChanged;
  final ValueChanged<bool> onPoChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131416),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // 3-way pill: cut / maintain / bulk
          _GoalSegmentedPill(
            value: goal,
            onChanged: onGoalChanged,
          ),
          const Divider(color: Color(0xFF252628), height: 18),
          Row(
            children: [
              Expanded(
                child: _InlineEditNumber(
                  label: 'Daily kcal',
                  value: kcal.toString(),
                  onChanged: (v) {
                    final p = int.tryParse(v);
                    if (p != null) onKcalChanged(p);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InlineEditNumber(
                  label: 'Protein g',
                  value: protein.toString(),
                  onChanged: (v) {
                    final p = int.tryParse(v);
                    if (p != null) onProteinChanged(p);
                  },
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF252628), height: 18),
          _InlineRow(
            label: 'Strictness',
            value: strict.name,
            onTap: () async {
              final s = await _pickStrict(context, strict);
              if (s != null) onStrictChanged(s);
            },
          ),
          const Divider(color: Color(0xFF252628), height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progressive overload',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              Switch(
                value: po,
                onChanged: onPoChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<DietStrictness?> _pickStrict(
      BuildContext context, DietStrictness current) {
    return showModalBottomSheet<DietStrictness>(
      context: context,
      backgroundColor: _kRoutineBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: DietStrictness.values.map((s) {
              return ListTile(
                title:
                    Text(s.name, style: const TextStyle(color: Colors.white)),
                trailing: s == current
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
                onTap: () => Navigator.of(context).pop(s),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _GoalSegmentedPill extends StatelessWidget {
  const _GoalSegmentedPill({
    required this.value,
    required this.onChanged,
  });

  final DietGoal value;
  final ValueChanged<DietGoal> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      DietGoal.cut,
      DietGoal.maintain,
      DietGoal.bulk,
    ];

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1C1F),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: _GoalSegment(
                label: switch (items[i]) {
                  DietGoal.cut => 'cut',
                  DietGoal.maintain => 'maintain',
                  DietGoal.bulk => 'bulk',
                },
                selected: value == items[i],
                onTap: () => onChanged(items[i]),
                isFirst: i == 0,
                isLast: i == items.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalSegment extends StatelessWidget {
  const _GoalSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isFirst,
    required this.isLast,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(
          left: isFirst ? 3 : 2,
          right: isLast ? 3 : 2,
          top: 3,
          bottom: 3,
        ),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(999) : Radius.zero,
            right: isLast ? const Radius.circular(999) : Radius.zero,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white.withOpacity(.72),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

class _InlineRow extends StatelessWidget {
  const _InlineRow({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            const Spacer(),
            Text(value,
                style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white30, size: 22),
          ],
        ),
      ),
    );
  }
}

class _InlineEditNumber extends StatelessWidget {
  const _InlineEditNumber({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 12.5)),
        const SizedBox(height: 6),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF1F2023),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
