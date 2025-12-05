// lib/ui/workout/library_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/services/exercise_library_service.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/ui/theme/app_colors.dart';
import 'package:kontinuum/utils/text_format.dart';

class LibraryPickerScreen extends StatefulWidget {
  const LibraryPickerScreen({super.key});

  /// If you're opening this to "swap" an exercise, pass the current one
  /// so we can show "similar" as the first action.
  factory LibraryPickerScreen.forSwap({String? exerciseId}) {
    return LibraryPickerScreen(key: ValueKey('swap:$exerciseId'));
  }

  @override
  State<LibraryPickerScreen> createState() => _LibraryPickerScreenState();
}

enum _LibraryTab { all, favorites, recents, similar }

class _LibraryPickerScreenState extends State<LibraryPickerScreen> {
  _LibraryTab _tab = _LibraryTab.all;
  String _search = '';

  // simple in-screen filters for P0 (you can later source from service)
  String? _selectedMuscle;
  String? _selectedEquipment;
  ExerciseDifficulty? _selectedDifficulty;
  ExerciseIntent? _selectedIntent;

  // when user hits "view similar", we remember the source exercise
  String? _similarSourceId;

  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setTab(_LibraryTab tab) {
    setState(() {
      _tab = tab;
      if (tab != _LibraryTab.similar) {
        _similarSourceId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final all = wp.libraryAll();

    final list = _buildListForCurrentTab(wp);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Exercise Library',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(
              children: [
                _TabChip(
                  label: 'All (${all.length})',
                  selected: _tab == _LibraryTab.all,
                  onTap: () => _setTab(_LibraryTab.all),
                ),
                const SizedBox(width: 8),
                _TabChip(
                  label: 'Favorites',
                  selected: _tab == _LibraryTab.favorites,
                  onTap: () => _setTab(_LibraryTab.favorites),
                ),
                const SizedBox(width: 8),
                _TabChip(
                  label: 'Recents',
                  selected: _tab == _LibraryTab.recents,
                  onTap: () => _setTab(_LibraryTab.recents),
                ),
                if (_tab == _LibraryTab.similar) ...[
                  const SizedBox(width: 8),
                  _TabChip(
                    label: 'Similar',
                    selected: true,
                    onTap: () {}, // stay
                  ),
                ],
              ],
            ),
          ),

          // search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v.trim()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                hintText: 'Search exercises...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: .035),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: .05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: AppColors.accentBlue.withValues(alpha: .4)),
                ),
              ),
            ),
          ),

          // filters row
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChipPill(
                  label: _selectedMuscle ?? 'Muscle',
                  selected: _selectedMuscle != null,
                  onTap: () => _openMuscleSheet(context),
                ),
                const SizedBox(width: 8),
                _FilterChipPill(
                  label: _selectedEquipment ?? 'Equipment',
                  selected: _selectedEquipment != null,
                  onTap: () => _openEquipmentSheet(context),
                ),
                const SizedBox(width: 8),
                _FilterChipPill(
                  label: _selectedDifficulty?.name ?? 'Difficulty',
                  selected: _selectedDifficulty != null,
                  onTap: () => _openDifficultySheet(context),
                ),
                const SizedBox(width: 8),
                _FilterChipPill(
                  label: _selectedIntent?.name ?? 'Intent',
                  selected: _selectedIntent != null,
                  onTap: () => _openIntentSheet(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // list
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text(
                      'No exercises match these filters',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) {
                      final ex = list[i];
                      return _ExerciseTile(
                        exercise: ex,
                        onSelect: () {
                          Navigator.of(context).pop<String>(ex.id);
                        },
                        onFavorite: () {
                          wp.favoriteExercise(ex.id);
                        },
                        onSimilar: () {
                          setState(() {
                            _tab = _LibraryTab.similar;
                            _similarSourceId = ex.id;
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<Exercise> _buildListForCurrentTab(WorkoutProvider wp) {
    List<Exercise> base;

    switch (_tab) {
      case _LibraryTab.all:
        base = wp.libraryAll();
        break;
      case _LibraryTab.favorites:
        base = wp.libraryFavorites();
        break;
      case _LibraryTab.recents:
        base = wp.libraryRecents();
        break;
      case _LibraryTab.similar:
        if (_similarSourceId != null) {
          base = wp.similarExercises(_similarSourceId!);
        } else {
          base = const <Exercise>[];
        }
        break;
    }

    // apply filters
    base = base.where((ex) {
      // search
      if (_search.isNotEmpty) {
        final hay = '${ex.name} ${ex.cues?.join(' ') ?? ''}'.toLowerCase();
        if (!hay.contains(_search.toLowerCase())) return false;
      }

      // muscle
      if (_selectedMuscle != null && _selectedMuscle!.isNotEmpty) {
        if (ex.muscles == null || !ex.muscles!.contains(_selectedMuscle)) {
          return false;
        }
      }

      // equipment
      if (_selectedEquipment != null && _selectedEquipment!.isNotEmpty) {
        if (ex.equipment == null ||
            !ex.equipment!.contains(_selectedEquipment)) {
          return false;
        }
      }

      // difficulty
      if (_selectedDifficulty != null && ex.difficulty != _selectedDifficulty) {
        return false;
      }

      // intent
      if (_selectedIntent != null && ex.intent != _selectedIntent) {
        return false;
      }

      return true;
    }).toList();

    return base;
  }

  Future<void> _openMuscleSheet(BuildContext context) async {
    // in P0 we hardcode a tiny set; you can load from ExerciseLibraryService later
    final choices = <String>[
      'Chest',
      'Back',
      'Shoulders',
      'Arms',
      'Legs',
      'Glutes',
      'Core',
    ];

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0A0A0B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _BottomSheetPicker(
          title: 'Select muscle group',
          options: choices,
          selected: _selectedMuscle,
        );
      },
    );

    if (!mounted) return;
    setState(() => _selectedMuscle = picked);
  }

  Future<void> _openEquipmentSheet(BuildContext context) async {
    final choices = <String>[
      'Barbell',
      'Dumbbell',
      'Cable',
      'Machine',
      'Kettlebell',
      'Bodyweight',
    ];

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0A0A0B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _BottomSheetPicker(
          title: 'Select equipment',
          options: choices,
          selected: _selectedEquipment,
        );
      },
    );

    if (!mounted) return;
    setState(() => _selectedEquipment = picked);
  }

  Future<void> _openDifficultySheet(BuildContext context) async {
    final picked = await showModalBottomSheet<ExerciseDifficulty>(
      context: context,
      backgroundColor: const Color(0xFF0A0A0B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _BottomSheetEnumPicker<ExerciseDifficulty>(
          title: 'Select difficulty',
          values: ExerciseDifficulty.values,
          selected: _selectedDifficulty,
          labelBuilder: (v) => v.name,
        );
      },
    );

    if (!mounted) return;
    setState(() => _selectedDifficulty = picked);
  }

  Future<void> _openIntentSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<ExerciseIntent>(
      context: context,
      backgroundColor: const Color(0xFF0A0A0B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _BottomSheetEnumPicker<ExerciseIntent>(
          title: 'Select intent',
          values: ExerciseIntent.values,
          selected: _selectedIntent,
          labelBuilder: (v) => v.name,
        );
      },
    );

    if (!mounted) return;
    setState(() => _selectedIntent = picked);
  }
}

// -----------------------------------------------------------------------------
// UI helpers
// -----------------------------------------------------------------------------
class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.accentBlue.withValues(alpha: .16)
        : Colors.white.withValues(alpha: .02);
    final border = selected
        ? AppColors.accentBlue.withValues(alpha: .6)
        : Colors.white.withValues(alpha: .06);
    final txt = selected ? Colors.white : Colors.white.withValues(alpha: .75);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: txt,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _FilterChipPill extends StatelessWidget {
  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? Colors.white.withValues(alpha: .08)
        : Colors.white.withValues(alpha: .02);
    final border = selected
        ? AppColors.accentBlue.withValues(alpha: .5)
        : Colors.white.withValues(alpha: .04);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .85),
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.onSelect,
    required this.onFavorite,
    required this.onSimilar,
  });

  final Exercise exercise;
  final VoidCallback onSelect;
  final VoidCallback onFavorite;
  final VoidCallback onSimilar;

  @override
  Widget build(BuildContext context) {
    final muscles = exercise.muscles.map(formatTitleCase).join(', ');
    final eq = exercise.equipment.map(formatTitleCase).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .015),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .04)),
      ),
      child: ListTile(
        onTap: onSelect,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        title: Text(
          formatTitleCase(exercise.name),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (muscles.isNotEmpty)
              Text(
                muscles,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .55),
                  fontSize: 12,
                ),
              ),
            if (eq.isNotEmpty)
              Text(
                eq,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .35),
                  fontSize: 11.5,
                ),
              ),
          ],
        ),
        trailing: Wrap(
          spacing: 6,
          children: [
            IconButton(
              icon: const Icon(Icons.favorite, size: 20),
              color: Colors.white.withValues(alpha: .6),
              onPressed: onFavorite,
              tooltip: 'Favorite',
            ),
            IconButton(
              icon: const Icon(Icons.auto_awesome, size: 20),
              color: Colors.white.withValues(alpha: .6),
              onPressed: onSimilar,
              tooltip: 'View similar',
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetPicker extends StatelessWidget {
  const _BottomSheetPicker({
    required this.title,
    required this.options,
    this.selected,
  });

  final String title;
  final List<String> options;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          for (final opt in options)
            ListTile(
              title: Text(
                opt,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .9),
                ),
              ),
              trailing: selected == opt
                  ? const Icon(Icons.check, color: AppColors.accentBlue)
                  : null,
              onTap: () {
                Navigator.of(context).pop(opt);
              },
            ),
          ListTile(
            title: Text(
              'Clear',
              style: TextStyle(color: Colors.white.withValues(alpha: .5)),
            ),
            onTap: () => Navigator.of(context).pop(null),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _BottomSheetEnumPicker<T> extends StatelessWidget {
  const _BottomSheetEnumPicker({
    required this.title,
    required this.values,
    required this.selected,
    required this.labelBuilder,
  });

  final String title;
  final List<T> values;
  final T? selected;
  final String Function(T) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          for (final v in values)
            ListTile(
              title: Text(
                labelBuilder(v),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .9),
                ),
              ),
              trailing: selected == v
                  ? const Icon(Icons.check, color: AppColors.accentBlue)
                  : null,
              onTap: () {
                Navigator.of(context).pop<T>(v);
              },
            ),
          ListTile(
            title: Text(
              'Clear',
              style: TextStyle(color: Colors.white.withValues(alpha: .5)),
            ),
            onTap: () => Navigator.of(context).pop<T?>(null),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
