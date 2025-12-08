// lib/ui/widgets/objective/objective_list_item.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:soundpool/soundpool.dart'; // 🔊 stacked chime

import 'package:kontinuum/data/level_utils.dart';
import 'package:kontinuum/ui/widgets/objective/objective_tokens.dart';
import 'package:kontinuum/ui/widgets/objective/complete_button.dart';
import 'package:kontinuum/ui/widgets/objective/tally_stepper.dart';
import 'package:kontinuum/ui/widgets/objective/stopwatch_sheet.dart';
import 'package:kontinuum/ui/widgets/objective/stat_progress.dart';
import 'package:kontinuum/ui/widgets/lottie_once.dart';

import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/data/stat_repository.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/widgets/objective_detail_popup.dart';
import 'package:kontinuum/ui/widgets/xp_gain_bottom_bar.dart' as xpoverlay;

// 🔥 bring back the per-objective streak badge
import 'package:kontinuum/ui/widgets/streak/objective_flame_badge.dart';

// ✅ abstinence mini sheet
import 'package:kontinuum/ui/widgets/objective/abstinence_sheet.dart';

/// ---- Stacking SFX (fire-and-forget; multiple overlaps allowed) -------------
class _Sfx {
  _Sfx._();
  static final _Sfx instance = _Sfx._();

  Soundpool? _pool;
  int? _chimeId;
  bool _loading = false;
  bool _loaded = false;

  void warmup() {
    if (_loaded || _loading) return;
    _loading = true;
    Future<void>(() async {
      try {
        _pool ??= Soundpool.fromOptions(
          options: const SoundpoolOptions(
            streamType: StreamType.notification,
            maxStreams: 8,
          ),
        );
        final data = await rootBundle.load('assets/audio/complete_chime.wav');
        _chimeId = await _pool!.load(data);
        _loaded = true;
      } catch (_) {
      } finally {
        _loading = false;
      }
    });
  }

  void playComplete() {
    try {
      if (!_loaded || _pool == null || _chimeId == null) {
        warmup();
        return;
      }
      _pool!.play(_chimeId!);
    } catch (_) {}
  }
}

/// Objective card background
const Color kObjectiveCardBg = Color(0xFF13151B);
const Color kAbstinenceCardBg = Color(0xFF1B1517);

/// Sent upward to make XpLevelBar jump+animate.
class XpBarJumpNotification extends Notification {
  final String? categoryName; // null => TOTAL
  final int fromXp;
  final int toXp;
  XpBarJumpNotification({
    this.categoryName,
    required this.fromXp,
    required this.toXp,
  });
}

class ObjectiveListItem extends StatefulWidget {
  final Objective objective;
  final DateTime selectedDate;

  const ObjectiveListItem({
    super.key,
    required this.objective,
    required this.selectedDate,
  });

  @override
  State<ObjectiveListItem> createState() => _ObjectiveListItemState();
}

class _ObjectiveListItemState extends State<ObjectiveListItem> {
  int _statIndex = 0;
  final Map<String, int> _lastXp = {};
  bool _confettiVisible = false;
  int _confettiSeed = 0;
  Offset? _confettiOffset;
  final GlobalKey _cardKey = GlobalKey();
  final GlobalKey _confettiOriginKey = GlobalKey();

  /// Previous completion state to detect rising edge.
  bool? _prevCompletedForCheck;

  /// Effects *latch*: set to true only by user-initiated actions on THIS card.
  bool _armCompleteEffects = false;

  static const double _kCheckConfettiSize = 220.0;

  // ---- Helpers: category label/color/xp ----
  String? _primaryCategoryName() {
    if (widget.objective.categoryIds.isEmpty) return null; // -> TOTAL
    return widget.objective.categoryIds.first;
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

  void _playConfettiLocal() {
    final cardBox = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    final originBox =
        _confettiOriginKey.currentContext?.findRenderObject() as RenderBox?;
    Offset? local;
    if (cardBox != null && originBox != null) {
      final originGlobal =
          originBox.localToGlobal(originBox.size.center(Offset.zero));
      final cardOrigin = cardBox.localToGlobal(Offset.zero);
      local = originGlobal - cardOrigin;
    }

    if (local == null) return;

    setState(() {
      _confettiSeed++;
      _confettiOffset = local;
      _confettiVisible = true;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = context.read<ObjectiveProvider>();
    // Seed baseline from the current day's live data.
    _prevCompletedForCheck ??= _liveObjective(p).isCompleted;
    // Warm audio non-blocking.
    WidgetsBinding.instance.addPostFrameCallback((_) => _Sfx.instance.warmup());
  }

  @override
  void didUpdateWidget(covariant ObjectiveListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the day or the bound objective changed, re-baseline and drop the latch.
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.objective.id != widget.objective.id) {
      final p = context.read<ObjectiveProvider>();
      _prevCompletedForCheck = _liveObjective(p).isCompleted;
      _armCompleteEffects = false; // do NOT play effects on rebuilds
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, __, ___) => ObjectiveDetailPopup(
              objective: widget.objective,
              selectedDate: widget.selectedDate,
            ),
            opaque: false,
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Hero(
          tag: 'objective_${widget.objective.id}',
          child: RepaintBoundary(
            child: Material(
              color: Colors.transparent,
              child: Selector<ObjectiveProvider, _CardVisualState>(
                selector: (_, p) {
                  final live = _liveObjective(p);
                  return _CardVisualState(
                    isCompleted: live.isCompleted,
                    isAbstinence: live.isAbstinence,
                  );
                },
                builder: (_, state, __) {
                  final isCompleted = state.isCompleted;
                  final isAbstinence = state.isAbstinence;
                  final EdgeInsets cardMargin = EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: isAbstinence ? 4 : 6,
                  );
                  final EdgeInsets cardPadding = isAbstinence
                      ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                      : const EdgeInsets.all(12);
                  final BorderRadius cardRadius =
                      BorderRadius.circular(isAbstinence ? 10 : 12);
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: isCompleted ? 0.60 : 1.0,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Container(
                          key: _cardKey,
                          margin: cardMargin,
                          padding: cardPadding,
                          decoration: BoxDecoration(
                            color:
                                isAbstinence ? kAbstinenceCardBg : kObjectiveCardBg,
                            borderRadius: cardRadius,
                            border: Border.all(
                              color: isCompleted
                                  ? Colors.greenAccent.withAlpha(90)
                                  : (isAbstinence
                                      ? Colors.redAccent.withAlpha(70)
                                      : Colors.white.withValues(alpha: .08)),
                              width: 1,
                            ),
                            boxShadow: [
                              if (isCompleted)
                                BoxShadow(
                                  color: Colors.greenAccent.withAlpha(40),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: _buildContent(context),
                        ),
                        if (_confettiVisible)
                          Positioned(
                            left: (_confettiOffset?.dx ?? 0) - 80,
                            top: (_confettiOffset?.dy ?? 0) - 80,
                            width: 160,
                            height: 160,
                            child: IgnorePointer(
                              child: LottieOnce(
                                key: ValueKey('confetti_$_confettiSeed'),
                                asset: 'assets/lottie/confetti.json',
                                play: true,
                                repeat: false,
                                onCompleted: () => setState(() {
                                  _confettiVisible = false;
                                }),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final provider = context.read<ObjectiveProvider>();

    // ✅ always work off live instance (day overrides)
    final liveObj = provider
        .getObjectivesForDay(widget.selectedDate)
        .firstWhere((o) => o.id == widget.objective.id, orElse: () {
      return widget.objective;
    });

    final isLocked = liveObj.isLocked;
    final isStopwatch = _isStopwatch(liveObj.type);
    final isTally = _isTally(liveObj.type);
    final isWriting = _isWriting(liveObj.type);
    final isAbstinence = liveObj.isAbstinence; // ✅ unified flag
    final isStandard = !isStopwatch && !isTally && !isWriting && !isAbstinence;

    Widget topRow;
    if (isLocked) {
      topRow = _lockedRow(liveObj);
    } else if (isAbstinence) {
      topRow = _abstinenceRow(provider, liveObj);
    } else if (isTally) {
      topRow = _tallyRow(liveObj);
    } else if (isWriting) {
      topRow = _standardRow(liveObj, provider, showCheck: true);
    } else if (isStopwatch) {
      topRow = _stopwatchRow(context, provider, liveObj);
    } else if (isStandard) {
      topRow = _standardRow(liveObj, provider, showCheck: true);
    } else {
      topRow = _standardRow(liveObj, provider, showCheck: true);
    }

    final hasStats = liveObj.statIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        topRow,
        if (!isLocked && isStopwatch) const SizedBox(height: 4),
        const SizedBox(height: 6),
        _xpAndStatRow(liveObj),
        if (hasStats)
          const SizedBox(height: 6), // ⬅️ tightened to avoid overflow
        if (hasStats) _miniStatXpBar(context, liveObj),
      ],
    );
  }

  // ---------- Compact, tappable stat XP bar ----------
  Widget _miniStatXpBar(BuildContext context, Objective liveObj) {
    final ids = liveObj.statIds;
    if (ids.isEmpty) return const SizedBox.shrink();

    if (_statIndex >= ids.length) _statIndex = 0;
    final statId = ids[_statIndex];

    final cat = StatRepository.getCategoryForStat(statId);
    final color =
        ObjectiveTokens.categoryColors[cat] ?? Colors.deepPurpleAccent;

    return GestureDetector(
      onTap: () {
        if (ids.length <= 1) return;
        HapticFeedback.selectionClick();
        setState(() {
          _statIndex = (_statIndex + 1) % ids.length;
        });
      },
      child: Selector<ObjectiveProvider, Stat?>(
        selector: (_, p) => p.stats[statId],
        builder: (_, stat, __) {
          final meta = StatRepository.getById(statId);

          final xp = stat?.xp ?? 0;
          final maxXp = stat?.maxXp ?? 1;
          final cap = maxXp <= 0 ? 1 : maxXp;

          final lp = LevelUtils.getProgress(xp: xp, maxXp: cap);
          final level = lp.level;
          final levelSpan = lp.levelSpan <= 0 ? 1 : lp.levelSpan;
          final currentWithin = lp.xpIntoLevel.clamp(0, levelSpan).toInt();
          final cappedXp = xp.clamp(0, cap).toInt();

          final display = meta?.display ?? statId;

          final prevXp = _lastXp[statId] ?? xp;
          final prevCapped = prevXp.clamp(0, cap).toInt();
          final currCapped = cappedXp.toInt();
          _lastXp[statId] = currCapped;

          final hasMultipleStats = liveObj.statIds.length > 1;

          Widget statLabel() {
            return SizedBox(
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: hasMultipleStats ? 20 : 0,
                    ),
                    child: Text(
                      '$display • Lv $level',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: .92),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (hasMultipleStats)
                    const Positioned(
                      right: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swap_horiz,
                            size: 12,
                            color: Colors.white38,
                          ),
                          SizedBox(width: 4),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MiniXpNumbers(
                level: level,
                xpIntoLevel: currentWithin,
                levelSpan: levelSpan,
                color: color,
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: .55),
                    width: 0.7,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LevelProgressBar(
                    previousXp: prevCapped,
                    currentXp: currCapped,
                    maxXp: cap,
                    color: color,
                    backgroundColor: const Color(0xFF141622),
                    thickness: 7.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              statLabel(),
            ],
          );
        },
      ),
    );
  }

  Widget _titleBlock({
    required Objective objective,
    required bool showAmountLine,
  }) {
    final hasAmountLine = showAmountLine && objective.targetAmount > 1;
    final hasCategories = objective.categoryIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          objective.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: ObjectiveTokens.kCardTitleSize,
            fontWeight: FontWeight.w400,
            height: 1.2,
          ),
        ),
        if (hasAmountLine) ...[
          const SizedBox(height: 4),
          Selector<ObjectiveProvider, int>(
            selector: (ctx, p) {
              final list = p.getObjectivesForDay(widget.selectedDate);
              final idx = list.indexWhere((o) => o.id == objective.id);
              final obj = idx == -1 ? objective : list[idx];
              return obj.getCompletedAmount(widget.selectedDate);
            },
            builder: (_, amount, __) => Text(
              "$amount / ${objective.targetAmount}",
              style: const TextStyle(
                color: Colors.white54,
                fontSize: ObjectiveTokens.kMicroSize,
              ),
            ),
          ),
        ],
        if (hasCategories) ...[
          SizedBox(height: hasAmountLine ? 6 : 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children:
                objective.categoryIds.map((id) => _categoryChip(id)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _lockedRow(Objective objective) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: kObjectiveCardBg,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.white.withValues(alpha: .10), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  objective.title,
                  style: const TextStyle(
                    fontSize: ObjectiveTokens.kCardTitleSize,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey,
                    height: 1.2,
                  ),
                ),
              ),
              if (objective.lockedReason != null)
                Tooltip(
                  message: objective.lockedReason!,
                  child: const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
          if (objective.categoryIds.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children:
                  objective.categoryIds.map((id) => _categoryChip(id)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // Standard row
  Widget _standardRow(
    Objective objective,
    ObjectiveProvider provider, {
    required bool showCheck,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _titleBlock(
            objective: objective,
            showAmountLine: objective.targetAmount > 1,
          ),
        ),
        const SizedBox(width: 8),
        // 🔥 streak badge lives here
        ObjectiveFlameBadge(objectiveId: objective.id),
        if (showCheck) ...[
          const SizedBox(width: 8),
          Selector<ObjectiveProvider, bool>(
            selector: (_, p) => _liveObjective(p).isCompleted,
            builder: (_, isCompleted, __) {
              final playEffects = _armCompleteEffects &&
                  isCompleted &&
                  (_prevCompletedForCheck == false);

              if (playEffects) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _playConfettiLocal();
                  _Sfx.instance.playComplete();
                  _armCompleteEffects = false; // consume the latch
                });
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _prevCompletedForCheck = isCompleted;
              });

              return SizedBox(
                key: _confettiOriginKey,
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    CompleteButton(
                      isCompleted: isCompleted,
                      onToggle: () {
                        HapticFeedback.selectionClick();
                        _armCompleteEffects = true;

                        final catName = _primaryCategoryName();
                        final before = _lookupCategoryXp(provider, catName);

                        provider.toggleObjectiveCompletion(
                          widget.selectedDate,
                          objective.id,
                        );

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final after = _lookupCategoryXp(
                            context.read<ObjectiveProvider>(),
                            catName,
                          );
                          if (after > before) {
                            xpoverlay.XpGainBottomBar.show(
                              context,
                              label: (catName ?? 'TOTAL').toUpperCase(),
                              fromXp: before,
                              toXp: after,
                              color: _catColor(catName),
                            );
                            XpBarJumpNotification(
                              categoryName: catName,
                              fromXp: before,
                              toXp: after,
                            ).dispatch(context);
                          }
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  // ✅ Abstinence row (only for abstinence objectives now)
  Widget _abstinenceRow(ObjectiveProvider provider, Objective live) {
    final daysClean = provider.getAbstinenceDays(live.id, widget.selectedDate);
    final hasRelapseToday = live.isRelapseOn(widget.selectedDate);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                live.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: ObjectiveTokens.kCardTitleSize,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 5,
                runSpacing: 3,
                children: [
                  ...live.categoryIds.map((id) => _categoryChip(id)),
                  _abstinenceCleanChip(daysClean),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // relapse action
        Tooltip(
          message: hasRelapseToday
              ? 'Relapse already logged today'
              : 'Log relapse for today',
          child: IconButton(
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: hasRelapseToday
                  ? Colors.redAccent.withAlpha(40)
                  : Colors.redAccent.withAlpha(16),
            ),
            onPressed: hasRelapseToday
                ? null
                : () async {
                    HapticFeedback.mediumImpact();
                    await provider.logAbstinenceRelapse(
                      live.id,
                      widget.selectedDate,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Relapse logged for "${live.title}". Streak reset.',
                        ),
                      ),
                    );
                  },
            icon: Icon(
              Icons.restart_alt_rounded,
              color: hasRelapseToday
                  ? Colors.redAccent.withAlpha(180)
                  : Colors.redAccent,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _stopwatchRow(
    BuildContext context,
    ObjectiveProvider provider,
    Objective objective,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _titleBlock(objective: objective, showAmountLine: true),
        ),
        const SizedBox(width: 8),
        // 🔥 keep badge on stopwatch too
        ObjectiveFlameBadge(objectiveId: objective.id),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          height: 40,
          child: Material(
            color: Colors.deepPurpleAccent.withAlpha(46),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.selectionClick();
                _openStopwatchOverlay(context, provider);
              },
              child: const Center(
                child: Icon(Icons.timer, size: 18, color: Colors.deepPurpleAccent),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Reactive tally row
  Widget _tallyRow(Objective objective) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _titleBlock(objective: objective, showAmountLine: true),
        ),
        const SizedBox(width: 8),
        // 🔥 keep badge on tally
        ObjectiveFlameBadge(objectiveId: objective.id),
        const SizedBox(width: 8),
        Selector<ObjectiveProvider, int>(
          selector: (_, p) {
            final list = p.getObjectivesForDay(widget.selectedDate);
            final idx = list.indexWhere((o) => o.id == objective.id);
            if (idx == -1) return 0;
            return list[idx].getCompletedAmount(widget.selectedDate);
          },
          builder: (context, amount, __) {
            return TallyStepper(
              amount: amount,
              min: 0,
              max: 1 << 31,
              target: objective.targetAmount,
              rowHeight: ObjectiveTokens.kRowHeight,
              numberFontSize: ObjectiveTokens.kStepperNumber,
              radius: 18,
              onChanged: (next) {
                final p = context.read<ObjectiveProvider>();

                final oldAmount = amount;
                final crossedNow = oldAmount < objective.targetAmount &&
                    next >= objective.targetAmount;

                final catName = _primaryCategoryName();
                final before = _lookupCategoryXp(p, catName);

                p.updateObjectiveAmountForDate(
                  widget.selectedDate,
                  objective.id,
                  next,
                );

                if (crossedNow) {
                  _armCompleteEffects = true;

                  _playConfettiLocal();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _Sfx.instance.playComplete();
                    _armCompleteEffects = false;
                  });

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final after = _lookupCategoryXp(
                      context.read<ObjectiveProvider>(),
                      catName,
                    );
                    if (after > before) {
                      xpoverlay.XpGainBottomBar.show(
                        context,
                        label: (catName ?? 'TOTAL').toUpperCase(),
                        fromXp: before,
                        toXp: after,
                        color: _catColor(catName),
                      );
                      XpBarJumpNotification(
                        categoryName: catName,
                        fromXp: before,
                        toXp: after,
                      ).dispatch(context);
                    }
                  });
                }
              },
            );
          },
        ),
      ],
    );
  }

  // ---------- Meta rows ----------
  Widget _xpAndStatRow(Objective liveObj) {
    final showXp = !liveObj.isLocked && !liveObj.isAbstinence;
    final showStats = liveObj.statIds.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showXp)
          Row(
            children: const [
              Icon(Icons.star, size: 14, color: Colors.amberAccent),
              SizedBox(width: 4),
            ],
          ),
        if (showXp)
          Text(
            "${liveObj.xpReward} XP",
            style: const TextStyle(
              fontSize: ObjectiveTokens.kMetaSize,
              color: Colors.amber,
            ),
          ),
        if (showXp && showStats)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child:
                Text("•", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        if (showStats)
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.bar_chart, size: 14, color: Colors.lightBlue),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    liveObj.statIds
                        .map((id) => StatRepository.getDisplay(id))
                        .join(', '),
                    style: const TextStyle(
                      fontSize: ObjectiveTokens.kMetaSize,
                      color: Colors.lightBlueAccent,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

// ✅ thinner category pills
Widget _categoryChip(String categoryId) {
  final color = ObjectiveTokens.categoryColors[categoryId] ?? Colors.white;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: color.withAlpha(32),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withAlpha(90), width: 0.5),
      ),
      child: Text(
        categoryId,
        style: TextStyle(
          fontSize: ObjectiveTokens.kBadgeSize - 1,
          color: color,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
    );
  }

Widget _abstinenceCleanChip(int days) {
  const iconColor = Colors.orangeAccent;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: iconColor.withAlpha(32),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: iconColor.withAlpha(90), width: 0.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.local_fire_department, size: 12, color: iconColor),
        const SizedBox(width: 4),
        Text(
          '$days day${days == 1 ? '' : 's'} clean',
          style: const TextStyle(
            fontSize: ObjectiveTokens.kBadgeSize - 1,
            color: iconColor,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ],
    ),
  );
}

  void _openStopwatchOverlay(
    BuildContext context,
    ObjectiveProvider provider,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) {
          return _StopwatchHeroOverlay(
            heroTag: 'objective_${widget.objective.id}',
            child: StopwatchSheet(
              title: widget.objective.title,
              targetMinutes: widget.objective.targetAmount,
              onLogMinutes: (m) {
                final list = provider.getObjectivesForDay(widget.selectedDate);
                final idx = list.indexWhere((o) => o.id == widget.objective.id);
                final live = idx == -1 ? widget.objective : list[idx];
                final current = live.getCompletedAmount(widget.selectedDate);
                final newAmount = current + m;
                provider.updateObjectiveAmountForDate(
                  widget.selectedDate,
                  widget.objective.id,
                  newAmount,
                );
              },
              onMarkComplete: () {
                _armCompleteEffects = true;

                final catName = _primaryCategoryName();
                final before = _lookupCategoryXp(provider, catName);

                final live = _liveObjective(provider);
                if (!live.isCompleted) {
                  provider.toggleObjectiveCompletion(
                    widget.selectedDate,
                    widget.objective.id,
                  );
                }

                _playConfettiLocal();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _Sfx.instance.playComplete();
                  _armCompleteEffects = false;
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final p2 = context.read<ObjectiveProvider>();
                  final after = _lookupCategoryXp(p2, catName);
                  if (after > before) {
                    xpoverlay.XpGainBottomBar.show(
                      context,
                      label: (catName ?? 'TOTAL').toUpperCase(),
                      fromXp: before,
                      toXp: after,
                      color: _catColor(catName),
                    );
                    XpBarJumpNotification(
                      categoryName: catName,
                      fromXp: before,
                      toXp: after,
                    ).dispatch(context);
                  }
                });
              },
            ),
          );
        },
      ),
    );
  }
}

class _StopwatchHeroOverlay extends StatelessWidget {
  final String heroTag;
  final Widget child;

  const _StopwatchHeroOverlay({
    required this.heroTag,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final animation = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final opacity = Curves.easeOutCubic.transform(animation.value);
        return Scaffold(
          backgroundColor: Colors.black.withOpacity(0.55 * opacity),
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const SizedBox.shrink(),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Hero(
                    tag: heroTag,
                    child: Material(
                      color: Colors.transparent,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          decoration: BoxDecoration(
                            color: kObjectiveCardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withValues(alpha: .08)),
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.35),
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardVisualState {
  final bool isCompleted;
  final bool isAbstinence;

  const _CardVisualState({
    required this.isCompleted,
    required this.isAbstinence,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _CardVisualState &&
        other.isCompleted == isCompleted &&
        other.isAbstinence == isAbstinence;
  }

  @override
  int get hashCode => Object.hash(isCompleted, isAbstinence);
}
