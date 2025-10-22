// lib/ui/widgets/objective_detail_popup.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/data/stat_repository.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/widgets/objective/objective_tokens.dart';

// ✅ same widgets the cards use
import 'package:kontinuum/ui/widgets/objective/complete_button.dart';
import 'package:kontinuum/ui/widgets/objective/tally_stepper.dart';
import 'package:kontinuum/ui/widgets/objective/stopwatch_sheet.dart';
import 'package:kontinuum/ui/widgets/xp_gain_bottom_bar.dart' as xpoverlay;

class ObjectiveDetailPopup extends StatefulWidget {
  final Objective objective;
  final DateTime selectedDate; // ✅ need date to update per-day state

  const ObjectiveDetailPopup({
    super.key,
    required this.objective,
    required this.selectedDate,
  });

  @override
  State<ObjectiveDetailPopup> createState() => _ObjectiveDetailPopupState();
}

class _ObjectiveDetailPopupState extends State<ObjectiveDetailPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final Animation<double> _bgOpacity; // 0 → 0.6, staged easing
  late final Animation<double> _bgBlur; // 0 → 6, staged easing
  bool _isPopping = false;

  // Match card look
  static const Color _kCardBg = Color(0xFF13151B);

  // Timings
  static const Duration _kFadeIn = Duration(milliseconds: 420);
  static const Duration _kFadeOut = Duration(milliseconds: 520);
  static const Duration _kHeroFlight = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: _kFadeIn,
      reverseDuration: _kFadeOut,
    );

    final curved = CurvedAnimation(
      parent: _bgCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );

    _bgOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.20)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.20, end: 0.60)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
    ]).animate(curved);

    _bgBlur = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 2.0)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 2.0, end: 6.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 65,
      ),
    ]).animate(curved);

    _bgCtrl.forward();
  }

  // ---- helpers (mirrors card logic) ----
  bool _isStopwatch(ObjectiveType t) {
    final s = t.toString().toLowerCase();
    return s.contains('stopwatch') ||
        s.contains('timer') ||
        s.contains('duration');
  }

  bool _isTally(ObjectiveType t) {
    final s = t.toString().toLowerCase();
    return s.contains('tally') || s.contains('counter');
  }

  bool _isWriting(ObjectiveType t) {
    final s = t.toString().toLowerCase();
    return s.contains('write') ||
        s.contains('writing') ||
        s.contains('editor') ||
        s.contains('journal') ||
        s.contains('lyrics') ||
        s.contains('draft') ||
        s.contains('text') ||
        s.contains('note');
  }

  Objective _liveObjective(ObjectiveProvider p) {
    final list = p.getObjectivesForDay(widget.selectedDate);
    final idx = list.indexWhere((o) => o.id == widget.objective.id);
    return idx == -1 ? widget.objective : list[idx];
  }

  String? _primaryCategoryName(Objective o) {
    if (o.categoryIds.isEmpty) return null; // -> TOTAL
    return o.categoryIds.first;
  }

  Color _catColor(String? name) {
    if (name == null) return const Color(0xFFFF4D8D);
    final c = ObjectiveTokens.categoryColors[name.toUpperCase()];
    return c ?? Colors.grey;
  }

  int _lookupCategoryXp(ObjectiveProvider p, String? categoryName) {
    if (categoryName == null) return p.totalXp;
    final match = p.categories.values.where(
      (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
    );
    if (match.isEmpty) return p.totalXp;
    return match.first.xp;
  }

  Color _borderColor(bool isCompleted) {
    return isCompleted
        ? Colors.greenAccent.withAlpha(90)
        : Colors.white.withValues(alpha: .08);
  }

  List<BoxShadow> _shadowFor(bool isCompleted) {
    if (!isCompleted) return const [];
    return [
      BoxShadow(
        color: Colors.greenAccent.withAlpha(40),
        blurRadius: 6,
        spreadRadius: 1,
        offset: const Offset(0, 2),
      ),
    ];
  }

  // Start backdrop reverse now; pop next frame so Hero flies immediately.
  void _popWithHero({VoidCallback? afterFlight}) {
    if (_isPopping) return;
    _isPopping = true;

    _bgCtrl.reverse();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop();

      if (afterFlight != null) {
        Future.delayed(_kHeroFlight, () {
          if (mounted) afterFlight();
        });
      }
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final popupMaxHeight = MediaQuery.of(context).size.height * 0.85;
    final popupMaxWidth = MediaQuery.of(context).size.width * 0.9;

    // 🔁 watch live state so visuals update instantly
    final live = context.select<ObjectiveProvider, Objective>(
      (p) => _liveObjective(p),
    );

    final isStopwatch = _isStopwatch(live.type);
    final isTally = _isTally(live.type);
    final isWriting = _isWriting(live.type);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _popWithHero();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: _popWithHero,
          child: Stack(
            children: [
              // Backdrop
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _bgCtrl,
                  builder: (_, __) => ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: _bgBlur.value,
                        sigmaY: _bgBlur.value,
                      ),
                      child: Container(
                        color: Colors.black.withValues(alpha: _bgOpacity.value),
                      ),
                    ),
                  ),
                ),
              ),

              // Sheet
              Center(
                child: Hero(
                  tag: 'objective_${widget.objective.id}',
                  transitionOnUserGestures: true,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: popupMaxHeight,
                        maxWidth: popupMaxWidth,
                      ),
                      child: SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _kCardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _borderColor(live.isCompleted),
                              width: 1,
                            ),
                            boxShadow: _shadowFor(live.isCompleted),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // --- Title ---
                              Text(
                                live.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // --- XP ---
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.star,
                                      size: 18, color: Colors.amberAccent),
                                  SizedBox(width: 6),
                                ],
                              ),
                              Text(
                                "${live.xpReward} XP",
                                style: const TextStyle(
                                    fontSize: 13.5, color: Colors.amber),
                              ),

                              const SizedBox(height: 12),

                              // --- Tracked stats ---
                              if (live.statIds.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Tracked Stats:',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      live.statIds
                                          .map(StatRepository.getDisplay)
                                          .join(', '),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.lightBlueAccent,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),

                              const SizedBox(height: 16),

                              // --- Categories ---
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                alignment: WrapAlignment.center,
                                children: live.categoryIds.map((id) {
                                  final color =
                                      ObjectiveTokens.categoryColors[id] ??
                                          Colors.white;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.4),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      id,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: 24),

                              // === Actions (type-aware) ===
                              _ActionSection(
                                live: live,
                                selectedDate: widget.selectedDate,
                                onShowXpOverlay:
                                    (context, before, after, label, color) {
                                  if (after > before) {
                                    xpoverlay.XpGainBottomBar.show(
                                      context,
                                      label: label,
                                      fromXp: before,
                                      toXp: after,
                                      color: color,
                                    );
                                  }
                                },
                                helpers: _ActionHelpers(
                                  isStopwatch: isStopwatch,
                                  isTally: _isTally(live.type),
                                  isWriting: _isWriting(live.type),
                                  primaryCategoryName: (o) =>
                                      _primaryCategoryName(o),
                                  catColor: (n) => _catColor(n),
                                  lookupCategoryXp: (p, n) =>
                                      _lookupCategoryXp(p, n),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Close / Delete
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _popWithHero,
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                            color: Colors.white24),
                                      ),
                                      child: const Text('Close'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                      ),
                                      onPressed: () async {
                                        // Capture references BEFORE await to avoid use_build_context_synchronously.
                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        final provider =
                                            context.read<ObjectiveProvider>();
                                        final id = live.id;
                                        final title = live.title;

                                        final ok = await showDialog<bool>(
                                              context: context,
                                              builder: (dialogCtx) =>
                                                  AlertDialog(
                                                backgroundColor:
                                                    const Color(0xFF1E1E1E),
                                                title: const Text(
                                                  'Delete objective?',
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                ),
                                                content: Text(
                                                  '“$title” will be permanently removed.',
                                                  style: const TextStyle(
                                                      color: Colors.white70),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    child: const Text('Cancel',
                                                        style: TextStyle(
                                                            color: Colors
                                                                .white70)),
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            dialogCtx, false),
                                                  ),
                                                  FilledButton(
                                                    style:
                                                        FilledButton.styleFrom(
                                                            backgroundColor:
                                                                Colors
                                                                    .redAccent),
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            dialogCtx, true),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            ) ??
                                            false;
                                        if (!ok || !mounted) return;

                                        // Pop first (Hero flight), then delete.
                                        _popWithHero(afterFlight: () async {
                                          await provider.deleteObjective(id);
                                          messenger.showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'Objective “$title” deleted')),
                                          );
                                        });
                                      },
                                      child: const Text('Delete'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// === Type-aware action section ===
class _ActionSection extends StatelessWidget {
  final Objective live;
  final DateTime selectedDate;
  final void Function(
          BuildContext ctx, int before, int after, String label, Color color)
      onShowXpOverlay;
  final _ActionHelpers helpers;

  const _ActionSection({
    required this.live,
    required this.selectedDate,
    required this.onShowXpOverlay,
    required this.helpers,
  });

  @override
  Widget build(BuildContext context) {
    if (live.isLocked) return const SizedBox.shrink();

    final isStopwatch = helpers.isStopwatch;
    final isTally = helpers.isTally;
    final isWriting = helpers.isWriting;

    final provider = context.read<ObjectiveProvider>();

    // Common handler to toggle completion with XP overlay
    Future<void> toggleComplete() async {
      final catName = helpers.primaryCategoryName(live);
      final before = helpers.lookupCategoryXp(provider, catName);
      provider.toggleObjectiveCompletion(selectedDate, live.id); // ✅ no await
      final after = helpers.lookupCategoryXp(provider, catName);
      onShowXpOverlay(
        context,
        before,
        after,
        (catName ?? 'TOTAL').toUpperCase(),
        helpers.catColor(catName),
      );
    }

    if (isTally) {
      // Live amount watcher so stepper stays in sync
      return Selector<ObjectiveProvider, int>(
        selector: (_, p) {
          final list = p.getObjectivesForDay(selectedDate);
          final idx = list.indexWhere((o) => o.id == live.id);
          if (idx == -1) return 0;
          return list[idx].getCompletedAmount(selectedDate);
        },
        builder: (context, amount, __) {
          return Row(
            children: [
              Expanded(
                child: TallyStepper(
                  amount: amount,
                  min: 0,
                  max: 1 << 31,
                  target: live.targetAmount,
                  rowHeight: ObjectiveTokens.kRowHeight,
                  numberFontSize: ObjectiveTokens.kStepperNumber,
                  radius: 18,
                  onChanged: (next) {
                    final p = context.read<ObjectiveProvider>();
                    p.updateObjectiveAmountForDate(
                        selectedDate, live.id, next); // ✅ no await

                    // Auto-complete on reaching target (guard idx)
                    final list = p.getObjectivesForDay(selectedDate);
                    final idx = list.indexWhere((o) => o.id == live.id);
                    final nowCompleted = (idx != -1) &&
                        (next >= live.targetAmount) &&
                        !list[idx].isCompleted;
                    if (nowCompleted) {
                      toggleComplete();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              _CompleteToggleButton(
                live: live,
                selectedDate: selectedDate, // ✅ pass down instead of ancestor
                onToggle: toggleComplete,
              ),
            ],
          );
        },
      );
    }

    if (isStopwatch) {
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: const Color(0xFF101014),
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  isScrollControlled: true,
                  builder: (_) => StopwatchSheet(
                    targetMinutes: live.targetAmount,
                    onLogMinutes: (m) {
                      final p = context.read<ObjectiveProvider>();
                      // increment amount
                      final list = p.getObjectivesForDay(selectedDate);
                      final idx = list.indexWhere((o) => o.id == live.id);
                      final current = (idx == -1
                          ? 0
                          : list[idx].getCompletedAmount(selectedDate));
                      p.updateObjectiveAmountForDate(
                          selectedDate, live.id, current + m); // ✅ no await
                    },
                    onMarkComplete: () {
                      toggleComplete();
                    },
                  ),
                );
              },
              icon: const Icon(Icons.timer, size: 18),
              label: const Text('Start'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent.withAlpha(46),
                foregroundColor: Colors.deepPurpleAccent,
                minimumSize: const Size(0, ObjectiveTokens.kRowHeight),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _CompleteToggleButton(
            live: live,
            selectedDate: selectedDate, // ✅ pass down
            onToggle: toggleComplete,
          ),
        ],
      );
    }

    // Standard or Writing
    return Align(
      alignment: Alignment.centerRight,
      child: _CompleteToggleButton(
        live: live,
        selectedDate: selectedDate, // ✅ pass down
        onToggle: toggleComplete,
      ),
    );
  }
}

class _CompleteToggleButton extends StatelessWidget {
  final Objective live;
  final DateTime selectedDate; // ✅ remove ancestor lookup
  final Future<void> Function() onToggle;

  const _CompleteToggleButton({
    required this.live,
    required this.selectedDate,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<ObjectiveProvider, bool>(
      selector: (_, p) {
        final list = p.getObjectivesForDay(selectedDate);
        final idx = list.indexWhere((o) => o.id == live.id);
        return (idx == -1 ? live.isCompleted : list[idx].isCompleted);
      },
      builder: (_, isCompleted, __) {
        return SizedBox(
          width: 44,
          height: 44,
          child: CompleteButton(
            isCompleted: isCompleted,
            onToggle: () async => onToggle(),
          ),
        );
      },
    );
  }
}

class _ActionHelpers {
  final bool isStopwatch;
  final bool isTally;
  final bool isWriting;
  final String? Function(Objective) primaryCategoryName;
  final Color Function(String?) catColor;
  final int Function(ObjectiveProvider, String?) lookupCategoryXp;

  const _ActionHelpers({
    required this.isStopwatch,
    required this.isTally,
    required this.isWriting,
    required this.primaryCategoryName,
    required this.catColor,
    required this.lookupCategoryXp,
  });
}
