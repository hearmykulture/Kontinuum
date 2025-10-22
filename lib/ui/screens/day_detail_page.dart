// lib/ui/screens/day_detail_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/utils/date_keys.dart';
import 'package:kontinuum/ui/screens/reminder_time_picker_page_v2.dart' as rtp;

// Keep the page import for the UI
import 'package:kontinuum/ui/screens/task_editor_page.dart' as tedit;
// Import the editor value types separately (moved to models)
import 'package:kontinuum/ui/screens/task_editor/models.dart' as tmodel;

// XP UI + data
import 'package:kontinuum/ui/widgets/xp_gain_bottom_bar.dart';
import 'package:kontinuum/providers/objective_provider.dart';
// ⬇️ used to map stat → category when awarding fallback XP
import 'package:kontinuum/data/stat_repository.dart';

/// --------------------------------------------------------------------------------
/// Lightweight in-memory store (swap with Hive/DB later without touching the UI)
/// Now supports multi-day reminder *series* via groupId.
/// --------------------------------------------------------------------------------
class DayPlanStore extends ChangeNotifier {
  static final DayPlanStore I = DayPlanStore._();
  DayPlanStore._();

  final Map<String, _DayPlan> _byKey = {};

  _DayPlan _get(DateTime day) =>
      _byKey.putIfAbsent(_k(day), () => _DayPlan(dateOnly(day)));

  List<Reminder> reminders(DateTime day) =>
      List.unmodifiable(_get(day).reminders);
  List<Task> tasks(DateTime day) => List.unmodifiable(_get(day).tasks);

  /// --- Basic add (single slice) ---
  void addReminder(DateTime day, Reminder r, {bool notify = true}) {
    _get(day).reminders.add(r);
    if (notify) notifyListeners();
  }

  /// --- Add a *series* (multi-day). One notify at the end by default. ---
  void addReminderSeries({
    required String groupId,
    required String title,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    bool notify = true,
  }) {
    // Ensure end is at or after start (local/naive).
    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }
    final startDay = dateOnly(start);
    final endDay = dateOnly(end);
    final totalDays = endDay.difference(startDay).inDays;

    for (int i = 0; i <= totalDays; i++) {
      final d = startDay.add(Duration(days: i));

      TimeOfDay? segStart;
      TimeOfDay? segEnd;

      if (allDay) {
        segStart = null;
        segEnd = null;
      } else {
        if (i == 0 && i == totalDays) {
          // single-day
          segStart = TimeOfDay(hour: start.hour, minute: start.minute);
          segEnd = TimeOfDay(hour: end.hour, minute: end.minute);
        } else if (i == 0) {
          // first day → until end of day
          segStart = TimeOfDay(hour: start.hour, minute: start.minute);
          segEnd = const TimeOfDay(hour: 23, minute: 59);
        } else if (i == totalDays) {
          // last day → from start of day
          segStart = const TimeOfDay(hour: 0, minute: 0);
          segEnd = TimeOfDay(hour: end.hour, minute: end.minute);
        } else {
          // middle day → full day
          segStart = const TimeOfDay(hour: 0, minute: 0);
          segEnd = const TimeOfDay(hour: 23, minute: 59);
        }
      }

      final slice = Reminder(
        id: genId(),
        groupId: groupId,
        title: title,
        start: segStart,
        end: segEnd,
      );
      _get(d).reminders.add(slice);
    }
    if (notify) notifyListeners();
  }

  /// Remove all slices that belong to a series.
  void removeReminderGroup(String groupId, {bool notify = true}) {
    for (final p in _byKey.values) {
      p.reminders.removeWhere((r) => r.groupId == groupId);
    }
    if (notify) notifyListeners();
  }

  /// Convenience for edit: replace whole series with new definition.
  void replaceReminderGroup({
    required String groupId,
    required String title,
    required DateTime start,
    required DateTime end,
    required bool allDay,
  }) {
    removeReminderGroup(groupId, notify: false);
    addReminderSeries(
      groupId: groupId,
      title: title,
      start: start,
      end: end,
      allDay: allDay,
      notify: false,
    );
    notifyListeners();
  }

  void addTask(DateTime day, Task t, {bool notify = true}) {
    _get(day).tasks.add(t);
    if (notify) notifyListeners();
  }

  /// Move a task to another day while preserving its ID.
  void moveTask(
    DateTime fromDay,
    String id,
    DateTime toDay, {
    Task? replaceWith,
    bool notify = true,
  }) {
    final src = _get(fromDay).tasks;
    final i = src.indexWhere((t) => t.id == id);
    if (i == -1) return;
    final moving = replaceWith ?? src[i];
    src.removeAt(i);
    _get(toDay).tasks.add(moving);
    if (notify) notifyListeners();
  }

  // Stable-ish id generator for in-memory use (swap for uuid when persisted)
  static String genId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  void toggleTask(DateTime day, String id, bool value) {
    final list = _get(day).tasks;
    final i = list.indexWhere((t) => t.id == id);
    if (i == -1) return;

    final cur = list[i];
    // Update the task in-place
    list[i] = cur.copyWith(
      done: value,
      completedAt: value ? DateTime.now() : null,
    );

    // NOTE: reward is triggered by UI fallback if needed

    // Repeat-on-completion: spawn a clone for the next day (no intermediate notify)
    if (value && cur.repeatOnCompletion) {
      final nextDay = dateOnly(day).add(const Duration(days: 1));
      final clone = cur.copyWith(
        id: genId(),
        done: false,
        completedAt: null,
        scheduledStart: cur.scheduledStart?.add(const Duration(days: 1)),
        scheduledEnd: cur.scheduledEnd?.add(const Duration(days: 1)),
        checklist: cur.checklist
            .map((c) => TaskChecklistEntry(text: c.text, done: false))
            .toList(),
      );
      addTask(nextDay, clone, notify: false);
    }

    // Single notify for the whole toggle operation
    notifyListeners();
  }

  // ===== Helpers (single-slice edit/delete) =====
  void removeReminder(DateTime day, String id) {
    final list = _get(day).reminders;
    list.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void replaceReminder(DateTime day, String id, Reminder next) {
    final list = _get(day).reminders;
    final i = list.indexWhere((r) => r.id == id);
    if (i != -1) {
      list[i] = next;
      notifyListeners();
    }
  }

  void removeTask(DateTime day, String id) {
    final list = _get(day).tasks;
    list.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void replaceTask(DateTime day, String id, Task next) {
    final list = _get(day).tasks;
    final i = list.indexWhere((t) => t.id == id);
    if (i != -1) {
      list[i] = next;
      notifyListeners();
    }
  }

  /// Helpers for series management/inspection
  List<Reminder> remindersInGroup(String groupId) {
    final out = <Reminder>[];
    for (final p in _byKey.values) {
      out.addAll(p.reminders.where((r) => r.groupId == groupId));
    }
    return out;
  }

  /// Returns the inclusive span of a reminder series across days.
  DateTimeRange? seriesSpan(String groupId) {
    DateTime? start;
    DateTime? end;
    for (final p in _byKey.values) {
      final any = p.reminders.any((r) => r.groupId == groupId);
      if (any) {
        start =
            (start == null) ? p.day : (p.day.isBefore(start!) ? p.day : start);
        end = (end == null) ? p.day : (p.day.isAfter(end!) ? p.day : end);
      }
    }
    if (start == null || end == null) return null;
    return DateTimeRange(start: start!, end: end!);
  }

  // ----- Derived views -----
  DaySummary summary(DateTime day) {
    final d = dateOnly(day);
    final rem = reminders(d);
    final ts = tasks(d);
    final done = ts.where((x) => x.done).length;
    final open = ts.length - done;
    final hasOverdue = ts.any(
      (t) => !t.done && t.due != null && dateOnly(t.due!).isBefore(d),
    );
    return DaySummary(
      events: rem.length,
      openTasks: open,
      doneTasks: done,
      hasOverdue: hasOverdue,
    );
  }

  AgendaView agendaFor(DateTime day) {
    final d = dateOnly(day);
    final rem = reminders(d);
    final ts = tasks(d);

    final scheduled = ts
        .where(
          (t) =>
              !t.done &&
              t.scheduledStart != null &&
              dateOnly(t.scheduledStart!) == d,
        )
        .toList()
      ..sort((a, b) => a.scheduledStart!.compareTo(b.scheduledStart!));

    final allDay = ts.where((t) => !t.done && t.scheduledStart == null).toList()
      ..sort((a, b) => (b.priority).compareTo(a.priority));

    final overdue = ts
        .where(
          (t) => !t.done && t.due != null && dateOnly(t.due!).isBefore(d),
        )
        .toList()
      ..sort((a, b) => (b.priority).compareTo(a.priority));

    final unscheduled = ts
        .where(
          (t) =>
              !t.done &&
              t.due != null &&
              !dateOnly(t.due!).isBefore(d) &&
              t.scheduledStart == null,
        )
        .toList()
      ..sort((a, b) => (b.priority).compareTo(a.priority));

    return AgendaView(
      events: rem,
      scheduled: scheduled,
      allDay: allDay,
      overdue: overdue,
      unscheduled: unscheduled,
    );
  }

  // Keying now uses centralized DateKeys (local yyyy-MM-dd)
  static String _k(DateTime d) => DateKeys.ymd(dateOnly(d));
  static DateTime dateOnly(DateTime d) => DateKeys.dateOnly(d);
}

class _DayPlan {
  _DayPlan(this.day);
  final DateTime day;
  final List<Reminder> reminders = [];
  final List<Task> tasks = [];
}

// Keep a local checklist entry type for tasks in the store
class TaskChecklistEntry {
  final String text;
  final bool done;
  const TaskChecklistEntry({required this.text, required this.done});
}

class Reminder {
  Reminder({
    required this.id,
    required this.title,
    required this.groupId,
    this.start,
    this.end,
  });

  final String id;
  final String groupId; // same across all slices of the series
  final String title;
  final TimeOfDay? start;
  final TimeOfDay? end;
}

class Task {
  Task({
    required this.id,
    required this.title,
    this.done = false,
    this.due,
    this.remindAt,
    this.scheduledStart,
    this.scheduledEnd,
    this.repeatOnCompletion = false,
    this.checklist = const <TaskChecklistEntry>[],
    this.priority = 0,
    this.projectId,
    this.completedAt,
    this.stats = const <tmodel.StatPick>[], // ✅ multi-stat payload
  });

  final String id;
  final String title;
  final bool done;
  final DateTime? due;
  final DateTime? remindAt;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final bool repeatOnCompletion;
  final List<TaskChecklistEntry> checklist;
  final int priority;
  final String? projectId;
  final DateTime? completedAt;

  /// New: selected stat rewards for this task (can be empty).
  final List<tmodel.StatPick> stats;

  Task copyWith({
    String? id,
    String? title,
    bool? done,
    DateTime? due,
    DateTime? remindAt,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    bool? repeatOnCompletion,
    List<TaskChecklistEntry>? checklist,
    int? priority,
    String? projectId,
    DateTime? completedAt,
    List<tmodel.StatPick>? stats, // ✅ copyWith support
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      done: done ?? this.done,
      due: due ?? this.due,
      remindAt: remindAt ?? this.remindAt,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      repeatOnCompletion: repeatOnCompletion ?? this.repeatOnCompletion,
      checklist: checklist ?? this.checklist,
      priority: priority ?? this.priority,
      projectId: projectId ?? this.projectId,
      completedAt: completedAt ?? this.completedAt,
      stats: stats ?? this.stats,
    );
  }
}

/// Derived structs for UI
class DaySummary {
  DaySummary({
    required this.events,
    required this.openTasks,
    required this.doneTasks,
    required this.hasOverdue,
  });
  final int events;
  final int openTasks;
  final int doneTasks;
  final bool hasOverdue;
}

class AgendaView {
  AgendaView({
    required this.events,
    required this.scheduled,
    required this.allDay,
    required this.overdue,
    required this.unscheduled,
  });
  final List<Reminder> events;
  final List<Task> scheduled;
  final List<Task> allDay;
  final List<Task> overdue;
  final List<Task> unscheduled;
}

/// --------------------------------------------------------------------------------
/// Day detail page with mode toggle (Summary <-> Schedule)
/// --------------------------------------------------------------------------------

enum _DetailTab { summary, schedule }

class DayDetailPage extends StatefulWidget {
  const DayDetailPage({super.key, required this.day});

  final DateTime day;

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  // Summary palette (your current navy look)
  static const _bg = Color(0xFF131720);
  static const _muted = Color(0x80FFFFFF);

  // Schedule palette (maroon look)
  static const _schedBg = Color(0xFF4B0B19);
  static const _schedPanel = Color(0xFF5A0E1E);
  static const _schedMuted = Color(0xCCFFFFFF);

  // ✅ Default to Summary (blue) so blank-day opens the default view
  _DetailTab _tab = _DetailTab.summary;

  DateTime get _dayOnly => DayPlanStore.dateOnly(widget.day);

  Future<void> _openReminder(Reminder r) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => rtp.EmptyReminderTimePage(
          day: _dayOnly,
          existing: r, // pass slice (editor will edit whole series by groupId)
          autofocusTitle: false,
          showDelete: true,
        ),
      ),
    );
  }

  Future<void> _openTask(Task t) async {
    // Build initial options for the editor from the existing task
    final DateTime? initialDate = t.due ?? t.scheduledStart ?? t.remindAt;
    final tmodel.TaskOptionsValue initialOptions = tmodel.TaskOptionsValue(
      date: initialDate == null ? null : DayPlanStore.dateOnly(initialDate),
      someday: false, // if you support Someday as a stored flag, map it here
      repeatsDaily: t.repeatOnCompletion,
      hasReminder: t.remindAt != null,
      hasDeadline: t.due != null,
      stats: t.stats, // ✅ seed multi-stat picks into editor
    );

    final List<tmodel.ChecklistEntry> initialChecklist = t.checklist
        .map((TaskChecklistEntry c) =>
            tmodel.ChecklistEntry(text: c.text, done: c.done))
        .toList();

    final res = await Navigator.push<tmodel.TaskEditorResult>(
      context,
      MaterialPageRoute<tmodel.TaskEditorResult>(
        fullscreenDialog: true,
        builder: (_) => tedit.TaskEditorPage(
          initialTitle: t.title,
          autofocusTitle: false,
          showDelete: true,
          onDelete: () {
            DayPlanStore.I.removeTask(_dayOnly, t.id);
            Navigator.of(context).pop();
          },
          // Seed the page so reopening shows saved subtasks + options + stats.
          initialOptions: initialOptions,
          initialChecklist: initialChecklist,
        ),
      ),
    );

    if (res == null) return;

    // Map editor result back to the task model
    final pickedDate = res.date;
    final updated = t.copyWith(
      title: res.title,
      repeatOnCompletion: res.repeatOnCompletion,
      due: (res.hasDeadline && pickedDate != null)
          ? DayPlanStore.dateOnly(pickedDate)
          : null,
      remindAt: (res.hasReminder && pickedDate != null)
          ? DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 9, 0)
          : null,
      checklist: res.checklist
          .map((tmodel.ChecklistEntry c) =>
              TaskChecklistEntry(text: c.text, done: c.done))
          .toList(),
      stats: res.stats, // ✅ persist multi-stat picks from editor
    );

    // If the date was changed to another day, move the task (preserve ID)
    final newDay = DayPlanStore.dateOnly(res.date ?? _dayOnly);
    if (newDay != _dayOnly) {
      DayPlanStore.I.moveTask(_dayOnly, t.id, newDay, replaceWith: updated);
    } else {
      DayPlanStore.I.replaceTask(_dayOnly, t.id, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = DayPlanStore.dateOnly(widget.day);

    final isSchedule = _tab == _DetailTab.schedule;
    final bg = isSchedule ? _schedBg : _bg;
    final muted = isSchedule ? _schedMuted : _muted;

    final weekday = DateFormat.EEEE().format(d).toUpperCase();
    final monDay = DateFormat.MMMM().format(d).toUpperCase();
    final dayNum = DateFormat.d().format(d);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      color: bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                weekday,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$monDay $dayNum',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: _showAddSheet,
              tooltip: 'Add',
            ),
          ],
        ),
        body: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _tab == _DetailTab.summary
                  ? _SummaryView(day: d, key: const ValueKey('summary'))
                  : _ScheduleView(
                      day: d,
                      panelColor: _schedPanel,
                      onOpenReminder: _openReminder,
                      onOpenTask: _openTask,
                      key: const ValueKey('schedule'),
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 18 + MediaQuery.of(context).padding.bottom,
              child: Center(
                child: _BottomModeToggle(
                  tab: _tab,
                  onChanged: (t) => setState(() => _tab = t),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- add sheets --------------------

  void _showAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A2029),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AddActionTile(
                icon: Icons.event_rounded,
                label: 'Add reminder',
                onTap: () {
                  Navigator.pop(context);
                  _showAddReminder();
                },
              ),
              const SizedBox(height: 10),
              _AddActionTile(
                icon: Icons.check_circle_rounded,
                label: 'Add task',
                onTap: () {
                  Navigator.pop(context);
                  _showAddTask();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Launch the v2 reminder page (saves on Done)
  Future<void> _showAddReminder() async {
    final d = DayPlanStore.dateOnly(widget.day);
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => rtp.EmptyReminderTimePage(day: d),
        fullscreenDialog: true,
      ),
    );
  }

  /// Full-screen task editor (create mode)
  Future<void> _showAddTask() async {
    final d = DayPlanStore.dateOnly(widget.day);

    final result = await Navigator.push<tmodel.TaskEditorResult>(
      context,
      MaterialPageRoute<tmodel.TaskEditorResult>(
        fullscreenDialog: true,
        builder: (_) => const tedit.TaskEditorPage(),
      ),
    );

    if (result != null) {
      final placeOn = DayPlanStore.dateOnly(result.date ?? d);
      final task = Task(
        id: DayPlanStore.genId(),
        title: result.title,
        repeatOnCompletion: result.repeatOnCompletion,
        checklist: result.checklist
            .map((tmodel.ChecklistEntry c) =>
                TaskChecklistEntry(text: c.text, done: c.done))
            .toList(),
        due: (result.hasDeadline && result.date != null) ? placeOn : null,
        remindAt: (result.hasReminder && result.date != null)
            ? DateTime(placeOn.year, placeOn.month, placeOn.day, 9, 0)
            : null,
        stats: result.stats, // ✅ persist from create flow
      );
      DayPlanStore.I.addTask(placeOn, task);
      // Optional: mirror a one-hour reminder block at 9am if hasReminder
      if (task.remindAt != null) {
        DayPlanStore.I.addReminder(
          placeOn,
          Reminder(
            id: DayPlanStore.genId(),
            title: task.title,
            groupId: 'task_${task.id}',
            start: const TimeOfDay(hour: 9, minute: 0),
            end: const TimeOfDay(hour: 10, minute: 0),
          ),
        );
      }
    }
  }
}

/// -------------------- Summary View --------------------
class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.day, super.key});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DayPlanStore.I,
      builder: (_, __) {
        final reminders = DayPlanStore.I.reminders(day);
        final tasks = DayPlanStore.I.tasks(day);

        return ListView(
          key: const PageStorageKey('summary-list'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            const _SectionHeader('SCHEDULE'),
            if (reminders.isEmpty)
              _EmptyCard(
                label: 'No reminders yet',
                onTap: () => _showAddReminder(context),
              )
            else
              ...reminders.map(_ReminderCard.new),
            const SizedBox(height: 18),
            const _SectionHeader('TASKS'),
            if (tasks.isEmpty)
              _EmptyCard(
                label: 'No tasks yet',
                onTap: () => _showAddTask(context),
              )
            else
              ...tasks.map(
                (t) => _TaskCard(
                  task: t,
                  // ✅ Checkbox completes/toggles task
                  onChanged: (v) async {
                    if (v == true) {
                      await _completeTaskAndShowXp(context, day, t);
                    } else {
                      DayPlanStore.I.toggleTask(day, t.id, false);
                    }
                  },
                  // ✅ Title opens the Task Editor
                  onOpen: () => _openTask(context, t),
                ),
              ),
            const SizedBox(height: 18),
            const _SectionHeader('WEATHER'),
            _WeatherCard(day: day),
          ],
        );
      },
    );
  }

  // ---------- tiny safe getter wrapper ----------
  // Accepts any closure returning Object?, then returns it iff it's T.
  static T? _tryGet<T>(Object? Function() read) {
    try {
      final v = read();
      return v is T ? v : null;
    } catch (_) {
      return null;
    }
  }

  // safe navigation; no unnecessary !
  static void _showAddReminder(BuildContext context) => context
      .findAncestorStateOfType<_DayDetailPageState>()
      ?._showAddReminder();

  static void _showAddTask(BuildContext context) =>
      context.findAncestorStateOfType<_DayDetailPageState>()?._showAddTask();

  // ✅ Helper to reach the page's _openTask from this stateless widget
  static void _openTask(BuildContext context, Task t) =>
      context.findAncestorStateOfType<_DayDetailPageState>()?._openTask(t);

  // ---------- helpers for fallback awarding (robust StatPick probing) ----------
  /// Pull the category for a stat pick by looking up its **stat id**
  /// in StatRepository. We *never* assume fields like `categoryId` exist.
  static String? _catIdFromPick(tmodel.StatPick pick) {
    // Try common shapes, preferring `id`, then `statId`, then nested `stat.id`
    final String? statId = _tryGet<String>(() => (pick as dynamic).id) ??
        _tryGet<String>(() => (pick as dynamic).statId) ??
        _tryGet<String>(() => ((pick as dynamic).stat as dynamic).id);

    if (statId == null || statId.isEmpty) return null;
    final cat = StatRepository.getCategoryForStat(statId);
    return cat?.toUpperCase();
  }

  /// Read a numeric amount from the pick.
  static int _xpFromPick(tmodel.StatPick pick) {
    final num? n = _tryGet<num>(() => (pick as dynamic).value) ??
        _tryGet<num>(() => (pick as dynamic).amount) ??
        _tryGet<num>(() => (pick as dynamic).xp) ??
        _tryGet<num>(() => (pick as dynamic).count);
    if (n == null) return 0;
    return n is int ? n : n.round();
  }

  /// If toggling the task didn't change any category XP (e.g. rewarder didn't run),
  /// award based on the task's stat picks right here.
  static Future<bool> _tryFallbackAward(
    BuildContext context,
    ObjectiveProvider provider,
    Task t,
  ) async {
    bool any = false;
    for (final p in t.stats) {
      final catId = _catIdFromPick(p);
      final xp = _xpFromPick(p);
      if (catId != null && xp > 0) {
        provider.addXpToCategory(catId, xp);
        any = true;
      }
    }
    if (any) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return any;
  }

  // ✅ Completion helper that shows sequential XP popups per category that increased.
  static Future<void> _completeTaskAndShowXp(
    BuildContext context,
    DateTime day,
    Task t,
  ) async {
    final provider = context.read<ObjectiveProvider>();

    // Snapshot BEFORE per-category XP
    final before = <String, int>{
      for (final c in provider.categories.values) c.name: c.xp,
    };

    // Toggle complete (store will update local state)
    DayPlanStore.I.toggleTask(day, t.id, true);

    // Give any async work a tick
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!context.mounted) return;

    // Snapshot AFTER per-category XP
    Map<String, int> after = {
      for (final c in provider.categories.values) c.name: c.xp,
    };

    // Build positive deltas
    List<_CatDelta> deltas = [];
    after.forEach((name, xpAfter) {
      final xpBefore = before[name] ?? 0;
      final delta = xpAfter - xpBefore;
      if (delta > 0) {
        deltas.add(_CatDelta(name: name, from: xpBefore, to: xpAfter));
      }
    });

    // If nothing changed, try a UI-side fallback award from task stat picks.
    if (deltas.isEmpty && t.stats.isNotEmpty) {
      final didAward = await _tryFallbackAward(context, provider, t);
      if (didAward && context.mounted) {
        after = {for (final c in provider.categories.values) c.name: c.xp};
        deltas = [];
        after.forEach((name, xpAfter) {
          final xpBefore = before[name] ?? 0;
          final delta = xpAfter - xpBefore;
          if (delta > 0) {
            deltas.add(_CatDelta(name: name, from: xpBefore, to: xpAfter));
          }
        });
      }
    }

    if (deltas.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task completed. No XP change detected.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1400),
        ),
      );
      return;
    }

    // Sort largest gain first (nicer if many)
    deltas.sort((a, b) => (b.to - b.from).compareTo(a.to - a.from));

    // Show each popup sequentially
    for (final d in deltas) {
      if (!context.mounted) return;
      await XpGainBottomBar.show(
        context,
        label: d.name.toUpperCase(),
        fromXp: d.from,
        toXp: d.to,
        color: _xpColorForCategory(d.name),
      );
    }
  }
}

/// -------------------- Schedule View --------------------
class _ScheduleView extends StatelessWidget {
  const _ScheduleView({
    required this.day,
    required this.panelColor,
    required this.onOpenReminder,
    required this.onOpenTask,
    super.key,
  });

  final DateTime day;
  final Color panelColor;
  final void Function(Reminder r) onOpenReminder;
  final void Function(Task t) onOpenTask;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DayPlanStore.I,
      builder: (_, __) {
        final agenda = DayPlanStore.I.agendaFor(day);

        return ListView(
          key: const PageStorageKey('schedule-list'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            const _SectionHeader('SCHEDULE'),

            // Overdue bucket
            if (agenda.overdue.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF7A1B2C),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OVERDUE',
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...agenda.overdue.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onOpenTask(t),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFC0C0),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  t.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // All-day tasks bucket
            if (agenda.allDay.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ALL-DAY TASKS',
                      style: TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...agenda.allDay.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onOpenTask(t),
                          child: Row(
                            children: [
                              // ✅ Inline complete button
                              InkResponse(
                                onTap: () =>
                                    _SummaryView._completeTaskAndShowXp(
                                  context,
                                  day,
                                  t,
                                ),
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(6.0),
                                  child: Icon(
                                    Icons.circle_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Build unified items for the timeline (reminders + scheduled tasks)
            _TimelineBoard(
              items: [
                ...agenda.events.where((r) => r.start != null).map((r) {
                  final s = r.start!;
                  final e =
                      r.end ?? TimeOfDay(hour: s.hour + 1, minute: s.minute);
                  return _BoardItem.reminder(
                    id: r.id,
                    title: r.title,
                    startMin: s.hour * 60 + s.minute,
                    endMin: e.hour * 60 + e.minute,
                    source: r,
                  );
                }),
                ...agenda.scheduled.map((t) {
                  final s = t.scheduledStart!;
                  final e = t.scheduledEnd ?? s.add(const Duration(hours: 1));
                  return _BoardItem.task(
                    id: t.id,
                    title: t.title,
                    startMin: s.hour * 60 + s.minute,
                    endMin: e.hour * 60 + e.minute,
                    source: t,
                  );
                }),
              ],
              onTapItem: (itm) {
                if (itm.isTask) {
                  onOpenTask(itm.source as Task);
                } else {
                  onOpenReminder(itm.source as Reminder);
                }
              },
            ),
          ],
        );
      },
    );
  }
}

/// --------------------------------------------------------------------------------
/// Bottom pill toggle
/// --------------------------------------------------------------------------------
class _BottomModeToggle extends StatelessWidget {
  const _BottomModeToggle({required this.tab, required this.onChanged});
  final _DetailTab tab;
  final ValueChanged<_DetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isSchedule = tab == _DetailTab.schedule;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(40),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeIcon(
              icon: Icons.dehaze_rounded,
              selected: !isSchedule,
              onTap: () => onChanged(_DetailTab.summary),
            ),
            const SizedBox(width: 10),
            _ModeIcon(
              icon: Icons.schedule_rounded,
              selected: isSchedule,
              onTap: () => onChanged(_DetailTab.schedule),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeIcon extends StatelessWidget {
  const _ModeIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.white : const Color(0x33FFFFFF);
    final fg = selected ? const Color(0xFF620B19) : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg),
      ),
    );
  }
}

/// -------------------- UI bits (reused) --------------------
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0x99FFFFFF),
          letterSpacing: 3,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline, color: Color(0xCCFFFFFF)),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard(Reminder r) : reminder = r;
  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    String time = '';
    final s = reminder.start;
    final e = reminder.end;
    if (s != null && e != null) {
      time = '${s.format(context)} \u2192 ${e.format(context)}';
    } else if (s != null) {
      time = s.format(context);
    }

    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reminder.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                time,
                style: const TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onChanged,
    required this.onOpen,
  });

  final Task task;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ✅ Only this checkbox toggles completion
            Checkbox(
              value: task.done,
              onChanged: (v) => onChanged(v ?? false),
              shape: const CircleBorder(),
              side: const BorderSide(color: Colors.white70),
              activeColor: Colors.white,
              checkColor: const Color(0xFF262C34),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 6),
            // ✅ Only this title area opens the editor
            Expanded(
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 22, 16, 22),
        child: Column(
          children: [
            Icon(Icons.cloud, size: 34, color: Colors.white70),
            SizedBox(height: 8),
            Text(
              'Weather coming soon',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Connect a weather API to show temp, wind & humidity.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF262C34),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AddActionTile extends StatelessWidget {
  const _AddActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.white, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: const Color(0xFF262C34),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }
}

/// --------------------------------------------------------------------------------
/// Timeline board (now unified for reminders + scheduled tasks)
/// --------------------------------------------------------------------------------
class _TimelineBoard extends StatelessWidget {
  const _TimelineBoard({required this.items, required this.onTapItem});

  final List<_BoardItem> items;
  final void Function(_BoardItem item) onTapItem;

  static const double _leftLabelsWidth = 56;
  static const double _rowHeight = 76;
  static const double _rowSpacing = 8;
  static const double _contentRadius = 16;
  static const double _laneGap = 8;
  static const double _contentPadding = 10;
  static const int _dayMinutes = 24 * 60;

  double get _unitHeight => _rowHeight + _rowSpacing;

  @override
  Widget build(BuildContext context) {
    final events = <_Evt>[];
    for (final it in items) {
      final start = it.startMin.clamp(0, _dayMinutes - 1);
      final end = it.endMin.clamp(start + 15, _dayMinutes);
      events.add(_Evt(item: it, startMin: start, endMin: end));
    }
    events.sort((a, b) => a.startMin.compareTo(b.startMin));

    // lane packing
    final laneEnds = <int>[];
    for (final e in events) {
      int lane = 0;
      for (; lane < laneEnds.length; lane++) {
        if (e.startMin >= laneEnds[lane]) break;
      }
      if (lane == laneEnds.length) {
        laneEnds.add(e.endMin);
      } else {
        laneEnds[lane] = e.endMin;
      }
      e.lane = lane;
    }
    final laneCount = laneEnds.isEmpty ? 1 : laneEnds.length;
    final totalHeight = 24 * _unitHeight;

    return SizedBox(
      height: totalHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // left hour gutter
          SizedBox(
            width: _leftLabelsWidth,
            child: Column(
              children: List.generate(24, (h) {
                return SizedBox(
                  height: _unitHeight,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: _rowSpacing / 2),
                      child: Text(
                        DateFormat('h a')
                            .format(DateTime(0, 1, 1, h))
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          // board
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boardWidth = constraints.maxWidth;
                final contentWidth = boardWidth - _contentPadding * 2;
                final columnWidth =
                    (contentWidth - (laneCount - 1) * _laneGap) / laneCount;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _contentPadding,
                        ),
                        child: Column(
                          children: List.generate(24, (index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: _rowSpacing / 2,
                              ),
                              child: Container(
                                height: _rowHeight,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF641023),
                                  borderRadius:
                                      BorderRadius.circular(_contentRadius),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    ...events.map((e) {
                      final top =
                          (_rowSpacing / 2) + (e.startMin / 60.0) * _unitHeight;
                      var height =
                          ((e.endMin - e.startMin) / 60.0) * _unitHeight;
                      if (top + height > totalHeight) {
                        height = totalHeight - top;
                      }
                      final left =
                          _contentPadding + e.lane * (columnWidth + _laneGap);

                      return Positioned(
                        left: left,
                        width: columnWidth,
                        top: top,
                        height: height,
                        child: _BoardCard(
                          item: e.item,
                          onTap: () => onTapItem(e.item),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Evt {
  _Evt({required this.item, required this.startMin, required this.endMin});
  final _BoardItem item;
  final int startMin;
  final int endMin;
  int lane = 0;
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.item, this.onTap});
  final _BoardItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color:
                item.isTask ? const Color(0xFF27455A) : const Color(0xFF5A0E1E),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardItem {
  const _BoardItem._({
    required this.id,
    required this.title,
    required this.startMin,
    required this.endMin,
    required this.isTask,
    required this.source,
  });
  final String id;
  final String title;
  final int startMin;
  final int endMin;
  final bool isTask;
  final Object source; // Reminder or Task

  factory _BoardItem.reminder({
    required String id,
    required String title,
    required int startMin,
    required int endMin,
    required Reminder source,
  }) =>
      _BoardItem._(
        id: id,
        title: title,
        startMin: startMin,
        endMin: endMin,
        isTask: false,
        source: source,
      );

  factory _BoardItem.task({
    required String id,
    required String title,
    required int startMin,
    required int endMin,
    required Task source,
  }) =>
      _BoardItem._(
        id: id,
        title: title,
        startMin: startMin,
        endMin: endMin,
        isTask: true,
        source: source,
      );
}

/// -------------------- XP helpers --------------------
class _CatDelta {
  final String name;
  final int from;
  final int to;
  _CatDelta({required this.name, required this.from, required this.to});
}

// Match XpLevelBar colors so everything feels consistent.
Color _xpColorForCategory(String name) {
  switch (name.toLowerCase()) {
    case 'rapping':
      return Colors.redAccent;
    case 'production':
      return Colors.blueAccent;
    case 'health':
      return Colors.greenAccent;
    case 'knowledge':
      return Colors.deepPurpleAccent;
    case 'networking':
      return Colors.teal;
    case 'content':
      return Colors.cyan;
    default:
      return Colors.grey;
  }
}
