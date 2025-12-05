// lib/ui/screens/objective_organization_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/screens/progress_screen.dart'
    show kProgressBg, AppPalette;

/// Independent screen to organize objectives for a given day.
/// - tap category pill ⇒ expand/collapse
/// - hold the little drag icon ⇒ reorder categories
/// - long-press objective ⇒ drag
/// - drop BETWEEN objectives to reorder inside a category
/// - drop ON a category (even when collapsed) to move there
class ObjectiveOrganizationScreen extends StatelessWidget {
  const ObjectiveOrganizationScreen({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ObjectiveProvider>();
    final objectives = provider.getObjectivesForDay(day);

    // group by FIRST category id
    final Map<String, List<Objective>> groupedByCategory = {};
    for (final obj in objectives) {
      final category =
          obj.categoryIds.isNotEmpty ? obj.categoryIds.first : 'Uncategorized';
      groupedByCategory.putIfAbsent(category, () => []).add(obj);
    }

    final orderedCats = groupedByCategory.keys.toList()
      ..sort((a, b) {
        if (a == 'Uncategorized' && b == 'Uncategorized') return 0;
        if (a == 'Uncategorized') return 1;
        if (b == 'Uncategorized') return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    return Scaffold(
      backgroundColor: kProgressBg,
      appBar: AppBar(
        backgroundColor: kProgressBg,
        elevation: 0,
        title: const Text(
          'Organize Objectives',
          style: TextStyle(color: AppPalette.onSurface),
        ),
        iconTheme: const IconThemeData(color: AppPalette.onSurface),
      ),
      body: _OrganizerBody(
        day: day,
        initialCategories: orderedCats,
        initialGrouped: groupedByCategory,
      ),
    );
  }
}

/// internal UI model so we can reorder without touching provider
class _OrgCategoryData {
  final String id;
  final List<Objective> items;
  bool expanded;

  _OrgCategoryData({
    required this.id,
    required this.items,
    this.expanded = true,
  });
}

class _OrganizerBody extends StatefulWidget {
  const _OrganizerBody({
    required this.day,
    required this.initialCategories,
    required this.initialGrouped,
  });

  final DateTime day;
  final List<String> initialCategories;
  final Map<String, List<Objective>> initialGrouped;

  @override
  State<_OrganizerBody> createState() => _OrganizerBodyState();
}

class _OrganizerBodyState extends State<_OrganizerBody> {
  late List<_OrgCategoryData> _cats;

  @override
  void initState() {
    super.initState();
    _cats = widget.initialCategories
        .map(
          (c) => _OrgCategoryData(
            id: c,
            items: List<Objective>.from(widget.initialGrouped[c] ?? const []),
            expanded: true,
          ),
        )
        .toList();
  }

  void _toggleExpanded(String categoryId) {
    setState(() {
      final c = _cats.firstWhere((e) => e.id == categoryId);
      c.expanded = !c.expanded;
    });
  }

  void _reorderCategory(String draggedId, String targetId) {
    setState(() {
      final from = _cats.indexWhere((e) => e.id == draggedId);
      final to = _cats.indexWhere((e) => e.id == targetId);
      if (from == -1 || to == -1 || from == to) return;
      final item = _cats.removeAt(from);
      _cats.insert(to, item);
    });
  }

  // generic move (within cat, or to another cat, with index)
  void _moveObjective({
    required String fromCategory,
    required String toCategory,
    required Objective obj,
    int? toIndex,
  }) {
    setState(() {
      final fromCat = _cats.firstWhere((e) => e.id == fromCategory);
      final toCat = _cats.firstWhere((e) => e.id == toCategory);
      final idx = fromCat.items.indexWhere((o) => o.id == obj.id);
      if (idx == -1) return;
      final removed = fromCat.items.removeAt(idx);

      if (toIndex == null || toIndex < 0 || toIndex > toCat.items.length) {
        toCat.items.add(removed);
      } else {
        toCat.items.insert(toIndex, removed);
      }
      // make sure user sees it
      toCat.expanded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // legend / instructions
        Container(
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x1219273A),
            border: Border.all(
              color: Colors.white.withValues(alpha: .03),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _legendDot(Colors.cyanAccent),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Tap pill = open/close · Hold drag icon = move category · Hold objective = drag · Drop between bars to reorder',
                  style: TextStyle(
                    fontSize: 11.2,
                    color: Colors.white70,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 78, top: 2),
            itemCount: _cats.length,
            itemBuilder: (context, index) {
              final cat = _cats[index];
              return _OrganizeCategorySection(
                key: ValueKey('org_${cat.id}'),
                data: cat,
                day: widget.day,
                onToggle: _toggleExpanded,
                onReorderCategory: _reorderCategory,
                onMoveObjective: _moveObjective,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color c) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _DraggedObjectivePayload {
  final Objective objective;
  final String fromCategory;
  final DateTime day;
  const _DraggedObjectivePayload({
    required this.objective,
    required this.fromCategory,
    required this.day,
  });
}

class _DraggedCategoryPayload {
  final String categoryId;
  const _DraggedCategoryPayload(this.categoryId);
}

class _OrganizeCategorySection extends StatefulWidget {
  const _OrganizeCategorySection({
    super.key,
    required this.data,
    required this.day,
    required this.onToggle,
    required this.onReorderCategory,
    required this.onMoveObjective,
  });

  final _OrgCategoryData data;
  final DateTime day;

  final void Function(String categoryId) onToggle;
  final void Function(String draggedId, String targetId) onReorderCategory;
  final void Function({
    required String fromCategory,
    required String toCategory,
    required Objective obj,
    int? toIndex,
  }) onMoveObjective;

  @override
  State<_OrganizeCategorySection> createState() =>
      _OrganizeCategorySectionState();
}

class _OrganizeCategorySectionState extends State<_OrganizeCategorySection>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      value: widget.data.expanded ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant _OrganizeCategorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.expanded != widget.data.expanded) {
      _ctrl.animateTo(widget.data.expanded ? 1.0 : 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() => widget.onToggle(widget.data.id);

  @override
  Widget build(BuildContext context) {
    final isUncategorized = widget.data.id == 'Uncategorized';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // header: tap = expand, right-handle = drag
          DragTarget<_DraggedCategoryPayload>(
            onWillAcceptWithDetails: (details) =>
                details.data.categoryId != widget.data.id,
            onAcceptWithDetails: (details) {
              widget.onReorderCategory(details.data.categoryId, widget.data.id);
            },
            builder: (context, cand, rej) {
              final hover = cand.isNotEmpty;
              return _CategoryPill(
                label: "${widget.data.id} (${widget.data.items.length})",
                expanded: widget.data.expanded,
                isUncategorized: isUncategorized,
                hover: hover,
                onTap: _toggle,
                dragHandle: LongPressDraggable<_DraggedCategoryPayload>(
                  data: _DraggedCategoryPayload(widget.data.id),
                  feedback: Material(
                    color: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: _CategoryPill(
                        label:
                            "${widget.data.id} (${widget.data.items.length})",
                        expanded: widget.data.expanded,
                        isUncategorized: isUncategorized,
                        hover: true,
                        onTap: () {},
                        dragHandle: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: Icon(
                      Icons.drag_indicator,
                      size: 18,
                      color: Colors.white60,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          // outer drop target so we can drop even when collapsed
          DragTarget<_DraggedObjectivePayload>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) {
              widget.onMoveObjective(
                fromCategory: details.data.fromCategory,
                toCategory: widget.data.id,
                obj: details.data.objective,
                toIndex: 0,
              );
            },
            builder: (context, cand, rej) {
              return SizeTransition(
                sizeFactor: CurvedAnimation(
                  parent: _ctrl,
                  curve: Curves.easeOutCubic,
                ),
                axisAlignment: 1.0,
                child: _buildObjectiveBox(context),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildObjectiveBox(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101520),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: .02),
        ),
      ),
      child: Column(
        children: [
          // dropzone at top (before first objective)
          _ObjectiveDropZone(
            onAccept: (payload) {
              widget.onMoveObjective(
                fromCategory: payload.fromCategory,
                toCategory: widget.data.id,
                obj: payload.objective,
                toIndex: 0,
              );
            },
          ),
          for (int i = 0; i < widget.data.items.length; i++) ...[
            LongPressDraggable<_DraggedObjectivePayload>(
              data: _DraggedObjectivePayload(
                objective: widget.data.items[i],
                fromCategory: widget.data.id,
                day: widget.day,
              ),
              feedback: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 290,
                    minWidth: 230,
                  ),
                  child: _CompactObjectiveRow(
                    objective: widget.data.items[i],
                    day: widget.day,
                    isGhost: true,
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: .13,
                child: _CompactObjectiveRow(
                  objective: widget.data.items[i],
                  day: widget.day,
                ),
              ),
              child: _CompactObjectiveRow(
                objective: widget.data.items[i],
                day: widget.day,
              ),
            ),
            // dropzone AFTER this objective
            _ObjectiveDropZone(
              onAccept: (payload) {
                widget.onMoveObjective(
                  fromCategory: payload.fromCategory,
                  toCategory: widget.data.id,
                  obj: payload.objective,
                  toIndex: i + 1,
                );
              },
            ),
          ],
          if (widget.data.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                'Drop objectives here',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .2),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.expanded,
    required this.isUncategorized,
    required this.hover,
    required this.onTap,
    required this.dragHandle,
  });

  final String label;
  final bool expanded;
  final bool isUncategorized;
  final bool hover;
  final VoidCallback onTap;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    final Color baseColor =
        isUncategorized ? const Color(0xFF1B1629) : const Color(0xFF162032);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: hover ? baseColor.withValues(alpha: .9) : baseColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppPalette.outline.withValues(alpha: .28),
            width: 0.7,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isUncategorized
                    ? Colors.pinkAccent
                    : Colors.blueAccent[400],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.category,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            // use Flexible(loose) so feedback in overlay won't blow up
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppPalette.onSurface,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: const Icon(
                Icons.expand_more,
                size: 18,
                color: Colors.white38,
              ),
            ),
            const SizedBox(width: 6),
            dragHandle,
          ],
        ),
      ),
    );
  }
}

class _ObjectiveDropZone extends StatelessWidget {
  const _ObjectiveDropZone({
    required this.onAccept,
    this.highlight = false,
  });

  final void Function(_DraggedObjectivePayload payload) onAccept;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_DraggedObjectivePayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, cand, rej) {
        final isHover = cand.isNotEmpty || highlight;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: isHover ? 14 : 6,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isHover
                ? Colors.tealAccent.withValues(alpha: .35)
                : Colors.white.withValues(alpha: .01),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      },
    );
  }
}

/// ultra-compact row just for organizer
class _CompactObjectiveRow extends StatelessWidget {
  const _CompactObjectiveRow({
    required this.objective,
    required this.day,
    this.isGhost = false,
  });

  final Objective objective;
  final DateTime day;
  final bool isGhost;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ObjectiveProvider>();
    final isCompleted = provider.isObjectiveCompletedOnDate(objective.id, day);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isGhost
            ? Colors.black.withValues(alpha: .1)
            : const Color(0xFF0A0F18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withValues(alpha: .35)
              : Colors.white.withValues(alpha: .035),
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.greenAccent.withValues(alpha: .8)
                  : Colors.blueAccent.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  objective.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    if (objective.categoryIds.isNotEmpty)
                      Text(
                        objective.categoryIds.first,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .28),
                          fontSize: 10.5,
                        ),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      '${objective.xpReward ?? 0} XP',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .22),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.drag_indicator,
            size: 18,
            color: Colors.white38,
          ),
        ],
      ),
    );
  }
}
