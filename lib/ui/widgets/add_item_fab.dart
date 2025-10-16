// lib/ui/widgets/add_item_fab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/data/stat_repository.dart';

class AddItemFab extends StatelessWidget {
  const AddItemFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'add_item_fab',
      onPressed: () => _showAddMenu(context),
      backgroundColor: const Color(0xFF6C63FF),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Add'),
    );
  }

  // ————— Shared popup shell (matches Objective/Level popups) —————
  Future<T?> _showCardDialog<T>(
    BuildContext context, {
    required Widget child,
    Color accent = const Color(0xFF6C63FF),
  }) {
    final bg = const Color(0xFF0F1218);
    final border = accent;
    final glow = accent.withAlpha(60);

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, minWidth: 320),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              // ↓ tighten top padding a bit
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border, width: 1.2),
                boxShadow: [
                  BoxShadow(color: glow, blurRadius: 28, spreadRadius: 3),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return Transform.scale(
          scale: 0.98 + 0.02 * curved.value,
          child: Opacity(opacity: anim.value, child: child),
        );
      },
    );
  }

  // ————— Root "Create" menu —————
  void _showAddMenu(BuildContext context) {
    _showCardDialog(
      context,
      // ↓ remove unwanted top padding from SafeArea
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Grabber(),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Create',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _MenuTile(
              icon: Icons.category_outlined,
              title: "New Category",
              subtitle: "Pick a name and color",
              onTap: () {
                Navigator.pop(context);
                _showNewCategoryCard(context);
              },
            ),
            const SizedBox(height: 10),
            _MenuTile(
              icon: Icons.flag_outlined,
              title: "New Objective",
              subtitle: "Name, type, XP, stats, schedule, category",
              onTap: () {
                Navigator.pop(context);
                _showNewObjectiveCard(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNewCategoryCard(BuildContext context) {
    _showCardDialog(context, child: const _NewCategoryCard());
  }

  void _showNewObjectiveCard(BuildContext context) {
    _showCardDialog(context, child: const _NewObjectiveCard());
  }
}

class _Grabber extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      width: 44,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF14141B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white10,
              child: Icon(icon, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

/// ===================== CATEGORY CARD =====================
class _NewCategoryCard extends StatefulWidget {
  const _NewCategoryCard();

  @override
  State<_NewCategoryCard> createState() => _NewCategoryCardState();
}

class _NewCategoryCardState extends State<_NewCategoryCard> {
  final _nameCtrl = TextEditingController();
  Color _selected = Colors.tealAccent;

  static const _palette = <Color>[
    Colors.amberAccent,
    Colors.redAccent,
    Colors.pinkAccent,
    Colors.deepPurpleAccent,
    Colors.blueAccent,
    Colors.cyanAccent,
    Colors.greenAccent,
    Colors.tealAccent,
    Colors.orangeAccent,
    Colors.limeAccent,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.78;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Grabber(),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'New Category',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: 'e.g. BRANDING',
                  hintStyle: TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Color(0xFF0D1116),
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Color',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _palette
                    .map(
                      (c) => GestureDetector(
                        onTap: () => setState(() => _selected = c),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c.withAlpha(48),
                            border: Border.all(
                              color: _selected == c ? c : Colors.white24,
                              width: _selected == c ? 2.0 : 1.0,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final name = _nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a name.')),
                      );
                      return;
                    }
                    context.read<ObjectiveProvider>().createCategory(
                      name,
                      color: _selected,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Category "${name.toUpperCase()}" created',
                        ),
                      ),
                    );
                  },
                  child: const Text('Create Category'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===================== OBJECTIVE CARD =====================
class _NewObjectiveCard extends StatefulWidget {
  const _NewObjectiveCard();

  @override
  State<_NewObjectiveCard> createState() => _NewObjectiveCardState();
}

class _NewObjectiveCardState extends State<_NewObjectiveCard> {
  // Core inputs
  final _titleCtrl = TextEditingController();
  final _xpCtrl = TextEditingController(text: '10');
  final _targetCtrl = TextEditingController(text: '1');

  ObjectiveType _type = ObjectiveType.standard;
  String? _selectedCategory;

  // Stats selection
  final List<String> _statIds = [];

  // Schedule
  bool _daily = true;
  final Map<int, bool> _weekday = {
    for (int i = 1; i <= 7; i++) i: true,
  }; // Mon..Sun
  bool _useInterval = false;
  int _everyNDays = 1;
  DateTime _anchor = DateTime.now();
  DateTime _startDate = DateTime.now();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _xpCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  String _typeLabel(ObjectiveType t) {
    switch (t) {
      case ObjectiveType.standard:
        return 'Standard (checkbox)';
      case ObjectiveType.tally:
        return 'Tally / counter';
      case ObjectiveType.stopwatch:
        return 'Stopwatch / duration';
      case ObjectiveType.writingPrompt:
        return 'Writing prompt';
      case ObjectiveType.reflective:
        return 'Reflective';
      case ObjectiveType.subtask:
        return 'Subtask';
    }
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _weekdayLabel(int weekday) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ObjectiveProvider>();
    final categories = provider.categories.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    final accent =
        (_selectedCategory != null &&
            provider.categories[_selectedCategory!]?.colorInt != null)
        ? Color(provider.categories[_selectedCategory!]!.colorInt!)
        : const Color(0xFF6C63FF);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Grabber(),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'New Objective',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Close',
                  ),
                ],
              ),

              // Title
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: 'e.g. Post on social media',
                  hintStyle: TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Color(0xFF0D1116),
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),

              // Type
              const SizedBox(height: 12),
              _Section(
                title: 'Objective Type',
                child: DropdownButtonFormField<ObjectiveType>(
                  value: _type,
                  dropdownColor: const Color(0xFF1C1C24),
                  style: const TextStyle(color: Colors.white),
                  items: ObjectiveType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(_typeLabel(t)),
                        ),
                      )
                      .toList(),
                  onChanged: (t) => setState(() => _type = t ?? _type),
                ),
              ),

              // XP + Target
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Section(
                      title: 'XP Reward',
                      child: TextField(
                        controller: _xpCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: '10',
                          hintStyle: TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Color(0xFF0D1116),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Section(
                      title: 'Target (amount/min)',
                      child: TextField(
                        controller: _targetCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: '1',
                          hintStyle: TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Color(0xFF0D1116),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Category
              const SizedBox(height: 12),
              _Section(
                title: 'Category',
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  dropdownColor: const Color(0xFF1C1C24),
                  style: const TextStyle(color: Colors.white),
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            children: [
                              if (c.colorInt != null) ...[
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Color(c.colorInt!),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(c.name),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                  hint: const Text(
                    'Choose category',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),

              // Stats (REQUIRED)
              const SizedBox(height: 12),
              _Section(
                title: 'Stats',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_statIds.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'No stats selected (required)',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    if (_statIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _statIds
                              .map(
                                (id) => Chip(
                                  label: Text(
                                    StatRepository.getById(id)?.display ?? id,
                                  ),
                                  labelStyle: const TextStyle(
                                    color: Colors.white,
                                  ),
                                  backgroundColor: Colors.white10,
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () =>
                                      setState(() => _statIds.remove(id)),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.list_alt),
                            label: const Text('Choose'),
                            onPressed: () async {
                              final chosen = await _showStatsChooser(
                                context,
                                _statIds,
                              );
                              if (chosen != null) {
                                setState(() {
                                  _statIds
                                    ..clear()
                                    ..addAll(chosen);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Create new'),
                          onPressed: () async {
                            final created = await showDialog<_NewStatResult>(
                              context: context,
                              builder: (_) => const NewStatDialog(),
                            );
                            if (created != null) {
                              // Register the counter entry so it can accrue; metadata lives in repository/seeders.
                              context.read<ObjectiveProvider>().registerStat(
                                Stat(
                                  id: created.id,
                                  label: created.name,
                                  averageMinutesPerUnit: 1,
                                  repsForMastery: 1,
                                ),
                              );
                              setState(() {
                                if (!_statIds.contains(created.id)) {
                                  _statIds.add(created.id);
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Schedule
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Schedule',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Start + Daily
              Row(
                children: [
                  Expanded(
                    child: _Section(
                      title: 'Start date',
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event),
                        label: Text(_fmtDate(_startDate)),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(now.year - 2),
                            lastDate: DateTime(now.year + 5),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Color(0xFF6C63FF),
                                  surface: Color(0xFF1B1B23),
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setState(() => _startDate = picked);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Section(
                      title: 'Daily',
                      child: Switch(
                        value: _daily && !_useInterval,
                        onChanged: _useInterval
                            ? null
                            : (v) {
                                setState(() {
                                  _daily = v;
                                  for (var i = 1; i <= 7; i++) {
                                    _weekday[i] = v;
                                  }
                                });
                              },
                      ),
                    ),
                  ),
                ],
              ),

              // Weekday chips
              const SizedBox(height: 8),
              Opacity(
                opacity: _useInterval ? 0.4 : 1,
                child: IgnorePointer(
                  ignoring: _useInterval,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (int i = 1; i <= 7; i++)
                        ChoiceChip(
                          selectedColor: accent.withOpacity(0.22),
                          labelStyle: const TextStyle(color: Colors.white),
                          selected: _weekday[i] == true,
                          label: Text(_weekdayLabel(i)),
                          onSelected: (sel) {
                            setState(() {
                              _weekday[i] = sel;
                              _daily = _weekday.values.every((v) => v == true);
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // Interval toggle
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      value: _useInterval,
                      onChanged: (v) =>
                          setState(() => _useInterval = v ?? false),
                      title: const Text(
                        'Repeat every N days',
                        style: TextStyle(color: Colors.white),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),

              // Interval controls
              AnimatedCrossFade(
                crossFadeState: _useInterval
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 180),
                firstChild: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _Section(
                            title: 'Every',
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: _everyNDays > 1
                                      ? () => setState(() => _everyNDays--)
                                      : null,
                                  icon: const Icon(Icons.remove),
                                ),
                                Text(
                                  '$_everyNDays',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _everyNDays++),
                                  icon: const Icon(Icons.add),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'day(s)',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Section(
                            title: 'Anchor date',
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.push_pin_outlined),
                              label: Text(_fmtDate(_anchor)),
                              onPressed: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _anchor,
                                  firstDate: DateTime(now.year - 2),
                                  lastDate: DateTime(now.year + 5),
                                  builder: (ctx, child) => Theme(
                                    data: Theme.of(ctx).copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: Color(0xFF6C63FF),
                                        surface: Color(0xFF1B1B23),
                                      ),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => _anchor = picked);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
              ),

              // Create
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final title = _titleCtrl.text.trim();
                    final xp = int.tryParse(_xpCtrl.text.trim()) ?? 0;
                    final target = int.tryParse(_targetCtrl.text.trim()) ?? 1;
                    final cat = _selectedCategory;

                    // 🔒 Require at least one stat
                    if (_statIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select at least one stat.'),
                        ),
                      );
                      return;
                    }

                    if (title.isEmpty || xp <= 0 || cat == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter title, choose category, and a positive XP.',
                          ),
                        ),
                      );
                      return;
                    }

                    // Build schedule
                    Map<int, bool>? activeDays;
                    int? repeatEveryNDays;
                    DateTime? repeatAnchorDate;

                    if (_useInterval) {
                      repeatEveryNDays = _everyNDays.clamp(1, 365);
                      repeatAnchorDate = _anchor;
                      activeDays = {for (int i = 1; i <= 7; i++) i: true};
                    } else {
                      activeDays = {
                        for (int i = 1; i <= 7; i++)
                          i: (_daily ? true : _weekday[i] == true),
                      };
                    }

                    context.read<ObjectiveProvider>().addObjective(
                      title: title,
                      type: _type,
                      categoryIds: [cat],
                      statIds: _statIds,
                      targetAmount: target,
                      xpReward: xp,
                      startDate: _startDate,
                      activeDays: activeDays,
                      repeatEveryNDays: repeatEveryNDays,
                      repeatAnchorDate: repeatAnchorDate,
                    );

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Objective "$title" created')),
                    );
                  },
                  child: const Text('Create Objective'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<String>?> _showStatsChooser(
    BuildContext context,
    List<String> initially,
  ) {
    final accent = const Color(0xFF6C63FF);
    return showGeneralDialog<List<String>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, minWidth: 320),
            child: _StatsChooserCard(
              initiallySelected: initially,
              accent: accent,
            ),
          ),
        ),
      ),
      transitionBuilder: (_, anim, __, child) =>
          Opacity(opacity: anim.value, child: child),
    );
  }
}

/// ========= Stats chooser & new-stat dialog ==========

class _StatsChooserCard extends StatefulWidget {
  const _StatsChooserCard({
    required this.initiallySelected,
    required this.accent,
  });
  final List<String> initiallySelected;
  final Color accent;

  @override
  State<_StatsChooserCard> createState() => _StatsChooserCardState();
}

class _StatsChooserCardState extends State<_StatsChooserCard> {
  late final Set<String> _selected;

  bool _validMeta(dynamic m) {
    final id = (m.id ?? '').toString().trim();
    final display = (m.display ?? '').toString().trim();
    final cat = (m.categoryId ?? '').toString().trim();
    return id.isNotEmpty && display.isNotEmpty && cat.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    // Keep only valid, known metas in the initial selection
    _selected = {
      for (final id in widget.initiallySelected)
        if (StatRepository.getById(id) != null &&
            _validMeta(StatRepository.getById(id)!))
          id,
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ObjectiveProvider>();

    // User stats → map to metas (only valid)
    final userValidMetas = <dynamic>[];
    final seen = <String>{};
    for (final s in provider.stats.values) {
      final meta = StatRepository.getById(s.id);
      if (meta != null && _validMeta(meta) && !seen.contains(meta.id)) {
        seen.add(meta.id);
        userValidMetas.add(meta);
      }
    }
    userValidMetas.sort(
      (a, b) => a.display.toString().compareTo(b.display.toString()),
    );

    // Catalog (only valid)
    final catalog = StatRepository.getAll().where(_validMeta).toList()
      ..sort((a, b) => a.display.toString().compareTo(b.display.toString()));

    final bg = const Color(0xFF0F1218);
    final border = widget.accent;
    final glow = widget.accent.withAlpha(60);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [BoxShadow(color: glow, blurRadius: 24, spreadRadius: 3)],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Grabber(),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Choose Stats',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 4),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (userValidMetas.isNotEmpty) ...[
                      _sectionTitle('Your stats'),
                      ...userValidMetas.map((m) => _metaTile(m)),
                      const SizedBox(height: 10),
                    ],
                    _sectionTitle('Catalog'),
                    ...catalog.map((m) => _metaTile(m)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selected.toList()),
                    child: const Text('Add selected'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaTile(dynamic meta) {
    final id = meta.id as String;
    final display = meta.display?.toString() ?? id;

    return CheckboxListTile(
      value: _selected.contains(id),
      onChanged: (v) =>
          setState(() => v == true ? _selected.add(id) : _selected.remove(id)),
      // Only show the friendly name
      title: Text(display, style: const TextStyle(color: Colors.white)),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _sectionTitle(String t) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 8),
      child: Text(
        t,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

/// Result for new stat dialog
class _NewStatResult {
  final String id;
  final String name;
  final String categoryId;
  _NewStatResult(this.id, this.name, this.categoryId);
}

class NewStatDialog extends StatefulWidget {
  const NewStatDialog({super.key});

  @override
  State<NewStatDialog> createState() => _NewStatDialogState();
}

class _NewStatDialogState extends State<NewStatDialog> {
  final _nameCtrl = TextEditingController();
  String? _categoryId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _toStatId(String name) {
    final s = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final t = s.replaceAll(RegExp(r'_+'), '_');
    return t.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        context.read<ObjectiveProvider>().categories.values.toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    final previewId = _toStatId(_nameCtrl.text);

    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B23),
      title: const Text('Create Stat', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Beats Made',
              hintStyle: TextStyle(color: Colors.white38),
              labelText: 'Name',
              labelStyle: TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Color(0xFF0D1116),
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _categoryId,
            dropdownColor: const Color(0xFF23232B),
            style: const TextStyle(color: Colors.white),
            items: categories
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setState(() => _categoryId = v),
            decoration: const InputDecoration(
              labelText: 'Category',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(borderSide: BorderSide.none),
              filled: true,
              fillColor: Color(0xFF0D1116),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Stat ID: ${previewId.isEmpty ? '—' : previewId}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            final id = _toStatId(name);
            final cat = _categoryId;

            if (name.isEmpty || id.isEmpty || cat == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enter a name and choose a category.'),
                ),
              );
              return;
            }
            Navigator.pop(context, _NewStatResult(id, name, cat));
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
