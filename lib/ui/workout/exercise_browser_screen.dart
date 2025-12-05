// lib/ui/workout/exercise_browser_screen.dart
import 'package:flutter/material.dart';
import 'package:kontinuum/models/workout_models.dart';
import 'package:kontinuum/ui/common/safe_network_image.dart';
import 'package:kontinuum/services/workout_boxes.dart';
import 'package:kontinuum/ui/theme/app_colors.dart';
import 'package:kontinuum/utils/text_format.dart';

const _kBg = Color(0xFF0A0A0B);

class ExerciseBrowserScreen extends StatefulWidget {
  const ExerciseBrowserScreen({super.key});

  @override
  State<ExerciseBrowserScreen> createState() => _ExerciseBrowserScreenState();
}

class _ExerciseBrowserScreenState extends State<ExerciseBrowserScreen> {
  String _query = '';
  int _activeTab = 0;
  List<Exercise> _all = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  void _loadExercises() {
    try {
      final box = WorkoutBoxes.exerciseBox;
      final list = box.values.whereType<Exercise>().toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _all = list;
        _loaded = true;
      });
      debugPrint('🔎 ExerciseBrowser: loaded ${list.length} exercises');
    } catch (e, st) {
      debugPrint('⚠️ ExerciseBrowser: failed to load exercises: $e');
      debugPrint('$st');
      setState(() {
        _all = const [];
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilters(_all, _query, _activeTab);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Exercise Library',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Column(
              children: [
                const SizedBox(height: 4),
                _HeaderTabs(
                  active: _activeTab,
                  total: _all.length,
                  onChanged: (i) => setState(() => _activeTab = i),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SearchField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: const [
                      _FilterPill(label: 'Muscle'),
                      SizedBox(width: 8),
                      _FilterPill(label: 'Equipment'),
                      SizedBox(width: 8),
                      _FilterPill(label: 'Difficulty'),
                      SizedBox(width: 8),
                      _FilterPill(label: 'Intent'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final ex = filtered[i];
                      return _ExerciseCard(
                        exercise: ex,
                        onTap: () => _showDetails(ex),
                        onPick: () => Navigator.of(context).pop(ex.id),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  List<Exercise> _applyFilters(
    List<Exercise> source,
    String query,
    int tab,
  ) {
    Iterable<Exercise> out = source;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      out = out.where((e) {
        if (e.name.toLowerCase().contains(q)) return true;
        if (e.muscles.any((m) => m.toLowerCase().contains(q))) return true;
        if (e.equipment.any((eq) => eq.toLowerCase().contains(q))) return true;
        return false;
      });
    }
    // later: tab 1 = favorites, tab 2 = recents
    return out.toList();
  }

  void _showDetails(Exercise ex) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final mediaUrl = ex.mediaUrl;
        final hasMedia = mediaUrl != null && mediaUrl.isNotEmpty;
        final height = MediaQuery.of(ctx).size.height * 0.9;

        return SizedBox(
          height: height,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // title + close
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ex.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).maybePop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in ex.muscles) _TagChip(label: m),
                      for (final eq in ex.equipment)
                        _TagChip(label: eq, icon: Icons.construction),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // HYBRID: small media, big text (tiny + non-zoomed)
                  if (hasMedia)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: SafeNetworkImage(
                            url: mediaUrl,
                            width: 110,
                            height: 110,
                            radius: 14,
                            fit: BoxFit.contain,
                            backgroundColor:
                                Colors.white.withValues(alpha: .02),
                            filterQuality: FilterQuality.high,
                            errorPlaceholder: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.white24,
                                size: 32,
                              ),
                            ),
                            placeholder: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.white24,
                                size: 32,
                              ),
                            ),
                            loadingPlaceholder:
                                const _SquareMediaLoadingPlaceholder(),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child:
                              _InstructionsBlock(instructions: ex.instructions),
                        ),
                      ],
                    )
                  else
                    _InstructionsBlock(instructions: ex.instructions),

                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(ex.id);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Use this exercise',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// widgets
// -----------------------------------------------------------------------------
class _HeaderTabs extends StatelessWidget {
  const _HeaderTabs({
    required this.active,
    required this.total,
    required this.onChanged,
  });

  final int active;
  final int total;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 16),
        _TabBtn(
          label: 'All ($total)',
          active: active == 0,
          onTap: () => onChanged(0),
        ),
        const SizedBox(width: 10),
        _TabBtn(
          label: 'Favorites',
          active: active == 1,
          onTap: () => onChanged(1),
        ),
        const SizedBox(width: 10),
        _TabBtn(
          label: 'Recents',
          active: active == 2,
          onTap: () => onChanged(2),
        ),
      ],
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg =
        active ? AppColors.accentBlue : Colors.white.withValues(alpha: .01);
    final fg = active ? Colors.white : Colors.white.withValues(alpha: .6);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? AppColors.accentBlue.withValues(alpha: .4)
                : Colors.white.withValues(alpha: .06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search exercises...',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: .35)),
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: .03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accentBlue),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: .015),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .7),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more,
              size: 16, color: Colors.white.withValues(alpha: .4)),
        ],
      ),
    );
  }
}

class _SquareMediaLoadingPlaceholder extends StatelessWidget {
  const _SquareMediaLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.onTap,
    required this.onPick,
  });

  final Exercise exercise;
  final VoidCallback onTap;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final musc = exercise.muscles.map(formatTitleCase).join(', ');
    final equip = exercise.equipment.map(formatTitleCase).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .015),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .04)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          formatTitleCase(exercise.name),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (musc.isNotEmpty)
              Text(
                musc,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .55),
                  fontSize: 12.5,
                ),
              ),
            if (equip.isNotEmpty)
              Text(
                equip,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .35),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.white70),
          onPressed: onTap,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white.withValues(alpha: .6)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionsBlock extends StatelessWidget {
  const _InstructionsBlock({required this.instructions});

  final String instructions;

  @override
  Widget build(BuildContext context) {
    final text = instructions.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Instructions',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        if (text.isNotEmpty)
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .8),
              fontSize: 13.5,
              height: 1.5,
            ),
          )
        else
          Text(
            'No instructions provided.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .4),
            ),
          ),
      ],
    );
  }
}
