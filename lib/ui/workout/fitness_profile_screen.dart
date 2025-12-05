import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/fitness_profile.dart';
import 'package:kontinuum/providers/fitness_profile_provider.dart';
import 'package:kontinuum/providers/diet_provider.dart';
import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/core/time/app_clock.dart';

class FitnessProfileScreen extends StatefulWidget {
  const FitnessProfileScreen({super.key});

  @override
  State<FitnessProfileScreen> createState() => _FitnessProfileScreenState();
}

class _FitnessProfileScreenState extends State<FitnessProfileScreen> {
  late FitnessNutritionProfile _profile;

  late final TextEditingController _ageCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;

  late String _sexAtBirth;
  late DietGoalKind _dietGoal;
  late int _daysPerWeek;
  late TrainingEnvironment _environment;

  late final Set<String> _equipment;
  late final Set<String> _dietaryRules;
  late final Set<String> _protectedAreas;
  late final Set<String> _movementAvoid;
  String? _currentRoutineId;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<FitnessProfileProvider>();
    final profile = provider.profile;
    if (profile == null) {
      throw StateError('FitnessProfileScreen opened before screening');
    }
    _profile = profile;
    _ageCtrl = TextEditingController(text: profile.age.toString());
    _heightCtrl = TextEditingController(text: profile.heightCm.toStringAsFixed(0));
    _weightCtrl = TextEditingController(text: profile.weightKg.toStringAsFixed(1));

    _sexAtBirth = profile.sexAtBirth;
    _dietGoal = profile.dietGoal;
    _daysPerWeek = profile.daysPerWeek;
    _environment = profile.trainingEnvironment;

    _equipment = profile.equipment.toSet();
    _dietaryRules = profile.dietaryRules.toSet();
    _protectedAreas = profile.protectedAreas.toSet();
    _movementAvoid = profile.excludedMovementPatterns.toSet();
    final routines = context.read<WorkoutProvider>().routines;
    _currentRoutineId =
        profile.currentRoutineId ?? (routines.isNotEmpty ? routines.first.id : null);
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final age = int.tryParse(_ageCtrl.text.trim());
    final heightCm = double.tryParse(_heightCtrl.text.trim());
    final weightKg = double.tryParse(_weightCtrl.text.trim());

    if (age == null || heightCm == null || weightKg == null) {
      setState(() => _saving = false);
      return;
    }

    final currentRoutineId = _currentRoutineId;

    final equipment = _environment == TrainingEnvironment.partialHome
        ? _equipment.toList()
        : (_environment == TrainingEnvironment.fullGym
            ? const ['machines', 'barbell', 'dumbbell']
            : const ['bodyweight']);

    final bmr = calculateBmr(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      sexAtBirth: _sexAtBirth,
    );
    final tdee = (bmr * activityMultiplierForDays(_daysPerWeek)).round();
    final aggressiveness = adjustmentForDietGoal(_dietGoal);
    final calorieTarget = (tdee * aggressiveness).round();
    final proteinPerKg = defaultProteinPerKg(_dietGoal);

    final updated = _profile.copyWith(
      age: age,
      sexAtBirth: _sexAtBirth,
      heightCm: heightCm,
      weightKg: weightKg,
      daysPerWeek: _daysPerWeek,
      trainingEnvironment: _environment,
      dietGoal: _dietGoal,
      dietGoalAggressiveness: aggressiveness,
      tdeeEstimate: calorieTarget,
      proteinPerKg: proteinPerKg,
      protectedAreas: _protectedAreas.toList(),
      excludedMovementPatterns: _movementAvoid.toList(),
      dietaryRules: _dietaryRules.toList(),
      equipment: equipment,
      weighingFrequency: _profile.weighingFrequency,
      createdAt: _profile.createdAt,
      updatedAt: AppClock.now(),
      source: _profile.source,
      currentRoutineId: currentRoutineId,
    );

    final profileProvider = context.read<FitnessProfileProvider>();
    final dietProvider = context.read<DietProvider>();

    await profileProvider.saveProfile(updated);
    await dietProvider.updateBaseCalories(updated.tdeeEstimate);
    await dietProvider.updateGoalMode(switch (updated.dietGoal) {
      DietGoalKind.cut => 'cut',
      DietGoalKind.bulk => 'bulk',
      DietGoalKind.maintain => 'maintain',
    });

    if (mounted) {
      setState(() {
        _profile = updated;
      });
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final routines = wp.routines;

    final previewAge = int.tryParse(_ageCtrl.text.trim()) ?? _profile.age;
    final previewHeight =
        double.tryParse(_heightCtrl.text.trim()) ?? _profile.heightCm;
    final previewWeight =
        double.tryParse(_weightCtrl.text.trim()) ?? _profile.weightKg;
    final previewBmr = calculateBmr(
      weightKg: previewWeight,
      heightCm: previewHeight,
      age: previewAge,
      sexAtBirth: _sexAtBirth,
    );
    final previewTdee =
        (previewBmr * activityMultiplierForDays(_daysPerWeek)).round();
    final previewAggressiveness = adjustmentForDietGoal(_dietGoal);
    final previewCalories = (previewTdee * previewAggressiveness).round();
    final previewProtein = defaultProteinPerKg(_dietGoal);

    return Scaffold(
      backgroundColor: const Color(0xFF090A0E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Fitness profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionCard(
                title: 'Current routine',
                child: routines.isEmpty
                    ? const Text(
                        'No routines yet. Create one from the workout dashboard.',
                        style: TextStyle(color: Colors.white54),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: routines
                            .map(
                              (routine) => _radioTile(
                                label:
                                    '${routine.name} • ${_dietSummary(routine.diet)}',
                                selected: routine.id == _currentRoutineId,
                                onTap: () => setState(
                                    () => _currentRoutineId = routine.id),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 18),
              _sectionCard(
                title: 'Basics',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _textField(
                      controller: _ageCtrl,
                      label: 'Age',
                      hint: 'Years',
                    ),
                    const SizedBox(height: 12),
                    _segmented<String>(
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
                    ),
                    const SizedBox(height: 12),
                    _textField(
                      controller: _weightCtrl,
                      label: 'Weight (kg)',
                      hint: 'e.g. 75',
                      allowDecimal: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _sectionCard(
                title: 'Training',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _segmented<int>(
                      label: 'Days per week',
                      current: _daysPerWeek,
                      options: const [
                        (2, '2'),
                        (3, '3'),
                        (4, '4'),
                        (5, '5+'),
                      ],
                      onChanged: (value) =>
                          setState(() => _daysPerWeek = value == 5 ? 5 : value),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Training environment',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final env in TrainingEnvironment.values)
                      _radioTile(
                        label: switch (env) {
                          TrainingEnvironment.fullGym => 'Full gym access',
                          TrainingEnvironment.partialHome =>
                            'Home setup (dumbbells / bands)',
                          TrainingEnvironment.bodyweight => 'Bodyweight focus',
                        },
                        selected: _environment == env,
                        onTap: () => setState(() => _environment = env),
                      ),
                    if (_environment == TrainingEnvironment.partialHome) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Equipment available',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in const [
                            ('db', 'Dumbbells'),
                            ('kb', 'Kettlebells'),
                            ('pullup_bar', 'Pull-up bar'),
                            ('bench', 'Bench'),
                            ('bands', 'Resistance bands'),
                          ])
                            _chip(
                              label: item.$2,
                              selected: _equipment.contains(item.$1),
                              onTap: () {
                                setState(() {
                                  if (_equipment.contains(item.$1)) {
                                    _equipment.remove(item.$1);
                                  } else {
                                    _equipment.add(item.$1);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _sectionCard(
                title: 'Nutrition',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Goal',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    for (final goal in DietGoalKind.values)
                      _radioTile(
                        label: switch (goal) {
                          DietGoalKind.cut => 'Cut (fat loss)',
                          DietGoalKind.maintain => 'Maintain',
                          DietGoalKind.bulk => 'Gain muscle',
                        },
                        selected: _dietGoal == goal,
                        onTap: () => setState(() => _dietGoal = goal),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'Dietary rules',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in const [
                          ('no_pork', 'No pork'),
                          ('pescetarian', 'Pescetarian'),
                          ('dairy_free', 'Dairy-free'),
                          ('gluten_free', 'Gluten-free'),
                          ('halal', 'Halal'),
                          ('none', 'None'),
                        ])
                          _chip(
                            label: item.$2,
                            selected: _dietaryRules.contains(item.$1),
                            onTap: () {
                              setState(() {
                                if (item.$1 == 'none') {
                                  _dietaryRules
                                    ..clear()
                                    ..add('none');
                                } else {
                                  _dietaryRules.remove('none');
                                  if (_dietaryRules.contains(item.$1)) {
                                    _dietaryRules.remove(item.$1);
                                  } else {
                                    _dietaryRules.add(item.$1);
                                  }
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _sectionCard(
                title: 'Constraints',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Areas to protect',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final area in const [
                          ('shoulder', 'Shoulder'),
                          ('low_back', 'Low back'),
                          ('knee', 'Knee'),
                          ('wrist', 'Wrist'),
                          ('none', 'None'),
                        ])
                          _chip(
                            label: area.$2,
                            selected: _protectedAreas.contains(area.$1),
                            onTap: () {
                              setState(() {
                                if (area.$1 == 'none') {
                                  _protectedAreas
                                    ..clear()
                                    ..add('none');
                                } else {
                                  _protectedAreas.remove('none');
                                  if (_protectedAreas.contains(area.$1)) {
                                    _protectedAreas.remove(area.$1);
                                  } else {
                                    _protectedAreas.add(area.$1);
                                  }
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Movements to avoid',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final move in const [
                          ('barbell_overhead', 'Barbell overhead'),
                          ('heavy_hinge', 'Heavy hinge'),
                          ('deep_squat', 'Deep squat'),
                          ('running', 'Running impact'),
                        ])
                          _chip(
                            label: move.$2,
                            selected: _movementAvoid.contains(move.$1),
                            onTap: () {
                              setState(() {
                                if (_movementAvoid.contains(move.$1)) {
                                  _movementAvoid.remove(move.$1);
                                } else {
                                  _movementAvoid.add(move.$1);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'TDEE: $previewCalories kcal • Protein target: ${previewProtein.toStringAsFixed(1)} g/kg',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (_currentRoutineId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Current routine: ${_routineName(_currentRoutineId!, routines)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101118),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool allowDecimal = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(allowDecimal ? r'[0-9.]' : r'[0-9]'),
            ),
          ],
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
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF14151A),
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

  Widget _radioTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF1D1930) : const Color(0xFF121318),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? const Color(0xFF7047EF)
              : Colors.white.withValues(alpha: .05),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: Icon(
          selected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7047EF) : const Color(0xFF14151A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF7047EF)
                : Colors.white.withValues(alpha: .05),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _dietSummary(DietSettings diet) {
    final goalLabel = switch (diet.goal) {
      DietGoal.cut => 'Cut',
      DietGoal.maintain => 'Maintain',
      DietGoal.bulk => 'Bulk',
    };
    return '$goalLabel · ${diet.kcalPerDay} kcal · ${diet.proteinTargetG}g';
  }

  String _routineName(String id, List<Routine> routines) {
    return routines.firstWhere(
      (r) => r.id == id,
      orElse: () => Routine(
        id: id,
        name: 'Routine',
        poEnabled: true,
        diet: DietSettings(
          goal: DietGoal.maintain,
          kcalPerDay: 0,
          proteinTargetG: 0,
          strictness: DietStrictness.soft,
        ),
        workoutIds: const [],
        createdAtMs: 0,
        restSchedule: null,
        scheduleMode: RepetitionMode.weekly,
      ),
    ).name;
  }
}
