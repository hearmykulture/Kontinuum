// lib/ui/widgets/objective/objective_list_item.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/ui/widgets/objective/objective_tokens.dart';
import 'package:kontinuum/ui/widgets/objective/complete_button.dart';
import 'package:kontinuum/ui/widgets/objective/tally_stepper.dart';
import 'package:kontinuum/ui/widgets/objective/stopwatch_sheet.dart';
import 'package:kontinuum/ui/widgets/objective/stat_progress.dart';

import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/data/stat_repository.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/widgets/objective_detail_popup.dart';
import 'package:kontinuum/ui/widgets/xp_gain_bottom_bar.dart' as xpoverlay;

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

  /// Per-stat previous XP cache for bar animation.
  final Map<String, int> _lastXp = {};

  // ---- Helpers for category → label/color/xp (used for XP jump+animate) ----
  String? _primaryCategoryName() {
    if (widget.objective.categoryIds.isEmpty) return null; // -> TOTAL
    return widget.objective.categoryIds.first;
  }

  Color _catColor(String? name) {
    if (name == null) return const Color(0xFFFF4D8D); // TOTAL hot pink
    final c = ObjectiveTokens.categoryColors[name.toUpperCase()];
    return c ?? Colors.grey;
  }

  int _lookupCategoryXp(ObjectiveProvider p, String? categoryName) {
    if (categoryName == null) return p.totalXp;
    final match = p.categories.values.where(
      (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
    );
    if (match.isEmpty) return p.totalXp; // fallback to total if unknown
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

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.objective.isCompleted;

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, __, ___) =>
                ObjectiveDetailPopup(objective: widget.objective),
            opaque: false,
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Hero(
          tag: 'objective_${widget.objective.id}',
          child: Material(
            color: Colors.transparent,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: isCompleted ? 0.6 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCompleted
                        ? Colors.greenAccent.withAlpha(102)
                        : Colors.white12,
                    width: 1,
                  ),
                  boxShadow: [
                    if (isCompleted)
                      BoxShadow(
                        color: Colors.greenAccent.withAlpha(51),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: _buildContent(context),
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
        if (!isLocked && isStopwatch)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              "",
              style: TextStyle(
                color: Colors.white54,
                fontSize: ObjectiveTokens.kMicroSize,
              ),
            ),
          ),
        const SizedBox(height: 10),
        _xpAndStatRow(),
        const SizedBox(height: 6),
        // Category chips FIRST…
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: widget.objective.categoryIds.map(_categoryChip).toList(),
        ),
        // …then mini stat XP bar UNDER the chips.
        if (hasStats) const SizedBox(height: 8),
        if (hasStats) _miniStatXpBar(context),
      ],
    );
  }

  // ---------- Compact, tappable stat XP bar (wrap-aware animation) ----------
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

          // Display level = 1..100 (LevelUtils logic mirrored)
          final level =
              ((maxXp <= 0 ? 0 : (xp / maxXp) * 100)).floor().clamp(0, 99) + 1;

          final step = (maxXp <= 0 ? 1 : (maxXp / 100)).toDouble();
          final lowerBound = ((level - 1) * step);
          final currentWithin = (xp - lowerBound).clamp(0, step).toInt();
          final stepInt = step.toInt();

          final display = meta?.display ?? statId;

          // previous values for animation (must be computed BEFORE we update caches)
          final prevXp = _lastXp[statId] ?? xp;

          // update caches for next build
          _lastXp[statId] = xp;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header line: label + level + index indicator (if many)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$display • Lv $level',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withOpacity(0.9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.objective.statIds.length > 1)
                    const SizedBox(width: 6),
                  if (widget.objective.statIds.length > 1)
                    const Icon(
                      Icons.swap_horiz,
                      size: 12,
                      color: Colors.white38,
                    ),
                  if (widget.objective.statIds.length > 1)
                    Text(
                      ' ${_statIndex + 1}/${widget.objective.statIds.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // Wrap-aware animated progress bar
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withOpacity(0.55),
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

              // Tiny numbers: this-level progress (matches bar)
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
    final bool isTally = _isTally(widget.objective.type);
    final bool isStopwatch = _isStopwatch(widget.objective.type);

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
          (isTally || isStopwatch)
              ? Selector<ObjectiveProvider, int>(
                  selector: (ctx, p) {
                    final list = p.getObjectivesForDay(widget.selectedDate);
                    final idx = list.indexWhere(
                      (o) => o.id == widget.objective.id,
                    );
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
                )
              : Text(
                  "${widget.objective.completedAmount} / ${widget.objective.targetAmount}",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: ObjectiveTokens.kMicroSize,
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
        color: const Color(0xFF2A2A2D),
        borderRadius: BorderRadius.circular(8),
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
            const Tooltip(
              message: '',
              child: Icon(Icons.info_outline, size: 14, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  // Capture BEFORE/AFTER XP, show overlay, dispatch notification
  Widget _standardRow(ObjectiveProvider provider, {required bool showCheck}) {
    final isCompleted = widget.objective.isCompleted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _titleBlock(showAmountLine: widget.objective.targetAmount > 1),
        ),
        if (showCheck) ...[
          const SizedBox(width: 8),
          CompleteButton(
            isCompleted: isCompleted,
            onToggle: () {
              // 1) capture BEFORE xp
              final catName = _primaryCategoryName(); // null => TOTAL
              final before = _lookupCategoryXp(provider, catName);

              // 2) toggle completion (updates provider)
              provider.toggleObjectiveCompletion(
                widget.selectedDate,
                widget.objective.id,
              );

              // 3) after provider rebuild, read AFTER xp and trigger UI
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final after = _lookupCategoryXp(
                  context.read<ObjectiveProvider>(),
                  catName,
                );
                if (after > before) {
                  // a) transient bottom overlay with counting progress
                  xpoverlay.XpGainBottomBar.show(
                    context,
                    label: (catName ?? 'TOTAL').toUpperCase(),
                    fromXp: before,
                    toXp: after,
                    color: _catColor(catName),
                  );
                  // b) notify screen-level listener to jump + animate the persistent bar
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

  /// Reactive tally row
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
              target: widget.objective.targetAmount, // ⬅️ ensure target effects
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
            child: Text(
              "•",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
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
    showModalBottomSheet(
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
          final newAmount = current + m; // allow going over target
          provider.updateObjectiveAmountForDate(
            widget.selectedDate,
            widget.objective.id,
            newAmount,
          );
        },
        onMarkComplete: () {
          // BEFORE XP from parent helpers
          final catName = _primaryCategoryName();
          final before = _lookupCategoryXp(provider, catName);

          if (!widget.objective.isCompleted) {
            provider.toggleObjectiveCompletion(
              widget.selectedDate,
              widget.objective.id,
            );
          }

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
