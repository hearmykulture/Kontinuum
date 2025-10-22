// lib/ui/widgets/objective/objective_list_item.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:soundpool/soundpool.dart'; // 🔊 stacked chime

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

  void _showConfettiOverlay(BuildContext context) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: Positioned.fill(
          child: Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: LottieOnce(
                asset: 'assets/lottie/confetti.json',
                play: true,
                repeat: false,
                onCompleted: () => entry.remove(),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
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
              child: Selector<ObjectiveProvider, bool>(
                selector: (_, p) => _liveObjective(p).isCompleted,
                builder: (_, isCompleted, __) {
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: isCompleted ? 0.60 : 1.0,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kObjectiveCardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCompleted
                              ? Colors.greenAccent.withAlpha(90)
                              : Colors.white.withValues(alpha: .08),
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

    final isLocked = widget.objective.isLocked;
    final isStopwatch = _isStopwatch(widget.objective.type);
    final isTally = _isTally(widget.objective.type);
    final isWriting = _isWriting(widget.objective.type);
    final isStandard = !isStopwatch && !isTally && !isWriting;

    Widget topRow;
    if (isLocked) {
      topRow = _lockedRow();
    } else if (isTally) {
      topRow = _tallyRow();
    } else if (isWriting) {
      topRow = _standardRow(provider, showCheck: true);
    } else if (isStopwatch) {
      topRow = _stopwatchRow(context, provider);
    } else if (isStandard) {
      topRow = _standardRow(provider, showCheck: true);
    } else {
      topRow = _standardRow(provider, showCheck: true);
    }

    final hasStats = widget.objective.statIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        topRow,
        if (!isLocked && isStopwatch) const SizedBox(height: 4),
        const SizedBox(height: 10),
        _xpAndStatRow(),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: widget.objective.categoryIds.map(_categoryChip).toList(),
        ),
        if (hasStats) const SizedBox(height: 8),
        if (hasStats) _miniStatXpBar(context),
      ],
    );
  }

  // ---------- Compact, tappable stat XP bar ----------
  Widget _miniStatXpBar(BuildContext context) {
    final ids = widget.objective.statIds;
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
          final maxXp = stat?.maxXp ?? 100;

          final level =
              (maxXp <= 0 ? 0 : (xp / maxXp) * 100).floor().clamp(0, 99) + 1;

          final double step = (maxXp <= 0 ? 1.0 : maxXp / 100.0);
          final double lowerBound = (level - 1) * step;
          final int currentWithin = (xp - lowerBound).clamp(0.0, step).round();
          final int stepInt = step.round();

          final display = meta?.display ?? statId;

          final prevXp = _lastXp[statId] ?? xp;
          _lastXp[statId] = xp;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$display • Lv $level',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: .92),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.objective.statIds.length > 1)
                    const SizedBox(width: 6),
                  if (widget.objective.statIds.length > 1)
                    const Icon(Icons.swap_horiz,
                        size: 12, color: Colors.white38),
                  if (widget.objective.statIds.length > 1)
                    const Text('  ', style: TextStyle(fontSize: 10)),
                ],
              ),
              const SizedBox(height: 4),
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
                    previousXp: prevXp,
                    currentXp: xp,
                    maxXp: maxXp,
                    color: color,
                    backgroundColor: const Color(0xFF141622),
                    thickness: 7.5,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              MiniXpNumbers(
                level: level,
                step: stepInt,
                currentWithin: currentWithin,
                totalMaxXp: maxXp,
                color: color,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _titleBlock({required bool showAmountLine}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.objective.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: ObjectiveTokens.kCardTitleSize,
            fontWeight: FontWeight.w400,
            height: 1.2,
          ),
        ),
        if (showAmountLine && widget.objective.targetAmount > 1) ...[
          const SizedBox(height: 4),
          Selector<ObjectiveProvider, int>(
            selector: (ctx, p) {
              final list = p.getObjectivesForDay(widget.selectedDate);
              final idx = list.indexWhere((o) => o.id == widget.objective.id);
              final obj = idx == -1 ? widget.objective : list[idx];
              return obj.getCompletedAmount(widget.selectedDate);
            },
            builder: (_, amount, __) => Text(
              "$amount / ${widget.objective.targetAmount}",
              style: const TextStyle(
                color: Colors.white54,
                fontSize: ObjectiveTokens.kMicroSize,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _lockedRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: kObjectiveCardBg,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.white.withValues(alpha: .10), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.objective.title,
              style: const TextStyle(
                fontSize: ObjectiveTokens.kCardTitleSize,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
                height: 1.2,
              ),
            ),
          ),
          if (widget.objective.lockedReason != null)
            Tooltip(
              message: widget.objective.lockedReason!,
              child:
                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  // Standard row (anchored confetti + SFX ONLY on user-initiated rising edge)
  Widget _standardRow(ObjectiveProvider provider, {required bool showCheck}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _titleBlock(showAmountLine: widget.objective.targetAmount > 1),
        ),
        if (showCheck) ...[
          const SizedBox(width: 8),
          Selector<ObjectiveProvider, bool>(
            selector: (_, p) => _liveObjective(p).isCompleted,
            builder: (_, isCompleted, __) {
              // Fire effects ONLY when:
              // 1) completion just turned true (rising edge), AND
              // 2) the user armed this card (they tapped the check).
              final playEffects = _armCompleteEffects &&
                  isCompleted &&
                  (_prevCompletedForCheck == false);

              if (playEffects) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _Sfx.instance.playComplete();
                  _armCompleteEffects = false; // consume the latch
                });
              }

              // Always re-baseline after the frame
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _prevCompletedForCheck = isCompleted;
              });

              return SizedBox(
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

                        // Arm effects for THIS user action
                        _armCompleteEffects = true;

                        final catName = _primaryCategoryName(); // null => TOTAL
                        final before = _lookupCategoryXp(provider, catName);

                        provider.toggleObjectiveCompletion(
                          widget.selectedDate,
                          widget.objective.id,
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

                    // 🎉 Anchored confetti plays only when playEffects == true
                    Positioned.fill(
                      child: IgnorePointer(
                        child: OverflowBox(
                          minWidth: 0,
                          minHeight: 0,
                          maxWidth: _kCheckConfettiSize,
                          maxHeight: _kCheckConfettiSize,
                          child: Center(
                            child: SizedBox(
                              width: _kCheckConfettiSize,
                              height: _kCheckConfettiSize,
                              child: LottieOnce(
                                asset: 'assets/lottie/confetti.json',
                                play: playEffects,
                                repeat: false,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
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

  Widget _stopwatchRow(BuildContext context, ObjectiveProvider provider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _titleBlock(showAmountLine: true)),
        const SizedBox(width: 8),
        SizedBox(
          height: ObjectiveTokens.kRowHeight,
          child: FilledButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              _openStopwatchSheet(context, provider);
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              backgroundColor: Colors.deepPurpleAccent.withAlpha(46),
              foregroundColor: Colors.deepPurpleAccent,
              minimumSize: const Size(0, ObjectiveTokens.kRowHeight),
            ),
            icon: const Icon(Icons.timer, size: 18),
            label: const Text('Start', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  /// Reactive tally row (only plays when YOU increment to target)
  Widget _tallyRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _titleBlock(showAmountLine: true)),
        const SizedBox(width: 8),
        Selector<ObjectiveProvider, int>(
          selector: (_, p) {
            final list = p.getObjectivesForDay(widget.selectedDate);
            final idx = list.indexWhere((o) => o.id == widget.objective.id);
            if (idx == -1) return 0;
            return list[idx].getCompletedAmount(widget.selectedDate);
          },
          builder: (context, amount, __) {
            return TallyStepper(
              amount: amount,
              min: 0,
              max: 1 << 31,
              target: widget.objective.targetAmount,
              rowHeight: ObjectiveTokens.kRowHeight,
              numberFontSize: ObjectiveTokens.kStepperNumber,
              radius: 18,
              onChanged: (next) {
                final p = context.read<ObjectiveProvider>();
                p.updateObjectiveAmountForDate(
                  widget.selectedDate,
                  widget.objective.id,
                  next,
                );

                // Only when the user *just* reached target, mark complete + effects.
                final live = _liveObjective(p);
                final reached = next >= widget.objective.targetAmount;
                if (reached && !live.isCompleted) {
                  _armCompleteEffects = true; // arm for this user action

                  final catName = _primaryCategoryName();
                  final before = _lookupCategoryXp(p, catName);

                  p.toggleObjectiveCompletion(
                    widget.selectedDate,
                    widget.objective.id,
                  );

                  // Center confetti + stacked chime (immediate, not via builder)
                  _showConfettiOverlay(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _Sfx.instance.playComplete();
                    _armCompleteEffects = false; // consume latch
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
  Widget _xpAndStatRow() {
    final showXp = !widget.objective.isLocked;
    final showStats = widget.objective.statIds.isNotEmpty;

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
            "${widget.objective.xpReward} XP",
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
                    widget.objective.statIds
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

  Widget _categoryChip(String categoryId) {
    final color = ObjectiveTokens.categoryColors[categoryId] ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(102), width: 0.5),
      ),
      child: Text(
        categoryId,
        style: TextStyle(
          fontSize: ObjectiveTokens.kBadgeSize,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _openStopwatchSheet(BuildContext context, ObjectiveProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101014),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (_) => StopwatchSheet(
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
          // Arm for this user intent.
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

          // Immediate effects here (not via builder)
          _showConfettiOverlay(context);
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
  }
}
