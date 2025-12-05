import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/fitness_profile.dart';
import 'package:kontinuum/providers/fitness_profile_provider.dart';
import 'package:kontinuum/providers/diet_provider.dart';
import 'package:kontinuum/ui/workout/workout_editor_constants.dart';

class FitnessScreeningFlow extends StatefulWidget {
  const FitnessScreeningFlow({super.key, this.forceCompletion = false});

  final bool forceCompletion;

  @override
  State<FitnessScreeningFlow> createState() => _FitnessScreeningFlowState();
}

class _FitnessScreeningFlowState extends State<FitnessScreeningFlow> {
  bool _submitting = false;

  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  WeightUnit _weightUnit = WeightUnit.lb;
  String _sexAtBirth = 'male';

  DietGoalKind _dietGoal = DietGoalKind.maintain;
  int _daysPerWeek = 3;
  TrainingEnvironment _environment = TrainingEnvironment.fullGym;
  final Set<String> _equipment = {'db', 'kb', 'bench', 'pullup_bar'};

  final Set<String> _dietaryRules = {};
  final Set<String> _protectedAreas = {};
  final Set<String> _movementAvoid = {};

  double _kgToLb(double kg) => kg * 2.2046226218;
  double _lbToKg(double lb) => lb / 2.2046226218;

  String _formatUnitValue(double value) {
    final bool isWholeNumber = value % 1 == 0;
    return value.toStringAsFixed(isWholeNumber ? 0 : 1);
  }

  void _setWeightUnit(WeightUnit unit) {
    if (_weightUnit == unit) return;
    final double? currentValue =
        double.tryParse(_weightCtrl.text.trim().replaceAll(',', ''));
    double? converted = currentValue;
    if (currentValue != null) {
      converted =
          unit == WeightUnit.kg ? _lbToKg(currentValue) : _kgToLb(currentValue);
    }
    setState(() {
      _weightUnit = unit;
      if (converted != null) {
        final formatted = _formatUnitValue(converted);
        _weightCtrl.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final age = int.tryParse(_ageCtrl.text.trim());
    final heightCm = double.tryParse(_heightCtrl.text.trim());
    final weightInput = double.tryParse(_weightCtrl.text.trim());
    final double? weightKg = weightInput == null
        ? null
        : (_weightUnit == WeightUnit.kg ? weightInput : _lbToKg(weightInput));
    if (age == null || heightCm == null || weightKg == null) {
      setState(() => _submitting = false);
      return;
    }

    final profileProvider = context.read<FitnessProfileProvider>();
    final dietProvider = context.read<DietProvider>();

    final equipment = _environment == TrainingEnvironment.partialHome
        ? _equipment.toList()
        : (_environment == TrainingEnvironment.fullGym
            ? const ['machines', 'barbell', 'dumbbell']
            : const ['bodyweight']);

    final profile = buildMvpProfile(
      age: age,
      sexAtBirth: _sexAtBirth,
      heightCm: heightCm,
      weightKg: weightKg,
      dietGoal: _dietGoal,
      daysPerWeek: _daysPerWeek,
      trainingEnvironment: _environment,
      dietaryRules: _dietaryRules.toList(),
      protectedAreas: _protectedAreas.toList(),
      excludedMovements: _movementAvoid.toList(),
      equipment: equipment,
    );

    await profileProvider.saveProfile(profile);
    await dietProvider.updateBaseCalories(profile.tdeeEstimate);
    await dietProvider.updateGoalMode(switch (profile.dietGoal) {
      DietGoalKind.cut => 'cut',
      DietGoalKind.bulk => 'bulk',
      DietGoalKind.maintain => 'maintain',
    });

    if (!mounted) return;

    setState(() => _submitting = false);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    void exitToProgress() {
      final rootNav = Navigator.of(context, rootNavigator: true);
      rootNav.popUntil((route) => route.isFirst);
    }

    return PopScope(
      canPop: !widget.forceCompletion,
      onPopInvoked: (didPop) {
        if (!didPop && !widget.forceCompletion) {
          exitToProgress();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF090A0E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: widget.forceCompletion
              ? null
              : IconButton(
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: exitToProgress,
                ),
          title: const Text(
            'Fitness screening',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            child: Column(
              children: [
                _identityStep(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7047EF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _identityStep() {
    return _CardShell(
      title: 'Basics',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tell us about you',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _textField(
            controller: _ageCtrl,
            label: 'Age',
            hint: 'Years',
            inputType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _segmented(
            label: 'Sex at birth',
            current: _sexAtBirth,
            options: const [
              ('female', 'Female'),
              ('male', 'Male'),
              ('other', 'Other'),
            ],
            onChanged: (value) => setState(() => _sexAtBirth = value),
          ),
          const SizedBox(height: 12),
          _textField(
            controller: _heightCtrl,
            label: 'Height (cm)',
            hint: 'e.g. 178',
            inputType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _textField(
            controller: _weightCtrl,
            label: 'Weight',
            hint: _weightUnit == WeightUnit.kg ? 'e.g. 75' : 'e.g. 165',
            inputType: TextInputType.number,
            trailing: _ScreeningWeightUnitToggle(
              selected: _weightUnit,
              onChanged: _setWeightUnit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType inputType = TextInputType.text,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing,
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: inputType,
          inputFormatters: inputType == TextInputType.number
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: .35)),
            filled: true,
            fillColor: const Color(0xFF14151A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _segmented<T>({
    required String label,
    required T current,
    required List<(T, String)> options,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131416),
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: options.map((entry) {
              final selected = entry.$1 == current;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(entry.$1),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF7047EF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      entry.$2,
                      style: TextStyle(
                        color: selected ? Colors.black : Colors.white,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

}

const List<WeightUnit> _weightToggleOrder = [WeightUnit.lb, WeightUnit.kg];

class _ScreeningWeightUnitToggle extends StatelessWidget {
  const _ScreeningWeightUnitToggle({
    required this.selected,
    required this.onChanged,
  });

  final WeightUnit selected;
  final ValueChanged<WeightUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color border = Colors.white.withValues(alpha: 0.2);
    final Color background = Colors.white.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: background,
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final unit in _weightToggleOrder)
            _ScreeningWeightUnitChip(
              unit: unit,
              selected: unit == selected,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _ScreeningWeightUnitChip extends StatelessWidget {
  const _ScreeningWeightUnitChip({
    required this.unit,
    required this.selected,
    required this.onChanged,
  });

  final WeightUnit unit;
  final bool selected;
  final ValueChanged<WeightUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color selectedBg = Colors.white.withValues(alpha: 0.28);
    final Color selectedFg = Colors.black;
    final Color unselectedFg = Colors.white.withValues(alpha: 0.65);

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

class _CardShell extends StatelessWidget {
  const _CardShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1015),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .8),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
