// lib/ui/screens/diet/diet_home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:kontinuum/providers/diet_provider.dart';
import 'package:kontinuum/models/diet_models.dart';
import 'package:kontinuum/ui/screens/diet/diet_log_sheet.dart';
import 'package:kontinuum/core/time/app_clock.dart';

class DietHomeScreen extends StatefulWidget {
  const DietHomeScreen({super.key});

  @override
  State<DietHomeScreen> createState() => _DietHomeScreenState();
}

class _DietHomeScreenState extends State<DietHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // palette
    const bg = Color(0xFF0A0A0B);
    const surface = Color(0xFF0E1320);
    const onSurface = Color(0xFFF5F7FA);
    const subtext = Color(0xFF9AA4B2);
    const outline = Color(0xFF273043);
    const accent = Color(0xFFB59BFF);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: onSurface,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Diet',
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const Spacer(),
                  Consumer<DietProvider>(
                    builder: (context, diet, _) {
                      final mode = diet.goal.mode;
                      final title = mode.isEmpty
                          ? 'Unknown'
                          : mode[0].toUpperCase() + mode.substring(1);
                      return GestureDetector(
                        onTap: () {
                          showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: const Color(0xFF0E1320),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(18),
                              ),
                            ),
                            builder: (_) => const _DietGoalSheet(),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2735),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .03),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.expand_more_rounded,
                                color: onSurface.withValues(alpha: .6),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // tabs
            Container(
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: outline.withValues(alpha: .18),
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabCtrl,
                isScrollable: false,
                labelColor: onSurface,
                unselectedLabelColor: subtext.withValues(alpha: .7),
                indicatorColor: accent,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overlayColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.pressed)
                      ? outline.withValues(alpha: .08)
                      : null,
                ),
                tabs: const [
                  Tab(text: 'Today'),
                  Tab(text: 'Planner'),
                  Tab(text: 'Foods'),
                  Tab(text: 'Insights'),
                ],
              ),
            ),

            // content
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _DietTodayTab(
                    accent: accent,
                    surface: surface,
                    outline: outline,
                    onSurface: onSurface,
                    subtext: subtext,
                  ),
                  _DietPlannerTab(
                    accent: accent,
                    surface: surface,
                    outline: outline,
                    onSurface: onSurface,
                    subtext: subtext,
                  ),
                  _DietFoodsTab(
                    accent: accent,
                    surface: surface,
                    outline: outline,
                    onSurface: onSurface,
                    subtext: subtext,
                  ),
                  _DietInsightsTab(
                    accent: accent,
                    surface: surface,
                    outline: outline,
                    onSurface: onSurface,
                    subtext: subtext,
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

// ---------------------------------------------------------------------------
// TODAY TAB
// ---------------------------------------------------------------------------

class _DietTodayTab extends StatelessWidget {
  const _DietTodayTab({
    required this.accent,
    required this.surface,
    required this.outline,
    required this.onSurface,
    required this.subtext,
  });

  final Color accent;
  final Color surface;
  final Color outline;
  final Color onSurface;
  final Color subtext;

  double _lbsToKg(double lbs) => lbs / 2.2046226218;

  @override
  Widget build(BuildContext context) {
    return Consumer<DietProvider>(
      builder: (context, diet, _) {
        final today = AppClock.now();
        final goal = diet.goal;
        final total = diet.caloriesForDay(today).toDouble();
        final target = goal.caloriesTarget.toDouble();
        final pct = target == 0 ? 0.0 : (total / target).clamp(0.0, 1.0);

        final breakfasts = diet.entriesForSlotEnum(today, MealSlot.breakfast);
        final lunches = diet.entriesForSlotEnum(today, MealSlot.lunch);
        final dinners = diet.entriesForSlotEnum(today, MealSlot.dinner);
        final snacks = diet.entriesForSlotEnum(today, MealSlot.snack);

        return Container(
          color: const Color(0xFF0A0A0B),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              Text(
                _pretty(today),
                style: TextStyle(
                  color: subtext.withValues(alpha: .8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Today',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              // progress
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: outline.withValues(alpha: .18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calories',
                      style: TextStyle(
                        color: onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${total.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} kcal',
                      style: TextStyle(
                        color: subtext,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 8,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: onSurface.withValues(alpha: .05),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: pct,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      accent,
                                      accent.withValues(alpha: .35),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _openLogWeightSheet(context),
                        icon: const Icon(
                          Icons.monitor_weight_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Log weight',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _mealCard(
                context,
                title: 'Breakfast',
                entries: breakfasts,
                surface: surface,
                onSurface: onSurface,
                subtext: subtext,
                slot: MealSlot.breakfast,
                date: today,
              ),
              _mealCard(
                context,
                title: 'Lunch',
                entries: lunches,
                surface: surface,
                onSurface: onSurface,
                subtext: subtext,
                slot: MealSlot.lunch,
                date: today,
              ),
              _mealCard(
                context,
                title: 'Dinner',
                entries: dinners,
                surface: surface,
                onSurface: onSurface,
                subtext: subtext,
                slot: MealSlot.dinner,
                date: today,
              ),
              _mealCard(
                context,
                title: 'Snacks',
                entries: snacks,
                surface: surface,
                onSurface: onSurface,
                subtext: subtext,
                slot: MealSlot.snack,
                date: today,
              ),
            ],
          ),
        );
      },
    );
  }

  String _pretty(DateTime d) {
    return '${_weekdayShort(d.weekday)}, ${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  String _weekdayShort(int w) {
    switch (w) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
      default:
        return 'Sun';
    }
  }

  Widget _mealCard(
    BuildContext context, {
    required String title,
    required List<DietEntry> entries,
    required Color surface,
    required Color onSurface,
    required Color subtext,
    required MealSlot slot,
    required DateTime date,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: entries.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nothing logged yet',
                        style: TextStyle(
                          color: subtext.withValues(alpha: .75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final e in entries)
                        GestureDetector(
                          onLongPress: () => _showEntryActions(context, e),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${e.name} • ${e.calories} kcal',
                              style: TextStyle(
                                color: onSurface.withValues(alpha: .9),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          GestureDetector(
            onTap: () => _openAddDietEntrySheet(context, slot, date),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEntryActions(BuildContext context, DietEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E1320),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .24),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text(
                  'Edit',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: const Color(0xFF0E1320),
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    isScrollControlled: true,
                    builder: (_) => DietLogSheet(
                      editingEntryId: entry.id,
                      defaultDate: entry.date,
                      defaultSlot: entry.mealSlot,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  await context.read<DietProvider>().deleteEntry(entry.id);
                  if (context.mounted) Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _openAddDietEntrySheet(
    BuildContext context,
    MealSlot slot,
    DateTime date,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E1320),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DietLogSheet(
        defaultSlot: slot,
        defaultDate: date,
      ),
    );
  }

  void _openLogWeightSheet(BuildContext context) {
    final ctrl = TextEditingController();
    DateTime picked = AppClock.now();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E1320),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const Text(
                    'Log weight',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        DateFormat.yMMMd().format(picked),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final now = AppClock.now();
                          final res = await showDatePicker(
                            context: context,
                            initialDate: picked,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 1),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Color(0xFFB59BFF),
                                    surface: Color(0xFF0E1320),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (res != null) {
                            setModal(() => picked = res);
                          }
                        },
                        child: const Text('Pick date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Weight (lbs)',
                      labelStyle:
                          TextStyle(color: Colors.white.withValues(alpha: .6)),
                      filled: true,
                      fillColor: const Color(0xFF1A2030),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final text = ctrl.text.trim();
                        final weightLbs = double.tryParse(text);
                        if (weightLbs == null) return;
                        final weightKg = _lbsToKg(weightLbs);
                        await context.read<DietProvider>().logWeight(
                              weightKg: weightKg,
                              date: picked,
                            );
                        if (context.mounted) Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB59BFF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// PLANNER TAB
// ---------------------------------------------------------------------------

class _DietPlannerTab extends StatefulWidget {
  const _DietPlannerTab({
    required this.accent,
    required this.surface,
    required this.outline,
    required this.onSurface,
    required this.subtext,
  });

  final Color accent;
  final Color surface;
  final Color outline;
  final Color onSurface;
  final Color subtext;

  @override
  State<_DietPlannerTab> createState() => _DietPlannerTabState();
}

class _DietPlannerTabState extends State<_DietPlannerTab> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = AppClock.now();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DietProvider>(
      builder: (context, diet, _) {
        final selected = _selected;
        final target = diet.goal.caloriesTarget.toDouble();
        final total = diet.caloriesForDay(selected).toDouble();
        final pct = target == 0 ? 0.0 : (total / target).clamp(0.0, 1.0);

        final breakfasts =
            diet.entriesForSlotEnum(selected, MealSlot.breakfast);
        final lunches = diet.entriesForSlotEnum(selected, MealSlot.lunch);
        final dinners = diet.entriesForSlotEnum(selected, MealSlot.dinner);
        final snacks = diet.entriesForSlotEnum(selected, MealSlot.snack);

        return Container(
          color: const Color(0xFF0A0A0B),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              Text(
                'Planner',
                style: TextStyle(
                  color: widget.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              PlannerProgressRingBar(
                selectedDate: selected,
                getProgressForDay: (day) {
                  final t = diet.caloriesForDay(day).toDouble();
                  final tar = diet.goal.caloriesTarget.toDouble();
                  if (tar <= 0) return 0.0;
                  return t / tar.clamp(0.0, 1.0);
                },
                onDateSelected: (day) {
                  setState(() {
                    _selected = day;
                  });
                },
              ),
              const SizedBox(height: 18),
              // progress for selected day
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: widget.outline.withValues(alpha: .18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.yMMMMEEEEd().format(selected),
                      style: TextStyle(
                        color: widget.subtext.withValues(alpha: .8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Calories',
                      style: TextStyle(
                        color: widget.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${total.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} kcal',
                      style: TextStyle(
                        color: widget.subtext,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 8,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: widget.onSurface.withValues(alpha: .05),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: pct,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      widget.accent,
                                      widget.accent.withValues(alpha: .35),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _plannerMealCard(
                context,
                title: 'Breakfast',
                entries: breakfasts,
                slot: MealSlot.breakfast,
                date: selected,
              ),
              _plannerMealCard(
                context,
                title: 'Lunch',
                entries: lunches,
                slot: MealSlot.lunch,
                date: selected,
              ),
              _plannerMealCard(
                context,
                title: 'Dinner',
                entries: dinners,
                slot: MealSlot.dinner,
                date: selected,
              ),
              _plannerMealCard(
                context,
                title: 'Snacks',
                entries: snacks,
                slot: MealSlot.snack,
                date: selected,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _plannerMealCard(
    BuildContext context, {
    required String title,
    required List<DietEntry> entries,
    required MealSlot slot,
    required DateTime date,
  }) {
    final onSurface = widget.onSurface;
    final subtext = widget.subtext;
    final surface = widget.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: entries.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nothing logged yet',
                        style: TextStyle(
                          color: subtext.withValues(alpha: .75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final e in entries)
                        GestureDetector(
                          onLongPress: () => _showEntryActions(context, e),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${e.name} • ${e.calories} kcal',
                              style: TextStyle(
                                color: onSurface.withValues(alpha: .9),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          GestureDetector(
            onTap: () => _openAddDietEntrySheet(context, slot, date),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEntryActions(BuildContext context, DietEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E1320),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .24),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text(
                  'Edit',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: const Color(0xFF0E1320),
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    isScrollControlled: true,
                    builder: (_) => DietLogSheet(
                      editingEntryId: entry.id,
                      defaultDate: entry.date,
                      defaultSlot: entry.mealSlot,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  await context.read<DietProvider>().deleteEntry(entry.id);
                  if (context.mounted) Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _openAddDietEntrySheet(
    BuildContext context,
    MealSlot slot,
    DateTime date,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E1320),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DietLogSheet(
        defaultSlot: slot,
        defaultDate: date,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FOODS TAB
// ---------------------------------------------------------------------------

class _DietFoodsTab extends StatefulWidget {
  const _DietFoodsTab({
    required this.accent,
    required this.surface,
    required this.outline,
    required this.onSurface,
    required this.subtext,
  });

  final Color accent;
  final Color surface;
  final Color outline;
  final Color onSurface;
  final Color subtext;

  @override
  State<_DietFoodsTab> createState() => _DietFoodsTabState();
}

class _DietFoodsTabState extends State<_DietFoodsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<DietProvider>(
      builder: (context, diet, _) {
        final all = diet.foods;
        final list = _query.isEmpty
            ? all
            : all
                .where(
                    (f) => f.name.toLowerCase().contains(_query.toLowerCase()))
                .toList();

        return Container(
          color: const Color(0xFF0A0A0B),
          child: Column(
            children: [
              // search
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: TextField(
                  style: TextStyle(color: widget.onSurface),
                  cursorColor: widget.accent,
                  decoration: InputDecoration(
                    hintText: 'Search foods…',
                    hintStyle:
                        TextStyle(color: widget.subtext.withValues(alpha: .6)),
                    filled: true,
                    fillColor: widget.surface,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    prefixIcon: Icon(
                      Icons.search,
                      color: widget.subtext.withValues(alpha: .7),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: widget.outline.withValues(alpha: .14),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: widget.outline.withValues(alpha: .14),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: widget.accent.withValues(alpha: .75),
                      ),
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _query = v;
                    });
                  },
                ),
              ),

              // header + add new
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Row(
                  children: [
                    Text(
                      'Saved foods',
                      style: TextStyle(
                        color: widget.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _openCreateFood(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New'),
                      style: TextButton.styleFrom(
                        foregroundColor: widget.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ],
                ),
              ),

              // list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final f = list[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: widget.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.outline.withValues(alpha: .06),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        title: Text(
                          f.name,
                          style: TextStyle(
                            color: widget.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${f.calories} kcal'
                          '${f.protein > 0 ? ' • ${f.protein.toStringAsFixed(0)}g P' : ''}'
                          '${f.carbs > 0 ? ' • ${f.carbs.toStringAsFixed(0)}g C' : ''}'
                          '${f.fats > 0 ? ' • ${f.fats.toStringAsFixed(0)}g F' : ''}',
                          style: TextStyle(
                            color: widget.subtext.withValues(alpha: .8),
                            fontSize: 12,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          color: widget.onSurface,
                          onPressed: () => _openAddToDay(context, f),
                        ),
                        onLongPress: () => _openEditFood(context, f),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCreateFood(BuildContext context) {
    _openFoodSheet(
      context,
      onSubmit: (name, kcal, p, c, f) async {
        await context.read<DietProvider>().addFood(
              name: name,
              calories: kcal,
              protein: p,
              carbs: c,
              fats: f,
            );
      },
    );
  }

  void _openEditFood(BuildContext context, DietFood food) {
    _openFoodSheet(
      context,
      initial: food,
      onSubmit: (name, kcal, p, c, f) async {
        await context.read<DietProvider>().updateFood(
              food.copyWith(
                name: name,
                calories: kcal,
                protein: p,
                carbs: c,
                fats: f,
              ),
            );
      },
      onDelete: () async {
        await context.read<DietProvider>().deleteFood(food.id);
      },
    );
  }

  void _openAddToDay(BuildContext context, DietFood food) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E1320),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        DateTime picked = AppClock.now();
        MealSlot slot = MealSlot.breakfast;

        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Text(
                    'Add "${food.name}"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        '${picked.month}/${picked.day}/${picked.year}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final now = AppClock.now();
                          final res = await showDatePicker(
                            context: context,
                            initialDate: picked,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 1),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: widget.accent,
                                    surface: const Color(0xFF0E1320),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (res != null) {
                            setModal(() => picked = res);
                          }
                        },
                        child: const Text('Pick date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: MealSlot.values.map((m) {
                      final selected = m == slot;
                      return ChoiceChip(
                        label: Text(
                          m.label,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                          ),
                        ),
                        selected: selected,
                        selectedColor: widget.accent,
                        backgroundColor: Colors.white.withValues(alpha: .05),
                        onSelected: (_) {
                          setModal(() => slot = m);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        await context.read<DietProvider>().addFoodToDay(
                              food,
                              date: picked,
                              slot: slot,
                            );
                        if (context.mounted) Navigator.of(ctx).pop();
                      },
                      child: const Text('Add to day'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openFoodSheet(
    BuildContext context, {
    DietFood? initial,
    required Future<void> Function(
            String name, int kcal, double p, double c, double f)
        onSubmit,
    Future<void> Function()? onDelete,
  }) {
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final kcalCtrl =
        TextEditingController(text: initial?.calories.toString() ?? '');
    final pCtrl =
        TextEditingController(text: initial?.protein.toString() ?? '');
    final cCtrl = TextEditingController(text: initial?.carbs.toString() ?? '');
    final fCtrl = TextEditingController(text: initial?.fats.toString() ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1320),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text(
                  initial == null ? 'New food' : 'Edit food',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 14),
                _foodField('Name', nameCtrl),
                _foodField('Calories (kcal)', kcalCtrl,
                    keyboard: TextInputType.number),
                Row(
                  children: [
                    Expanded(
                      child: _foodField(
                        'Protein (g)',
                        pCtrl,
                        keyboard: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _foodField(
                        'Carbs (g)',
                        cCtrl,
                        keyboard: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _foodField(
                        'Fats (g)',
                        fCtrl,
                        keyboard: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final kcal = int.tryParse(kcalCtrl.text.trim()) ?? 0;
                      final p = double.tryParse(pCtrl.text.trim()) ?? 0;
                      final c = double.tryParse(cCtrl.text.trim()) ?? 0;
                      final f = double.tryParse(fCtrl.text.trim()) ?? 0;

                      await onSubmit(name, kcal, p, c, f);
                      if (context.mounted) Navigator.of(ctx).pop();
                    },
                    child: const Text('Save'),
                  ),
                ),
                if (onDelete != null && initial != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () async {
                        await onDelete();
                        if (context.mounted) Navigator.of(ctx).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _foodField(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: .6),
          ),
          filled: true,
          fillColor: const Color(0xFF1A2030),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// INSIGHTS TAB (7 days + latest weight)
// ---------------------------------------------------------------------------

class _DietInsightsTab extends StatelessWidget {
  const _DietInsightsTab({
    required this.accent,
    required this.surface,
    required this.outline,
    required this.onSurface,
    required this.subtext,
  });

  final Color accent;
  final Color surface;
  final Color outline;
  final Color onSurface;
  final Color subtext;

  double _kgToLbs(double kg) => kg * 2.2046226218;
  double _lbsToKg(double lbs) => lbs / 2.2046226218;

  @override
  Widget build(BuildContext context) {
    return Consumer<DietProvider>(
      builder: (context, diet, _) {
        final today = AppClock.now();
        final target = diet.goal.caloriesTarget;
        final days = List.generate(7, (i) => today.subtract(Duration(days: i)));
        final latest = diet.latestWeight; // _DietWeightLog? from provider
        final latestLbs = latest != null
            ? _kgToLbs(latest.weightKg).toStringAsFixed(1)
            : null;

        return Container(
          color: const Color(0xFF0A0A0B),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              Text(
                'Insights',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Last 7 days vs target',
                style: TextStyle(
                  color: subtext.withValues(alpha: .85),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              if (latest != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: outline.withValues(alpha: .16)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monitor_weight_outlined,
                          color: Colors.white),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Latest weight',
                            style: TextStyle(
                              color: subtext.withValues(alpha: .9),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '$latestLbs lbs',
                            style: TextStyle(
                              color: onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _openLogWeightSheet(context),
                        child: const Text('Update'),
                      ),
                    ],
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => _openLogWeightSheet(context),
                  icon: const Icon(Icons.monitor_weight_outlined,
                      color: Colors.white),
                  label: const Text(
                    'Log your weight',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              for (final day in days)
                _insightDayRow(
                  day: day,
                  cals: diet.caloriesForDay(day),
                  target: target,
                  surface: surface,
                  onSurface: onSurface,
                  subtext: subtext,
                  accent: accent,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _insightDayRow({
    required DateTime day,
    required int cals,
    required int target,
    required Color surface,
    required Color onSurface,
    required Color subtext,
    required Color accent,
  }) {
    final double pct = target <= 0
        ? 0.0
        : ((cals.toDouble() / target.toDouble()).clamp(0.0, 1.0) as double);
    final df = DateFormat.MMMd().add_E();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              df.format(day),
              style: TextStyle(
                color: onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(
                      color: onSurface.withValues(alpha: .04),
                    ),
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent,
                              accent.withValues(alpha: .35),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$cals/${target == 0 ? '—' : target} kcal',
            style: TextStyle(
              color: subtext.withValues(alpha: .85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _openLogWeightSheet(BuildContext context) {
    final ctrl = TextEditingController();
    DateTime picked = AppClock.now();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E1320),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const Text(
                    'Log weight',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        DateFormat.yMMMd().format(picked),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final now = AppClock.now();
                          final res = await showDatePicker(
                            context: context,
                            initialDate: picked,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 1),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Color(0xFFB59BFF),
                                    surface: Color(0xFF0E1320),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (res != null) {
                            setModal(() => picked = res);
                          }
                        },
                        child: const Text('Pick date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Weight (lbs)',
                      labelStyle:
                          TextStyle(color: Colors.white.withValues(alpha: .6)),
                      filled: true,
                      fillColor: const Color(0xFF1A2030),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final text = ctrl.text.trim();
                        final weightLbs = double.tryParse(text);
                        if (weightLbs == null) return;
                        final weightKg = _lbsToKg(weightLbs);
                        await context.read<DietProvider>().logWeight(
                              weightKg: weightKg,
                              date: picked,
                            );
                        if (context.mounted) Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB59BFF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// GOAL SHEET
// ---------------------------------------------------------------------------

class _DietGoalSheet extends StatelessWidget {
  const _DietGoalSheet();

  @override
  Widget build(BuildContext context) {
    final diet = context.watch<DietProvider>();
    final current = diet.goal.mode;

    Widget buildTile(String mode, String label, String desc) {
      final selected = current == mode;
      return ListTile(
        onTap: () async {
          await context.read<DietProvider>().updateGoalMode(mode);
          if (context.mounted) Navigator.of(context).pop();
        },
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? Colors.white : Colors.white.withValues(alpha: .4),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        subtitle: Text(
          desc,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .4),
            fontSize: 12,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const Text(
            'Diet mode',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          buildTile('cut', 'Cut', 'Slight deficit / lose fat'),
          buildTile('maintain', 'Maintain', 'Stay around current weight'),
          buildTile('bulk', 'Bulk', 'Caloric surplus / gain muscle'),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SCROLLING PROGRESS RING BAR (planner)
// ---------------------------------------------------------------------------

class PlannerProgressRingBar extends StatefulWidget {
  const PlannerProgressRingBar({
    super.key,
    required this.selectedDate,
    required this.getProgressForDay,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final double Function(DateTime) getProgressForDay;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<PlannerProgressRingBar> createState() => _PlannerProgressRingBarState();
}

class _PlannerProgressRingBarState extends State<PlannerProgressRingBar> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  static const double itemWidth = 60;

  static const Color _kAccent = Color(0xFFA56ABD);
  static const Color _kProgressGreen = Color(0xFF8EB69B);

  static const double _kProgressSize = 48;
  static const double _kProgressStroke = 5;
  static const double _kRingWidth = 1.6;
  static const double _kRingGap = 2.0;

  static const Duration _ringFade = Duration(milliseconds: 420);
  static const double _kRingScaleMin = 0.90;

  final Map<int, double> _prevProgressByDayIndex = {};
  int? _cachedYear;
  Timer? _throttle;
  Timer? _midnightTimer;

  int _dayIndexUtc(DateTime d) {
    final a = DateTime.utc(d.year, 1, 1);
    final b = DateTime.utc(d.year, d.month, d.day);
    return b.difference(a).inDays;
  }

  int _daysInYearUtc(int year) {
    final a = DateTime.utc(year, 1, 1);
    final b = DateTime.utc(year + 1, 1, 1);
    return b.difference(a).inDays;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCenter(widget.selectedDate, jump: true);
    });
    _scrollController.addListener(() {
      if (_throttle != null) return;
      _throttle = Timer(const Duration(milliseconds: 16), () {
        _throttle = null;
        if (mounted) setState(() => _scrollOffset = _scrollController.offset);
      });
    });
    _scheduleMidnightTick();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _throttle?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCenter(DateTime date, {bool jump = false}) {
    final index = _dayIndexUtc(date);
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = (index * itemWidth) - (screenWidth / 2 - itemWidth / 2);

    void go() {
      final maxExtent = _scrollController.hasClients
          ? _scrollController.position.maxScrollExtent
          : 0.0;
      final clamped = offset.clamp(0.0, maxExtent);
      if (jump) {
        _scrollController.jumpTo(clamped);
      } else {
        _scrollController.animateTo(
          clamped,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }

    if (_scrollController.hasClients) {
      go();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => go());
    }
  }

  double _calculateScale(double itemCenter, double screenCenter) {
    final distance = (itemCenter - screenCenter).abs();
    const maxDistance = 200.0;
    final t = (distance / maxDistance).clamp(0.0, 1.0);
    return 1.0 - (0.3 * t);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _weekday3(int w) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(w - 1) % 7];
  }

  void _scheduleMidnightTick() {
    _midnightTimer?.cancel();
    final now = AppClock.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final delay = tomorrow.difference(now) + const Duration(milliseconds: 50);
    _midnightTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _scheduleMidnightTick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = widget.selectedDate;
    final startOfYearLocal = DateTime(selectedDate.year, 1, 1);
    final daysInYear = _daysInYearUtc(selectedDate.year);
    final screenWidth = MediaQuery.of(context).size.width;
    final nowLocal = AppClock.now();

    final double ringSize = _kProgressSize + 2 * _kRingWidth + 2 * _kRingGap;

    if (_cachedYear != selectedDate.year) {
      _prevProgressByDayIndex.clear();
      _cachedYear = selectedDate.year;
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemExtent: itemWidth,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
        itemCount: daysInYear,
        itemBuilder: (context, index) {
          final day = startOfYearLocal.add(Duration(days: index));
          final isToday = _isSameDay(day, nowLocal);
          final isSelected = _isSameDay(day, selectedDate);
          final currentProgress =
              widget.getProgressForDay(day).clamp(0.0, 1.0).toDouble();

          final prev = _prevProgressByDayIndex[index] ?? currentProgress;
          _prevProgressByDayIndex[index] = currentProgress;

          final itemStart = index * itemWidth;
          final itemCenter = itemStart + itemWidth / 2;
          final screenCenter = _scrollOffset + screenWidth / 2;
          final scale = _calculateScale(itemCenter, screenCenter);

          Color dayTextColor = Colors.white;
          if (isToday) dayTextColor = Colors.purpleAccent;
          if (isSelected) dayTextColor = _kAccent;

          return GestureDetector(
            onTap: () {
              widget.onDateSelected(day);
              _scrollToCenter(day);
            },
            child: SizedBox(
              width: itemWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_weekday3(day.weekday),
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Transform.scale(
                    scale: scale,
                    alignment: Alignment.center,
                    child: RepaintBoundary(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: prev, end: currentProgress),
                            duration: const Duration(milliseconds: 550),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) {
                              return CustomPaint(
                                size: const Size.square(_kProgressSize),
                                painter: _GradientProgressPainter(
                                  progress: value.clamp(0.0, 1.0),
                                  strokeWidth: _kProgressStroke,
                                  trackColor: Colors.grey.shade800,
                                  startColor: Colors.white,
                                  endColor: _kProgressGreen,
                                  startAngle: -3.1415926535 / 2,
                                ),
                              );
                            },
                          ),
                          IgnorePointer(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                  begin: 0.0, end: isSelected ? 1.0 : 0.0),
                              duration: _ringFade,
                              curve: Curves.easeInOutCubic,
                              builder: (context, t, child) {
                                final double s =
                                    _kRingScaleMin + (1.0 - _kRingScaleMin) * t;
                                return Opacity(
                                  opacity: t,
                                  child: Transform.scale(
                                    scale: s,
                                    child: child,
                                  ),
                                );
                              },
                              child: Container(
                                width: ringSize,
                                height: ringSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _kAccent,
                                    width: _kRingWidth,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: dayTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GradientProgressPainter extends CustomPainter {
  _GradientProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.startColor,
    required this.endColor,
    required this.startAngle,
  });

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color startColor;
  final Color endColor;
  final double startAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    canvas.drawArc(rect, 0, 2 * 3.1415926535, false, trackPaint);

    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0) return;

    final sweep = 2 * 3.1415926535 * clamped;

    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweep,
      colors: [startColor, endColor],
      stops: const [0.0, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    canvas.drawArc(rect, startAngle, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientProgressPainter old) {
    return old.progress != progress ||
        old.strokeWidth != strokeWidth ||
        old.trackColor != trackColor ||
        old.startColor != startColor ||
        old.endColor != endColor ||
        old.startAngle != startAngle;
  }
}
