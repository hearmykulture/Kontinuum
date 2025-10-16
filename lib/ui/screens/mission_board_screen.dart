// lib/ui/screens/missions/mission_board_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/mission.dart';
import 'package:kontinuum/providers/mission_provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/widgets/mission_card.dart';
import 'package:kontinuum/ui/widgets/level_up_watcher.dart';
import 'package:kontinuum/data/stat_repository.dart';

// For the Home button fallback when this screen isn't on its own route.
import 'package:kontinuum/ui/screens/progress_screen.dart';

const _kBankHeroTag = 'mission_bank_hero_tag';

class MissionBoardScreen extends StatefulWidget {
  const MissionBoardScreen({super.key});

  @override
  State<MissionBoardScreen> createState() => _MissionBoardScreenState();
}

class _MissionBoardScreenState extends State<MissionBoardScreen> {
  // Midnight reset
  late Timer _timer;
  Duration _timeUntilMidnight = Duration.zero;
  bool _didResetThisMidnight = false;

  @override
  void initState() {
    super.initState();
    _updateTimeUntilMidnight();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final missionProvider = context.read<MissionProvider>();
      final objectiveProvider = context.read<ObjectiveProvider>();

      // ensure XP → level popups while on the board
      missionProvider.attachObjectiveProvider(objectiveProvider);

      await missionProvider.seedIfEmpty();
      await missionProvider.syncWithSeeder();
      missionProvider.ensureMissionSlotsFilled();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;

      setState(_updateTimeUntilMidnight);

      final provider = context.read<MissionProvider>();
      if (!_didResetThisMidnight && _timeUntilMidnight.inSeconds <= 1) {
        await provider.dailyReset();
        _didResetThisMidnight = true;
      } else if (_didResetThisMidnight &&
          _timeUntilMidnight.inSeconds >= 86390) {
        _didResetThisMidnight = false;
      }
    });
  }

  void _updateTimeUntilMidnight() {
    // CST (UTC-5)
    final now = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _timeUntilMidnight = nextMidnight.difference(now);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // Keep this for other navigation paths that may still want a normal push.
  void _openBank({int initialTab = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MissionBankScreen(initialTab: initialTab),
      ),
    );
  }

  void _goHome() async {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      // Fallback when this screen is embedded (e.g., inside a PageView)
      await nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ProgressScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LevelUpWatcher(
      child: Scaffold(
        backgroundColor: Colors.black, // ← make board background pure black
        appBar: AppBar(
          backgroundColor: Colors.black,
          centerTitle: true,

          // ⬅️ Mission Bank (leading) — Hero expands into the Bank (All tab)
          leading: const _BankHeroButton(),

          // 🧭 Title
          title: _HeaderTitle(countdown: _formatDuration(_timeUntilMidnight)),

          // ➡️ Home (actions)
          actions: [
            IconButton(
              tooltip: 'Back to Main',
              icon: const Icon(Icons.home_outlined, color: Colors.white70),
              onPressed: _goHome,
            ),
          ],
        ),
        body: const SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          child: _BoardPage(),
        ),
      ),
    );
  }
}

class _BankHeroButton extends StatelessWidget {
  const _BankHeroButton({super.key});

  // The “flying” widget for the Hero. We fade this out near the end of the
  // animation so the Mission Bank content can fade in underneath it.
  static Widget _bankFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    const bankBg = Color(0xFF0F0F1A);

    // Fade the shuttle only at the *end* of push (and the *start* of pop).
    final fade = direction == HeroFlightDirection.push
        ? Tween<double>(begin: 1, end: 0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.75, 1.0, curve: Curves.easeOutCubic),
            ),
          )
        : Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.25, curve: Curves.easeInCubic),
            ),
          );

    return FadeTransition(
      opacity: fade,
      child: const Material(
        color: bankBg,
        // Keep circular visual while small; it’ll scale to full-screen as the
        // rect tween runs. (No shadow/elevation for a cleaner look.)
        shape: CircleBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bankBg = Color(0xFF0F0F1A); // Destination background
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Hero(
        tag: _kBankHeroTag,
        createRectTween: (begin, end) =>
            MaterialRectArcTween(begin: begin, end: end),
        flightShuttleBuilder: _bankFlightShuttle,
        child: Material(
          color: bankBg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 460),
                  reverseTransitionDuration: const Duration(milliseconds: 360),
                  pageBuilder: (_, __, ___) =>
                      const MissionBankScreen(initialTab: 0),
                  // Delay the page’s opacity so it appears *under* the hero
                  // shuttle right as the shuttle fades away.
                  transitionsBuilder: (_, anim, __, child) => FadeTransition(
                    opacity: CurvedAnimation(
                      parent: anim,
                      curve: const Interval(
                        0.30,
                        1.0,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: child,
                  ),
                ),
              );
            },
            child: const SizedBox(
              width: 40,
              height: 40,
              // crate/locker icon reads as "bank/storage"
              child: Icon(Icons.inventory_2_outlined, color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.countdown});
  final String countdown;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Mission Board",
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, size: 15, color: Colors.white60),
            const SizedBox(width: 6),
            Text(
              "Resets in $countdown",
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Active Missions Grid
/// ---------------------------------------------------------------------------
class _BoardPage extends StatelessWidget {
  const _BoardPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Consumer<MissionProvider>(
        builder: (context, provider, _) {
          final missions = provider.getVisibleMissionSlots();

          if (missions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.inbox_outlined,
                    color: Colors.white30,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "No missions to show (yet).",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      await provider.seedIfEmpty();
                      await provider.syncWithSeeder();
                      provider.ensureMissionSlotsFilled();
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text("Fill Board"),
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (ctx, constraints) {
              const crossAxisCount = 2;
              const rows = 4;
              const spacing = 10.0;

              final availableWidth = constraints.maxWidth;
              final availableHeight = constraints.maxHeight;

              final itemWidth =
                  (availableWidth - spacing * (crossAxisCount - 1)) /
                  crossAxisCount;
              final itemHeight =
                  (availableHeight - spacing * (rows - 1)) / rows;

              final aspectRatio = itemWidth / itemHeight;

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: missions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: aspectRatio,
                ),
                itemBuilder: (context, index) {
                  return MissionCard(mission: missions[index]);
                },
              );
            },
          );
        },
      ),
    );
  }
}

// =====================================================================
// Mission Bank (in this file for convenience)
// =====================================================================

class MissionBankScreen extends StatelessWidget {
  const MissionBankScreen({super.key, this.initialTab = 0});

  /// 0 = All, 1 = Completed
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text(
            'Mission Bank',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFF6C63FF),
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Completed'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Add mission',
              icon: const Icon(Icons.add),
              onPressed: () async {
                final created = await showDialog<Mission>(
                  context: context,
                  builder: (_) => const _NewMissionDialog(),
                );
                if (created != null && context.mounted) {
                  context.read<MissionProvider>().addMission(created);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mission added')),
                  );
                }
              },
            ),
          ],
        ),
        body: Stack(
          children: const [
            // Destination of the hero flight — full-screen bank background.
            _BankHeroTarget(),
            // Actual content on top.
            TabBarView(children: [_AllMissionsTab(), _CompletedMissionsTab()]),
          ],
        ),
      ),
    );
  }
}

class _BankHeroTarget extends StatelessWidget {
  const _BankHeroTarget({super.key});

  @override
  Widget build(BuildContext context) {
    const bankBg = Color(0xFF0F0F1A);
    return IgnorePointer(
      child: Hero(
        tag: _kBankHeroTag,
        createRectTween: (begin, end) =>
            MaterialRectArcTween(begin: begin, end: end),
        child: const SizedBox.expand(child: ColoredBox(color: bankBg)),
      ),
    );
  }
}

// --------------------------- All missions ---------------------------

class _AllMissionsTab extends StatelessWidget {
  const _AllMissionsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<MissionProvider>(
      builder: (ctx, provider, _) {
        final items = provider.allMissionsSorted;
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No missions in the bank yet.',
              style: TextStyle(color: Colors.white60),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Colors.white10),
          itemBuilder: (_, i) {
            final m = items[i];
            final color = _rarityColor(m.rarity);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(
                m.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(
                      m.rarity.name.toUpperCase(),
                      border: color,
                      text: color,
                    ),
                    _chip(
                      '${m.xpReward} XP',
                      border: Colors.cyanAccent,
                      text: Colors.cyanAccent,
                    ),
                    if (m.categoryIds.isNotEmpty)
                      _chip(
                        m.categoryIds.first.toUpperCase(),
                        border: Colors.white24,
                        text: Colors.white70,
                      ),
                    if (m.isCompleted)
                      _chip(
                        'COMPLETED',
                        border: Colors.greenAccent,
                        text: Colors.greenAccent,
                      ),
                    if (m.isAccepted)
                      _chip(
                        'ACCEPTED',
                        border: Colors.amberAccent,
                        text: Colors.amberAccent,
                      ),
                  ],
                ),
              ),
              // ⛔️ No "Put on board" — keep only Delete
              trailing: IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => provider.deleteMission(m.id),
              ),
            );
          },
        );
      },
    );
  }

  Color _rarityColor(MissionRarity r) => switch (r) {
    MissionRarity.common => Colors.grey,
    MissionRarity.rare => Colors.cyanAccent,
    MissionRarity.legendary => Colors.deepPurpleAccent,
  };

  Widget _chip(String label, {required Color border, required Color text}) {
    Color alpha(Color c, double o) => c.withAlpha((o * 255).round());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: alpha(border, 0.6)),
        color: alpha(border, 0.09),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ------------------------- Completed missions -------------------------

class _CompletedMissionsTab extends StatelessWidget {
  const _CompletedMissionsTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MissionProvider>();
    final completed = provider.completedMissions;

    return Column(
      children: [
        // 🧪 Temporary debug control — performs EXACT midnight reset
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () async {
                await provider
                    .debugResetBoardNow(); // identical to midnight reset
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Debug: Simulated midnight reset'),
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Debug: Reset Board (Midnight)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6C63FF),
                side: BorderSide(
                  color: const Color(0xFF6C63FF).withOpacity(0.6),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: completed.isEmpty
              ? const Center(
                  child: Text(
                    'Nothing completed yet.',
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: completed.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (_, i) {
                    final m = completed[i];
                    final color = switch (m.rarity) {
                      MissionRarity.common => Colors.grey,
                      MissionRarity.rare => Colors.cyanAccent,
                      MissionRarity.legendary => Colors.deepPurpleAccent,
                    };

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(
                        m.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _chip(
                              m.rarity.name.toUpperCase(),
                              border: color,
                              text: color,
                            ),
                            _chip(
                              '${m.xpReward} XP',
                              border: Colors.cyanAccent,
                              text: Colors.cyanAccent,
                            ),
                            if (m.categoryIds.isNotEmpty)
                              _chip(
                                m.categoryIds.first.toUpperCase(),
                                border: Colors.white24,
                                text: Colors.white70,
                              ),
                          ],
                        ),
                      ),
                      // ⛔️ No "Reopen" (can’t put back on board)
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => provider.deleteMission(m.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, {required Color border, required Color text}) {
    Color alpha(Color c, double o) => c.withAlpha((o * 255).round());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: alpha(border, 0.6)),
        color: alpha(border, 0.09),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ------------------------- New mission dialog -------------------------

class _NewMissionDialog extends StatefulWidget {
  const _NewMissionDialog();

  @override
  State<_NewMissionDialog> createState() => _NewMissionDialogState();
}

class _NewMissionDialogState extends State<_NewMissionDialog> {
  final _titleCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _xpCtrl = TextEditingController(text: '100');

  String? _categoryId;
  String? _statId;
  MissionRarity _rarity = MissionRarity.common;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _idCtrl.dispose();
    _descCtrl.dispose();
    _xpCtrl.dispose();
    super.dispose();
  }

  String _toIdSlug(String s) {
    final x = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return x.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  }

  bool _validMeta(dynamic m) {
    final id = (m.id ?? '').toString().trim();
    final display = (m.display ?? '').toString().trim();
    final cat = (m.categoryId ?? '').toString().trim();
    return id.isNotEmpty && display.isNotEmpty && cat.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final missionProvider = context.read<MissionProvider>();
    final objectiveProvider = context.read<ObjectiveProvider>();

    final categories = objectiveProvider.categories.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final statMetas = StatRepository.getAll().where(_validMeta).toList()
      ..sort((a, b) => a.display.toString().compareTo(b.display.toString()));

    final previewId = (_idCtrl.text.isEmpty
        ? _toIdSlug(_titleCtrl.text)
        : _idCtrl.text);

    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B23),
      title: const Text('New Mission', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'Write 10 metaphors or punchlines',
                hintStyle: TextStyle(color: Colors.white38),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFF0D1116),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _idCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'ID (optional)',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: previewId,
                hintStyle: const TextStyle(color: Colors.white38),
                border: const OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: const Color(0xFF0D1116),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFF0D1116),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _categoryId,
              dropdownColor: const Color(0xFF23232B),
              style: const TextStyle(color: Colors.white),
              items: categories
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  )
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
            DropdownButtonFormField<String>(
              value: _statId,
              dropdownColor: const Color(0xFF23232B),
              style: const TextStyle(color: Colors.white),
              items: statMetas
                  .map(
                    (m) => DropdownMenuItem(
                      value: m.id.toString(),
                      child: Text(m.display.toString()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _statId = v),
              decoration: const InputDecoration(
                labelText: 'Stat',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFF0D1116),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _xpCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'XP Reward',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFF0D1116),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<MissionRarity>(
              value: _rarity,
              dropdownColor: const Color(0xFF23232B),
              style: const TextStyle(color: Colors.white),
              items: MissionRarity.values
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(
                        r.name[0].toUpperCase() + r.name.substring(1),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _rarity = v ?? _rarity),
              decoration: const InputDecoration(
                labelText: 'Rarity',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                filled: true,
                fillColor: Color(0xFF0D1116),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Final ID: ${previewId.isEmpty ? '—' : previewId}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final missionProvider = context.read<MissionProvider>();

            final title = _titleCtrl.text.trim();
            final id = (_idCtrl.text.trim().isEmpty)
                ? _toIdSlug(title)
                : _idCtrl.text.trim();
            final xp = int.tryParse(_xpCtrl.text.trim()) ?? 0;

            if (title.isEmpty ||
                id.isEmpty ||
                xp <= 0 ||
                _categoryId == null ||
                _statId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Fill title, ID, category, stat and positive XP.',
                  ),
                ),
              );
              return;
            }

            // Prevent duplicate IDs
            final exists = missionProvider.allMissionsSorted.any(
              (m) => m.id.toLowerCase() == id.toLowerCase(),
            );
            if (exists) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ID already exists. Pick another.'),
                ),
              );
              return;
            }

            final mission = Mission(
              id: id,
              title: title,
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              categoryIds: [_categoryId!],
              statIds: [_statId!],
              xpReward: xp,
              rarity: _rarity,
              isAccepted: false,
              isCompleted: false,
            );

            Navigator.pop(context, mission);
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
