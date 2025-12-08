import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kontinuum/models/diet_models.dart';

const _kEditorBg = Color(0xFF090A0E);
const _kFooterH = 44;
const int _kMaxTitleChars = 48;

/// What we return on save. Consumer can store this however they like.
class CreateDietResult {
  /// Under the hood this holds the full DietGoal/Diet Plan.
  final DietGoal settings;

  const CreateDietResult({required this.settings});

  /// Convenience getter: plan name.
  String get name => settings.name ?? '';
}

/// High-level goal type for the plan.
enum DietMode { cut, maintain, bulk }

/// Whether macros are being tracked as full targets or just calories.
enum _MacroMode { simple, advanced }

class CreateDietScreen extends StatefulWidget {
  const CreateDietScreen({
    super.key,
    this.onRequestClose,
    this.onSaved,
    this.closeTopOverride,
    this.initialGoal,
  });

  /// If provided, we treat this as embedded (like a sheet inside another
  /// screen) and call this instead of just popping.
  final VoidCallback? onRequestClose;

  /// Optional callback that receives the result on save.
  final ValueChanged<CreateDietResult>? onSaved;

  /// Override the inline-close button's top offset (to match any host header).
  final double? closeTopOverride;

  /// Optional: editing an existing goal instead of creating new.
  final DietGoal? initialGoal;

  @override
  State<CreateDietScreen> createState() => _CreateDietScreenState();
}

class _CreateDietScreenState extends State<CreateDietScreen> {
  final _titleCtrl = TextEditingController();
  final _titleFocus = FocusNode();

  DietMode _goalMode = DietMode.maintain;
  _MacroMode _macroMode = _MacroMode.simple;

  int _kcal = 2000;
  int _protein = 0;
  int _carbs = 0;
  int _fats = 0;
  int _fastingHours = 0;

  late Map<MealSlot, bool> _slotEnabled;
  late Map<MealSlot, TextEditingController> _slotLabels;

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

    final name = _titleCtrl.text.trim().isEmpty
        ? 'New Diet Plan'
        : _titleCtrl.text.trim();

    // Collect enabled meal slots + final labels
    final enabledSlots = <MealSlot>[];
    final slotLabels = <int, String>{};
    for (final slot in MealSlot.values) {
      if (_slotEnabled[slot] == true) {
        enabledSlots.add(slot);
        final raw = _slotLabels[slot]!.text.trim();
        slotLabels[slot.index] = raw.isEmpty ? _defaultSlotLabel(slot) : raw;
      }
    }

    final macrosAdvanced = _macroMode == _MacroMode.advanced;

    final goal = DietGoal(
      caloriesTarget: _kcal,
      proteinTarget: macrosAdvanced ? _protein.toDouble() : 0,
      carbsTarget: macrosAdvanced ? _carbs.toDouble() : 0,
      fatsTarget: macrosAdvanced ? _fats.toDouble() : 0,
      mode: _goalMode.name, // "cut" | "maintain" | "bulk"
      baseCalories: widget.initialGoal?.baseCalories ?? _kcal,
      name: name,
      fastingHours: _fastingHours > 0 ? _fastingHours.toDouble() : null,
      enabledSlots: enabledSlots.isEmpty
          ? List<MealSlot>.from(MealSlot.values)
          : enabledSlots,
      slotLabels: slotLabels,
    ).withDefaults();

    final result = CreateDietResult(settings: goal);

    if (widget.onSaved != null) {
      widget.onSaved!(result);
      _close();
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(result);
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
      setState(() => _titleFontSize = size);
    }
  }

  @override
  void initState() {
    super.initState();

    final existing = widget.initialGoal;
    if (existing != null) {
      _titleCtrl.text = existing.name ?? '';

      _goalMode = switch (existing.mode) {
        'cut' => DietMode.cut,
        'maintain' => DietMode.maintain,
        'bulk' => DietMode.bulk,
        _ => DietMode.maintain,
      };

      _kcal = existing.caloriesTarget;
      _protein = existing.proteinTarget.round();
      _carbs = existing.carbsTarget.round();
      _fats = existing.fatsTarget.round();
      _fastingHours = (existing.fastingHours ?? 0).round();

      _macroMode = (existing.proteinTarget > 0 ||
              existing.carbsTarget > 0 ||
              existing.fatsTarget > 0)
          ? _MacroMode.advanced
          : _MacroMode.simple;

      final enabled = existing.enabledSlots;
      final labels = existing.slotLabels;

      _slotEnabled = {
        for (final slot in MealSlot.values) slot: enabled.contains(slot),
      };
      _slotLabels = {
        for (final slot in MealSlot.values)
          slot: TextEditingController(
            text: labels[slot.index] ?? _defaultSlotLabel(slot),
          ),
      };
    } else {
      _slotEnabled = {
        for (final slot in MealSlot.values) slot: true,
      };
      _slotLabels = {
        for (final slot in MealSlot.values)
          slot: TextEditingController(text: _defaultSlotLabel(slot)),
      };
    }

    _titleCtrl.addListener(() => _recalcTitleSize(_titleCtrl.text));

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
    for (final c in _slotLabels.values) {
      c.dispose();
    }
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
      backgroundColor: _kEditorBg,
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
                      // TITLE (same placement/metrics as routine editor)
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
                                hintText: 'Diet plan name',
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
                                  _DietDataPanel(
                                    mode: _goalMode,
                                    macroMode: _macroMode,
                                    kcal: _kcal,
                                    protein: _protein,
                                    carbs: _carbs,
                                    fats: _fats,
                                    fastingHours: _fastingHours,
                                    onModeChanged: (m) =>
                                        setState(() => _goalMode = m),
                                    onMacroModeChanged: (m) =>
                                        setState(() => _macroMode = m),
                                    onKcalChanged: (v) =>
                                        setState(() => _kcal = v),
                                    onProteinChanged: (v) =>
                                        setState(() => _protein = v),
                                    onCarbsChanged: (v) =>
                                        setState(() => _carbs = v),
                                    onFatsChanged: (v) =>
                                        setState(() => _fats = v),
                                    onFastingChanged: (v) =>
                                        setState(() => _fastingHours = v),
                                  ),
                                  const SizedBox(height: 14),
                                  _MealSlotsPanel(
                                    enabled: _slotEnabled,
                                    controllers: _slotLabels,
                                    onToggleSlot: (slot, value) {
                                      setState(() {
                                        _slotEnabled[slot] = value;
                                      });
                                    },
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

          // FOOTER (Done/Cancel)
          Positioned(
            left: 0,
            right: 0,
            bottom: insets.bottom,
            child: Container(
              height: _kFooterH + pad.bottom,
              color: _kEditorBg,
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

          // INLINE CLOSE “X” (shown when standalone route)
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

// ===== panels / widgets =====

class _DietDataPanel extends StatelessWidget {
  const _DietDataPanel({
    required this.mode,
    required this.macroMode,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.fastingHours,
    required this.onModeChanged,
    required this.onMacroModeChanged,
    required this.onKcalChanged,
    required this.onProteinChanged,
    required this.onCarbsChanged,
    required this.onFatsChanged,
    required this.onFastingChanged,
  });

  final DietMode mode;
  final _MacroMode macroMode;
  final int kcal;
  final int protein;
  final int carbs;
  final int fats;
  final int fastingHours;

  final ValueChanged<DietMode> onModeChanged;
  final ValueChanged<_MacroMode> onMacroModeChanged;
  final ValueChanged<int> onKcalChanged;
  final ValueChanged<int> onProteinChanged;
  final ValueChanged<int> onCarbsChanged;
  final ValueChanged<int> onFatsChanged;
  final ValueChanged<int> onFastingChanged;

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
          _GoalSegmentedPill(
            value: mode,
            onChanged: onModeChanged,
          ),
          const Divider(color: Color(0xFF252628), height: 18),
          Row(
            children: [
              Expanded(
                child: _InlineEditNumber(
                  label: 'Daily kcal',
                  value: kcal == 0 ? '' : kcal.toString(),
                  onChanged: (v) {
                    if (v.isEmpty) {
                      onKcalChanged(0);
                    } else {
                      final p = int.tryParse(v);
                      if (p != null) onKcalChanged(p);
                    }
                  },
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF252628), height: 18),
          Row(
            children: [
              const Text(
                'Macro targets',
                style: TextStyle(color: Colors.white, fontSize: 13.5),
              ),
              const Spacer(),
              ChoiceChip(
                label: const Text('Simple'),
                selected: macroMode == _MacroMode.simple,
                onSelected: (_) => onMacroModeChanged(_MacroMode.simple),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Advanced'),
                selected: macroMode == _MacroMode.advanced,
                onSelected: (_) => onMacroModeChanged(_MacroMode.advanced),
              ),
            ],
          ),
          if (macroMode == _MacroMode.advanced) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InlineEditNumber(
                    label: 'Protein g',
                    value: protein == 0 ? '' : protein.toString(),
                    onChanged: (v) {
                      if (v.isEmpty) {
                        onProteinChanged(0);
                      } else {
                        final p = int.tryParse(v);
                        if (p != null) onProteinChanged(p);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InlineEditNumber(
                    label: 'Carbs g',
                    value: carbs == 0 ? '' : carbs.toString(),
                    onChanged: (v) {
                      if (v.isEmpty) {
                        onCarbsChanged(0);
                      } else {
                        final p = int.tryParse(v);
                        if (p != null) onCarbsChanged(p);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InlineEditNumber(
                    label: 'Fats g',
                    value: fats == 0 ? '' : fats.toString(),
                    onChanged: (v) {
                      if (v.isEmpty) {
                        onFatsChanged(0);
                      } else {
                        final p = int.tryParse(v);
                        if (p != null) onFatsChanged(p);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
          const Divider(color: Color(0xFF252628), height: 18),
          _InlineEditNumber(
            label: 'Fasting hours',
            value: fastingHours == 0 ? '' : fastingHours.toString(),
            onChanged: (v) {
              if (v.isEmpty) {
                onFastingChanged(0);
              } else {
                final p = int.tryParse(v);
                if (p != null) onFastingChanged(p);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _GoalSegmentedPill extends StatelessWidget {
  const _GoalSegmentedPill({
    required this.value,
    required this.onChanged,
  });

  final DietMode value;
  final ValueChanged<DietMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [DietMode.cut, DietMode.maintain, DietMode.bulk];

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
                  DietMode.cut => 'Cut',
                  DietMode.maintain => 'Maintain',
                  DietMode.bulk => 'Bulk',
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
            color: selected ? Colors.black : Colors.white.withValues(alpha: .72),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

class _MealSlotsPanel extends StatelessWidget {
  const _MealSlotsPanel({
    required this.enabled,
    required this.controllers,
    required this.onToggleSlot,
  });

  final Map<MealSlot, bool> enabled;
  final Map<MealSlot, TextEditingController> controllers;
  final void Function(MealSlot slot, bool value) onToggleSlot;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131416),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Meal slots',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...MealSlot.values.map((slot) {
            final isOn = enabled[slot] ?? true;
            final ctrl = controllers[slot]!;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Switch(
                    value: isOn,
                    onChanged: (value) => onToggleSlot(slot, value),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      enabled: isOn,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: _defaultSlotLabel(slot),
                        labelStyle: const TextStyle(color: Colors.white60),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InlineEditNumber extends StatefulWidget {
  const _InlineEditNumber({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_InlineEditNumber> createState() => _InlineEditNumberState();
}

class _InlineEditNumberState extends State<_InlineEditNumber> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _InlineEditNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
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
            controller: _controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: widget.onChanged,
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

// Default labels for meal slots.
String _defaultSlotLabel(MealSlot slot) {
  switch (slot) {
    case MealSlot.breakfast:
      return 'Breakfast';
    case MealSlot.lunch:
      return 'Lunch';
    case MealSlot.dinner:
      return 'Dinner';
    case MealSlot.snack:
      return 'Snack';
  }
}
