// lib/ui/screens/missions/mission_board_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Aliased to avoid ambiguous imports if the editor defines similarly named symbols.
import 'package:kontinuum/models/mission.dart' as model;
import 'package:kontinuum/providers/mission_provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/widgets/mission_card.dart';
import 'package:kontinuum/ui/widgets/level_up_watcher.dart';

// For the Home button fallback when this screen isn't on its own route.
import 'package:kontinuum/ui/screens/progress_screen.dart';

// Full-screen mission editor
import 'package:kontinuum/ui/screens/missions/mission_editor_page.dart'
    as editor;
import 'package:kontinuum/core/time/app_clock.dart';

/// Classic switch helper for rarity → color.
Color _rarityColor(model.MissionRarity r) {
  switch (r) {
    case model.MissionRarity.common:
      return Colors.grey;
    case model.MissionRarity.rare:
      return Colors.cyanAccent;
    case model.MissionRarity.legendary:
      return Colors.deepPurpleAccent;
  }
}

// Keep mission surfaces aligned with the Progress screen palette.
const Color _missionBg = kProgressBg;

class MissionBoardScreen extends StatefulWidget {
  const MissionBoardScreen({
    super.key,
    this.isActive = true,
    this.skipIntroAnimation = false,
  });

  /// When embedded inside a PageView, pass `isActive: pageIndex == boardIndex`
  /// so the 1s timer is paused off-screen to avoid jank.
  final bool isActive;
  final bool skipIntroAnimation;

  @override
  State<MissionBoardScreen> createState() => _MissionBoardScreenState();
}

class _MissionBoardScreenState extends State<MissionBoardScreen>
    with SingleTickerProviderStateMixin {
  // Countdown text is isolated so only the title rebuilds every second.
  final ValueNotifier<String> _countdownText =
      ValueNotifier<String>('00:00:00');

  Timer? _timer;
  Duration _timeUntilMidnight = Duration.zero;
  bool _didResetThisMidnight = false;

  // Intro fade (no slide)
  late final AnimationController _introCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    // Longer, more dramatic entrance (no slide).
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      value: widget.skipIntroAnimation ? 1.0 : 0.0,
    );
    _fade = CurvedAnimation(parent: _introCtrl, curve: Curves.easeOutCubic);

    // Warm the provider logic.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final missionProvider = context.read<MissionProvider>();
      final objectiveProvider = context.read<ObjectiveProvider>();

      // ensure XP → level popups while on the board
      missionProvider.attachObjectiveProvider(objectiveProvider);

      await missionProvider.seedIfEmpty();
      await missionProvider.syncWithSeeder();
      missionProvider.ensureMissionSlotsFilled();

      // Slight delay so we definitely start "empty" before fading in.
      if (!widget.skipIntroAnimation) {
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) _introCtrl.forward();
        });
      }

      // Start/stop ticking based on visibility.
      _ensureTimer(widget.isActive, initialKick: true);
    });
  }

  @override
  void didUpdateWidget(covariant MissionBoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _ensureTimer(widget.isActive);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownText.dispose();
    _introCtrl.dispose();
    super.dispose();
  }

  // Start or stop the 1s timer; when (re)starting, tick immediately once.
  void _ensureTimer(bool shouldRun, {bool initialKick = false}) {
    if (!mounted) return;
    if (shouldRun) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      if (initialKick || _countdownText.value == '00:00:00') {
        _tick(); // update immediately so title is fresh
      }
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _tick() async {
    if (!mounted || !widget.isActive) return;

    _updateTimeUntilMidnight();

    // Update only the small title subtree.
    _countdownText.value = _formatDuration(_timeUntilMidnight);

    // Midnight reset logic (kept here so it still runs while active).
    final provider = context.read<MissionProvider>();
    if (!_didResetThisMidnight && _timeUntilMidnight.inSeconds <= 1) {
      await provider.dailyReset();
      _didResetThisMidnight = true;
    } else if (_didResetThisMidnight && _timeUntilMidnight.inSeconds >= 86390) {
      _didResetThisMidnight = false;
    }
  }

  void _updateTimeUntilMidnight() {
    // CST (UTC-5) approximation (keep all math in UTC to avoid tz skew).
    final utcNow = AppClock.now().toUtc();
    final cstNow = utcNow.subtract(const Duration(hours: 5));
    final cstNextMidnight = DateTime.utc(
      cstNow.year,
      cstNow.month,
      cstNow.day,
    ).add(const Duration(days: 1));
    _timeUntilMidnight = cstNextMidnight.difference(cstNow);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  // Open Mission Bank with a quick crossfade.
  void _openBank() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => const MissionBankScreen(),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
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
        MaterialPageRoute<void>(builder: (_) => const ProgressScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // We fade in the whole Scaffold and ignore input until done.
    return Stack(
      children: [
        Container(color: _missionBg), // stays aligned during 0-opacity
        AnimatedBuilder(
          animation: _introCtrl,
          builder: (_, __) {
            final absorbing =
                !widget.skipIntroAnimation && _introCtrl.value < 0.999;
            return AbsorbPointer(
              absorbing: absorbing,
              child: FadeTransition(
                opacity: _fade,
                child: LevelUpWatcher(
                  child: Scaffold(
                    backgroundColor: _missionBg, // board background
                    appBar: AppBar(
                      backgroundColor: _missionBg,
                      centerTitle: true,
                      toolbarHeight: 46,

                      // ⬅️ Mission Bank (leading) — opens instantly (no animation)
                      leading: Transform.translate(
                        offset: const Offset(0, -10),
                        child: _BankButton(
                          onTap: _openBank,
                        ),
                      ),

                      // 🧭 Title — only this tiny part rebuilds every second
                      title: _HeaderTitle(countdownListenable: _countdownText),

                      // ➡️ Home (actions)
                      actions: [
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Transform.translate(
                            offset: const Offset(0, -10),
                            child: IconButton(
                              tooltip: 'Close',
                              iconSize: 20,
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(8),
                              ),
                              icon: const Icon(Icons.close),
                              onPressed: _goHome,
                            ),
                          ),
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
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BankButton extends StatelessWidget {
  const _BankButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        color: _missionBg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.inventory_2_outlined,
                color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

const TextStyle _missionTitleTextStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w500,
  color: Colors.white,
);

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.countdownListenable});

  // Use ValueNotifier directly to avoid needing the foundation import.
  final ValueNotifier<String> countdownListenable;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: countdownListenable,
      builder: (_, countdown, __) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Mission Board",
              overflow: TextOverflow.ellipsis,
              style: _missionTitleTextStyle,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, size: 13, color: Colors.white60),
                const SizedBox(width: 6),
                Text(
                  "Resets in $countdown",
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    letterSpacing: 0.15,
                  ),
                ),
              ],
            ),
          ],
        );
      },
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
                  // Isolate each card’s paint work.
                  return RepaintBoundary(
                    child: MissionCard(mission: missions[index]),
                  );
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
// Mission Bank (kept in this file for convenience) — NO transition.
// =====================================================================

class MissionBankScreen extends StatelessWidget {
  const MissionBankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _missionBg,
      appBar: AppBar(
        backgroundColor: _missionBg,
        centerTitle: true,
        toolbarHeight: 46,
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        leading: Transform.translate(
          offset: const Offset(0, -10),
          child: IconButton(
            iconSize: 20,
            style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(8),
            ),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Transform.translate(
          offset: const Offset(0, -10),
          child: const Text(
            'Mission Bank',
            style: _missionTitleTextStyle,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Transform.translate(
              offset: const Offset(0, -10),
              child: IconButton(
                iconSize: 20,
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(8),
                ),
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
      body: const _AllMissionsTab(),
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
        final activeMissions =
            items.where((m) => !m.isCompleted).toList(growable: false);
        final completedMissions =
            items.where((m) => m.isCompleted).toList(growable: false);
        final orderedMissions = [...activeMissions, ...completedMissions];

        final hasMissions = orderedMissions.isNotEmpty;
        final totalItems = hasMissions ? orderedMissions.length + 1 : 2;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: totalItems,
          itemBuilder: (_, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await provider.debugResetBoardNow();
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Debug: Simulated midnight reset'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Debug: Reset Board (Midnight)'),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      foregroundColor: const Color(0xFF6C63FF),
                      side: BorderSide(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              );
            }

            if (!hasMissions && index == 1) {
              return const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    'No missions in the bank yet.',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              );
            }

            final m = orderedMissions[index - 1];
            final isCompleted = m.isCompleted;
            final color = _rarityColor(m.rarity);
            final cardColor =
                isCompleted ? const Color(0xFF0D2218) : const Color(0xFF2D2B5F);
            final titleColor = isCompleted ? Colors.white70 : Colors.white;
            final rarityColor =
                isCompleted ? color.withValues(alpha: 0.55) : color;
            final xpColor = isCompleted
                ? Colors.cyanAccent.withValues(alpha: 0.55)
                : Colors.cyanAccent;
            final metaColor =
                isCompleted ? Colors.white54 : Colors.white70;
            final acceptedColor = isCompleted
                ? Colors.amberAccent.withValues(alpha: 0.55)
                : Colors.amberAccent;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Dismissible(
                key: ValueKey('mission_${m.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                secondaryBackground: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  final confirmed = await showDialog<bool>(
                        context: ctx,
                        builder: (dialogCtx) {
                          return AlertDialog(
                            backgroundColor: const Color(0xFF1B1B23),
                            title: const Text(
                              'Delete mission?',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: Text(
                              'Delete "${m.title}" from the bank?',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogCtx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(dialogCtx).pop(true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          );
                        },
                      ) ??
                      false;

                  if (!confirmed) return false;
                  provider.deleteMission(m.id);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Deleted "${m.title}"'),
                      ),
                    );
                  }
                  return true;
                },
                child: SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.title,
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            _chip(
                              m.rarity.name.toUpperCase(),
                              border: rarityColor,
                              text: rarityColor,
                            ),
                            _chip(
                              '${m.xpReward} XP',
                              border: xpColor,
                              text: xpColor,
                            ),
                            if (m.categoryIds.isNotEmpty)
                              _chip(
                                m.categoryIds.first.toUpperCase(),
                                border: metaColor.withValues(alpha: 0.3),
                                text: metaColor,
                              ),
                            if (m.categoryIds.length > 1)
                              _chip(
                                '${m.categoryIds.length - 1} more',
                                border: metaColor.withValues(alpha: 0.3),
                                text: metaColor,
                              ),
                            if (m.isCompleted)
                              _chip(
                                'COMPLETED',
                                border: Colors.greenAccent.withValues(alpha: 0.55),
                                text: Colors.greenAccent.withValues(alpha: 0.55),
                              ),
                            if (m.isAccepted)
                              _chip(
                                'ACCEPTED',
                                border: acceptedColor,
                                text: acceptedColor,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
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
