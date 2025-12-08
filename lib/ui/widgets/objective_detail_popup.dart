import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:kontinuum/models/objective.dart';
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/models/streak_models.dart';
import 'package:kontinuum/data/stat_repository.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/widgets/objective/objective_tokens.dart';
import 'package:kontinuum/data/level_utils.dart';
import 'package:kontinuum/core/time/app_clock.dart';

// same widgets the cards use
import 'package:kontinuum/ui/widgets/objective/complete_button.dart';
import 'package:kontinuum/ui/widgets/objective/tally_stepper.dart';
import 'package:kontinuum/ui/widgets/objective/stopwatch_sheet.dart';
import 'package:kontinuum/ui/widgets/xp_gain_bottom_bar.dart' as xpoverlay;
import 'package:kontinuum/ui/widgets/objective/stat_progress.dart';

// abstinence mini sheet
import 'package:kontinuum/ui/widgets/objective/abstinence_sheet.dart';

// helpers for history
import 'package:kontinuum/utils/date_keys.dart';

// page dots from workout overview
import 'package:kontinuum/ui/workout/session_widgets/overview_screen_widgets.dart';

class ObjectiveDetailPopup extends StatefulWidget {
  final Objective objective;
  final DateTime selectedDate;

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
  late final Animation<double> _bgOpacity;
  late final Animation<double> _bgBlur;
  bool _isPopping = false;

  static const Color _kCardBg = Color(0xFF13151B);

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
    if (o.categoryIds.isEmpty) return null;
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

  Future<void> _confirmDeleteObjective(Objective live) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<ObjectiveProvider>();
    final id = live.id;
    final title = live.title;

    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Delete objective?',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              '“$title” will be permanently removed.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
                onPressed: () => Navigator.pop(dialogCtx, false),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok || !mounted) return;

    _popWithHero(afterFlight: () async {
      await provider.deleteObjective(id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Objective “$title” deleted'),
        ),
      );
    });
  }

  Widget _buildHeaderRow(Objective live) {
    return Transform.translate(
      offset: const Offset(0, -6), // raise trash icon a bit
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 22,
            ),
            tooltip: 'Delete objective',
            onPressed: () => _confirmDeleteObjective(live),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Future<void> _handleStandardComplete(
    BuildContext context,
    Objective live,
    _ActionHelpers helpers,
  ) async {
    final provider = context.read<ObjectiveProvider>();
    final catName = helpers.primaryCategoryName(live);
    final before = helpers.lookupCategoryXp(provider, catName);

    provider.toggleObjectiveCompletion(widget.selectedDate, live.id);

    final after = helpers.lookupCategoryXp(provider, catName);
    if (after > before) {
      xpoverlay.XpGainBottomBar.show(
        context,
        label: (catName ?? 'TOTAL').toUpperCase(),
        fromXp: before,
        toXp: after,
        color: helpers.catColor(catName),
      );
    }
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

    final live = context.select<ObjectiveProvider, Objective>(
      (p) => _liveObjective(p),
    );

    final isStopwatch = _isStopwatch(live.type);
    final isTally = _isTally(live.type);
    final isWriting = _isWriting(live.type);
    final isAbstinence = live.isAbstinence;

    final helpers = _ActionHelpers(
      isStopwatch: isStopwatch,
      isTally: isTally,
      isWriting: isWriting,
      isAbstinence: isAbstinence,
      primaryCategoryName: (o) => _primaryCategoryName(o),
      catColor: (n) => _catColor(n),
      lookupCategoryXp: (p, n) => _lookupCategoryXp(p, n),
    );

    final showStandardCompleteButton =
        !live.isLocked && !isAbstinence && !isStopwatch && !isTally;
    final showTallyCompleteButton = !live.isLocked && isTally;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _popWithHero();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: _popWithHero,
          child: Stack(
            children: [
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
              Center(
                child: Stack(
                  children: [
                    Hero(
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
                                  _buildHeaderRow(live),
                                  const SizedBox(height: 4),
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
                                  if (live.categoryIds.isNotEmpty) ...[
                                    const SizedBox(height: 8),
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
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color:
                                                  color.withValues(alpha: 0.4),
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
                                  ],
                                  const SizedBox(height: 16),
                                  if (!isAbstinence)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          size: 18,
                                          color: Colors.amberAccent,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${live.xpReward} XP',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 12),
                                  if (!isAbstinence &&
                                      live.statIds.isNotEmpty)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Tracked Stats:',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
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
                                  if (isAbstinence) ...[
                                    const SizedBox(height: 4),
                                    _AbstinenceInfoCard(
                                      objective: live,
                                      selectedDate: widget.selectedDate,
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  _ObjectiveInsightsSection(objective: live),
                                  const SizedBox(height: 24),
                                  _ActionSection(
                                    live: live,
                                    selectedDate: widget.selectedDate,
                                    onShowXpOverlay: (
                                      context,
                                      before,
                                      after,
                                      label,
                                      color,
                                    ) {
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
                                    helpers: helpers,
                                  ),
                                  const SizedBox(height: 20),
                                  if (showStandardCompleteButton ||
                                      showTallyCompleteButton)
                                    Align(
                                      alignment: Alignment.center,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 280,
                                        ),
                                        child:
                                            Selector<ObjectiveProvider, bool>(
                                          selector: (_, p) {
                                            final list = p.getObjectivesForDay(
                                                widget.selectedDate);
                                            final idx = list.indexWhere(
                                                (o) => o.id == live.id);
                                            return (idx == -1
                                                ? live.isCompleted
                                                : list[idx].isCompleted);
                                          },
                                          builder: (_, isCompleted, __) {
                                            return FilledButton(
                                              onPressed: () =>
                                                  _handleStandardComplete(
                                                context,
                                                live,
                                                helpers,
                                              ),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: isCompleted
                                                    ? Colors.greenAccent
                                                        .withAlpha(60)
                                                    : Colors.greenAccent
                                                        .withAlpha(45),
                                                foregroundColor:
                                                    Colors.greenAccent,
                                                minimumSize:
                                                    const Size.fromHeight(44),
                                              ),
                                              child: Text(
                                                isCompleted
                                                    ? 'Completed'
                                                    : 'Complete',
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton(
                        tooltip: 'Close',
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(8),
                        ),
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: _popWithHero,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AbstinenceInfoCard extends StatelessWidget {
  final Objective objective;
  final DateTime selectedDate;

  const _AbstinenceInfoCard({
    required this.objective,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<ObjectiveProvider, int>(
      selector: (_, p) => p.getAbstinenceDays(objective.id, selectedDate),
      builder: (_, days, __) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1C28),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.lightBlueAccent.withAlpha(80),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.shield_moon,
                size: 20,
                color: Colors.lightBlueAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$days day${days == 1 ? '' : 's'} clean',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => AbstinenceSheet(
                      objective: objective,
                      selectedDate: selectedDate,
                    ),
                  );
                },
                child: const Text(
                  'Manage',
                  style: TextStyle(color: Colors.lightBlueAccent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// INSIGHTS PAGER (skills / stats / consistency)
/// ---------------------------------------------------------------------------

enum _SlideType { skills, stats, consistency }

class _InsightSlideConfig {
  final _SlideType type;
  final String title;
  final List<_LevelHistoryPoint> history;
  final List<_LevelItem> items;
  final ObjectiveStreak? streak;
  final Color accentColor;
  final double maxValue;
  final double valueOffset;
  final bool showAsRatio;
  final bool highlightLevelUps;
  final String valueLabel;

  const _InsightSlideConfig({
    required this.type,
    required this.title,
    required this.history,
    required this.accentColor,
    required this.maxValue,
    required this.valueOffset,
    this.items = const [],
    this.streak,
    this.showAsRatio = false,
    this.highlightLevelUps = false,
    this.valueLabel = '',
  });
}

class _ObjectiveInsightsSection extends StatefulWidget {
  final Objective objective;

  const _ObjectiveInsightsSection({
    required this.objective,
  });

  @override
  State<_ObjectiveInsightsSection> createState() =>
      _ObjectiveInsightsSectionState();
}

class _ObjectiveInsightsSectionState extends State<_ObjectiveInsightsSection> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final objective = widget.objective;

    return Consumer<ObjectiveProvider>(
      builder: (context, provider, _) {
        final primaryCategoryId = objective.categoryIds.isNotEmpty
            ? objective.categoryIds.first
            : null;
        final accentColor = (primaryCategoryId != null
                ? ObjectiveTokens.categoryColors[primaryCategoryId]
                : null) ??
            Colors.cyanAccent;

        final statItems =
            _buildStatLevelItems(provider, objective, accentColor);
        final skills = _buildSkillList(provider, objective);
        final skillItems =
            _buildSkillItems(provider, skills, accentColor: accentColor);

        final trackedDays = _objectiveTrackedDays(provider, objective);
        final consistencyPoints =
            _buildConsistencyPoints(provider, objective, trackedDays);

        final skillHistorySeries = _buildSkillHistorySeries(
          provider,
          skills,
          trackedDays,
          objectiveId: objective.id,
        );
        final statHistorySeries = _buildStatHistorySeries(
          provider,
          objective,
          trackedDays,
          objectiveId: objective.id,
        );
        final streak = _currentStreak(objective.id);

        final consistencyHistory = consistencyPoints
            .map(
              (p) => _LevelHistoryPoint(
                date: p.date,
                value: p.ratio.clamp(0.0, 1.0),
                ratio: p.ratio.clamp(0.0, 1.0),
                level: 0,
                leveledUp: false,
              ),
            )
            .toList();

        final slides = <_InsightSlideConfig>[];

        _InsightSlideConfig? statsSlide;
        if (statItems.isNotEmpty) {
          final statSpan =
              (statHistorySeries.maxValue - statHistorySeries.minValue)
                  .clamp(0, double.infinity);
          statsSlide = _InsightSlideConfig(
            type: _SlideType.stats,
            title: 'Stat levels',
            history: statHistorySeries.points,
            items: statItems,
            accentColor: accentColor,
            maxValue: statSpan.toDouble(),
            valueOffset: statHistorySeries.minValue,
            showAsRatio: false,
            highlightLevelUps: true,
            valueLabel: 'XP',
          );
        }

        _InsightSlideConfig? skillsSlide;
        if (skillItems.isNotEmpty) {
          final skillSpan =
              (skillHistorySeries.maxValue - skillHistorySeries.minValue)
                  .clamp(0, double.infinity);
          skillsSlide = _InsightSlideConfig(
            type: _SlideType.skills,
            title: 'Skill levels',
            history: skillHistorySeries.points,
            items: skillItems,
            accentColor: accentColor,
            maxValue: skillSpan.toDouble(),
            valueOffset: skillHistorySeries.minValue,
            showAsRatio: false,
            highlightLevelUps: true,
            valueLabel: 'XP',
          );
        }

        if (statsSlide != null) {
          slides.add(statsSlide);
        }
        if (skillsSlide != null) {
          slides.add(skillsSlide);
        }

        if (consistencyPoints.isNotEmpty) {
          slides.add(
            _InsightSlideConfig(
              type: _SlideType.consistency,
              title: 'Consistency',
              history: consistencyHistory,
              items: const [],
              streak: streak,
              accentColor: accentColor,
              maxValue: 1,
              valueOffset: 0,
              showAsRatio: true,
              highlightLevelUps: false,
              valueLabel: '%',
            ),
          );
        }

        if (slides.isEmpty) {
          return const SizedBox.shrink();
        }

        if (_currentPage >= slides.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _currentPage = slides.length - 1;
              _pageController.jumpToPage(_currentPage);
            });
          });
        }

        final int pageIndex =
            _currentPage.clamp(0, slides.length - 1); // safe in build
        final currentSlide = slides[pageIndex];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 172, // 160 chart + 12 gap
              child: PageView.builder(
                key: PageStorageKey(
                  'objective_insights_pager_${objective.id}',
                ),
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: slides.length,
                itemBuilder: (context, index) {
                  return _InsightSlideView(config: slides[index]);
                },
              ),
            ),
            if (slides.length > 1) ...[
              const SizedBox(height: 8),
              Center(
                child: PageDotsIndicator(
                  count: slides.length,
                  index: pageIndex,
                ),
              ),
              const SizedBox(height: 8),
            ] else
              const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _buildSlideDetail(currentSlide, key: ValueKey(pageIndex)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSlideDetail(
    _InsightSlideConfig slide, {
    Key? key,
  }) {
    switch (slide.type) {
      case _SlideType.skills:
      case _SlideType.stats:
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              slide.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 6),
            _ObjectiveLevelSection(items: slide.items),
          ],
        );

      case _SlideType.consistency:
        final streak = slide.streak;
        final bgColor = const Color(0xFF0C1016);
        final borderColor = Colors.white.withValues(alpha: 0.08);

        String formatDays(int days) {
          if (days <= 0) return '0 days';
          if (days == 1) return '1 day';
          return '$days days';
        }

        return Container(
          key: key,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Consistency streak',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (streak == null) ...[
                const Text(
                  'No streak data yet',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _StreakStatTile(
                        label: 'Current streak',
                        value: formatDays(streak.current),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StreakStatTile(
                        label: 'Best streak',
                        value: formatDays(streak.best),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Complete this objective daily to grow your streak.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _StreakStatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StreakStatTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InsightSlideView extends StatelessWidget {
  final _InsightSlideConfig config;

  const _InsightSlideView({
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 160,
          child: _ObjectiveTrendChart(
            points: config.history,
            accentColor: config.accentColor,
            maxValue: config.maxValue,
            valueOffset: config.valueOffset,
            showAsRatio: config.showAsRatio,
            highlightLevelUps: config.highlightLevelUps,
            valueLabel: config.valueLabel,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// DATA HELPERS FOR INSIGHTS
/// ---------------------------------------------------------------------------

class _HistorySeries {
  final List<_LevelHistoryPoint> points;
  final double minValue;
  final double maxValue;

  const _HistorySeries({
    required this.points,
    required this.minValue,
    required this.maxValue,
  });
}

class _ConsistencyPoint {
  final DateTime date;
  final double ratio;

  const _ConsistencyPoint({
    required this.date,
    required this.ratio,
  });
}

List<_ConsistencyPoint> _buildConsistencyPoints(
  ObjectiveProvider provider,
  Objective objective,
  List<DateTime> trackedDays,
) {
  if (trackedDays.isEmpty) return const [];

  final points = <_ConsistencyPoint>[];

  for (final day in trackedDays) {
    final listForDay = provider.getObjectivesForDay(day);
    final idx = listForDay.indexWhere((o) => o.id == objective.id);
    if (idx == -1) continue;

    final instance = listForDay[idx];

    final ratio = instance.completionRatioForDate(day);
    points.add(
      _ConsistencyPoint(
        date: day,
        ratio: ratio.clamp(0.0, 1.0),
      ),
    );
  }

  if (points.isEmpty) return const [];

  const maxPoints = 30;
  if (points.length <= maxPoints) {
    return points;
  }
  return points.sublist(points.length - maxPoints);
}

List<DateTime> _objectiveTrackedDays(
  ObjectiveProvider provider,
  Objective objective,
) {
  final today = DateKeys.dateOnly(AppClock.now());
  final defaultStart = today.subtract(const Duration(days: 29));
  final earliestRecorded = _earliestObjectiveEntryDate(provider, objective);
  DateTime start = defaultStart;
  if (earliestRecorded != null) {
    if (earliestRecorded.isAfter(today)) {
      start = today;
    } else if (earliestRecorded.isAfter(defaultStart)) {
      start = earliestRecorded;
    }
  }
  final tracked = <DateTime>[];

  DateTime cursor = start;
  while (!cursor.isAfter(today)) {
    final listForDay = provider.getObjectivesForDay(cursor);
    final idx = listForDay.indexWhere((o) => o.id == objective.id);
    if (idx != -1) {
      final instance = listForDay[idx];
      if (instance.isAbstinence || instance.isActiveOnDate(cursor)) {
        tracked.add(cursor);
      }
    } else {
      if (objective.isAbstinence || objective.isActiveOnDate(cursor)) {
        tracked.add(cursor);
      }
    }
    cursor = cursor.add(const Duration(days: 1));
  }

  return tracked;
}

DateTime? _earliestObjectiveEntryDate(
  ObjectiveProvider provider,
  Objective objective,
) {
  final dates = provider.getAllTrackedDates().toList()
    ..sort((a, b) => a.compareTo(b));
  for (final day in dates) {
    final list = provider.getObjectivesForDay(day);
    if (list.any((o) => o.id == objective.id)) {
      return day;
    }
  }
  return null;
}

List<Skill> _buildSkillList(
  ObjectiveProvider provider,
  Objective objective,
) {
  if (objective.statIds.isEmpty) return const [];

  final statIds = objective.statIds;
  final skills = <Skill>[];

  for (final skill in provider.skills.values) {
    final hasMatch = skill.stats.any((s) => statIds.contains(s.id));
    if (hasMatch) {
      skills.add(skill);
    }
  }

  if (skills.isEmpty) return const [];

  int indexForSkill(Skill skill) {
    int best = statIds.length;
    for (final stat in skill.stats) {
      final idx = statIds.indexOf(stat.id);
      if (idx != -1 && idx < best) {
        best = idx;
      }
    }
    return best;
  }

  skills.sort((a, b) => indexForSkill(a).compareTo(indexForSkill(b)));
  return skills;
}

class _LevelItem {
  final String label;
  final int xp;
  final Color color;
  final int maxXp;
  final int level;
  final int currentWithin;
  final int levelSpan;
  final int xpToNext;
  final bool isAtCap;

  const _LevelItem({
    required this.label,
    required this.xp,
    required this.color,
    required this.maxXp,
    required this.level,
    required this.currentWithin,
    required this.levelSpan,
    required this.xpToNext,
    required this.isAtCap,
  });
}

List<_LevelItem> _buildStatLevelItems(
  ObjectiveProvider provider,
  Objective objective,
  Color accentColor,
) {
  if (objective.statIds.isEmpty) return const [];

  final items = <_LevelItem>[];

  for (final statId in objective.statIds) {
    final stat = provider.stats[statId];
    final xp = stat?.xp ?? 0;
    final label = StatRepository.getDisplay(statId);
    final maxXp = stat?.maxXp ?? 0;
    final level = stat?.level ?? 1;

    items.add(_makeLevelItem(
      label: label,
      xp: xp,
      maxXp: maxXp,
      level: level,
      color: accentColor,
    ));
  }

  return items;
}

List<_LevelItem> _buildSkillItems(
  ObjectiveProvider provider,
  List<Skill> skills, {
  required Color accentColor,
}) {
  if (skills.isEmpty) return const [];

  final items = <_LevelItem>[];

  for (final skill in skills) {
    items.add(_makeLevelItem(
      label: skill.label,
      xp: skill.xp,
      maxXp: skill.maxXp,
      level: skill.level,
      color: accentColor,
    ));
  }

  return items;
}

_LevelItem _makeLevelItem({
  required String label,
  required int xp,
  required int maxXp,
  required int level,
  required Color color,
}) {
  final safeMax = maxXp <= 0 ? 1 : maxXp;
  final cappedXp = xp <= 0
      ? 0
      : (xp >= safeMax ? safeMax : xp);
  final cappedLevel = level.clamp(1, LevelUtils.maxLevel);

  var startOfLevel = LevelUtils.getXpForLevel(cappedLevel, safeMax);
  startOfLevel = startOfLevel.clamp(0, safeMax);

  int nextLevelXp;
  if (cappedLevel >= LevelUtils.maxLevel) {
    nextLevelXp = safeMax;
  } else {
    nextLevelXp = LevelUtils.getXpForLevel(cappedLevel + 1, safeMax);
    if (nextLevelXp < startOfLevel) nextLevelXp = startOfLevel;
    if (nextLevelXp > safeMax) nextLevelXp = safeMax;
  }

  int levelSpan = nextLevelXp - startOfLevel;
  if (levelSpan <= 0) levelSpan = 1;
  if (levelSpan > safeMax) levelSpan = safeMax;

  int currentWithin = cappedXp - startOfLevel;
  if (currentWithin < 0) currentWithin = 0;
  if (currentWithin > levelSpan) currentWithin = levelSpan;
  int xpToNext = cappedLevel >= LevelUtils.maxLevel ? 0 : (nextLevelXp - cappedXp);
  if (xpToNext < 0) xpToNext = 0;
  final isAtCap = cappedLevel >= LevelUtils.maxLevel || xpToNext <= 0;

  return _LevelItem(
    label: label,
    xp: cappedXp,
    color: color,
    maxXp: safeMax,
    level: cappedLevel,
    currentWithin: currentWithin,
    levelSpan: levelSpan,
    xpToNext: xpToNext,
    isAtCap: isAtCap,
  );
}

class _LevelHistoryPoint {
  final DateTime date;
  final double value;
  final double ratio;
  final int level;
  final bool leveledUp;

  const _LevelHistoryPoint({
    required this.date,
    required this.value,
    required this.ratio,
    required this.level,
    required this.leveledUp,
  });
}

_HistorySeries _buildSkillHistorySeries(
  ObjectiveProvider provider,
  List<Skill> skills,
  List<DateTime> trackedDays, {
  required String objectiveId,
}) {
  if (skills.isEmpty || provider.statHistory.isEmpty) {
    return const _HistorySeries(points: [], minValue: 0, maxValue: 0);
  }

  final skillIds = skills.map((s) => s.id).toSet();
  if (skillIds.isEmpty) {
    return const _HistorySeries(points: [], minValue: 0, maxValue: 0);
  }

  final totalMaxXp = skills.fold<double>(
    0,
    (sum, s) => sum + (s.maxXp <= 0 ? 0 : s.maxXp.toDouble()),
  );
  if (totalMaxXp <= 0) {
    return const _HistorySeries(points: [], minValue: 0, maxValue: 0);
  }

  final series = _buildHistoryPoints(
    provider,
    statPredicate: (entry) {
      final skillId = entry.skillId;
      if (skillId == null) return false;
      return skillIds.contains(skillId);
    },
    objectiveId: objectiveId,
    totalMaxXp: totalMaxXp,
    trackedDays: trackedDays,
  );

  final minValue = series.isEmpty
      ? 0.0
      : series.map((p) => p.value).reduce((a, b) => a < b ? a : b);
  final maxValue = series.isEmpty
      ? 0.0
      : series.map((p) => p.value).reduce((a, b) => a > b ? a : b);

  return _HistorySeries(points: series, minValue: minValue, maxValue: maxValue);
}

_HistorySeries _buildStatHistorySeries(
  ObjectiveProvider provider,
  Objective objective,
  List<DateTime> trackedDays, {
  required String objectiveId,
}) {
  if (objective.statIds.isEmpty || provider.statHistory.isEmpty) {
    return const _HistorySeries(points: [], minValue: 0, maxValue: 0);
  }

  final statIds = objective.statIds.toSet();
  if (statIds.isEmpty) {
    return const _HistorySeries(points: [], minValue: 0, maxValue: 0);
  }

  final relevantStats = <String, int>{};
  for (final id in statIds) {
    final stat = provider.stats[id];
    if (stat != null && stat.maxXp > 0) {
      relevantStats[id] = stat.maxXp;
    }
  }

  final totalMaxXp = relevantStats.values.fold<double>(
    0,
    (sum, v) => sum + v.toDouble(),
  );
  if (totalMaxXp <= 0) {
    return const _HistorySeries(points: [], minValue: 0, maxValue: 0);
  }

  final series = _buildHistoryPoints(
    provider,
    statPredicate: (entry) {
      final statId = entry.statId;
      if (statId == null) return false;
      return statIds.contains(statId);
    },
    objectiveId: objectiveId,
    totalMaxXp: totalMaxXp,
    trackedDays: trackedDays,
  );

  final minValue = series.isEmpty
      ? 0.0
      : series.map((p) => p.value).reduce((a, b) => a < b ? a : b);
  final maxValue = series.isEmpty
      ? 0.0
      : series.map((p) => p.value).reduce((a, b) => a > b ? a : b);

  return _HistorySeries(points: series, minValue: minValue, maxValue: maxValue);
}

typedef _HistoryPredicate = bool Function(_StatHistoryProxy entry);

List<_LevelHistoryPoint> _buildHistoryPoints(
  ObjectiveProvider provider, {
  required _HistoryPredicate statPredicate,
  required String objectiveId,
  required double totalMaxXp,
  required List<DateTime> trackedDays,
}) {
  if (totalMaxXp <= 0) return const [];

  final dailyDeltas = <DateTime, double>{};
  final history = List<dynamic>.from(provider.statHistory, growable: false);

  history.sort((a, b) {
    final da = (a as dynamic).date as DateTime? ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final db = (b as dynamic).date as DateTime? ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return da.compareTo(db);
  });

  for (final raw in history) {
    final entry = _StatHistoryProxy(raw);
    if (!statPredicate(entry)) continue;
    final entryObjectiveId = entry.objectiveId;
    if (entryObjectiveId != null && entryObjectiveId != objectiveId) {
      continue;
    }

    final DateTime? date = entry.date;
    if (date == null) continue;

    final num amountNum = entry.xpDelta;

    final day = DateKeys.dateOnly(date);
    final amount = amountNum.toDouble();

    dailyDeltas[day] = (dailyDeltas[day] ?? 0) + amount;
  }

  final timelineSet = <DateTime>{
    ...dailyDeltas.keys,
    ...trackedDays,
  };

  if (timelineSet.isEmpty) return const [];

  final days = timelineSet.toList()..sort((a, b) => a.compareTo(b));

  final points = <_LevelHistoryPoint>[];
  double cumulative = 0;
  int prevLevel = 1;
  var isFirstPoint = true;

  for (final day in days) {
    cumulative += dailyDeltas[day] ?? 0;
    if (cumulative < 0) cumulative = 0;
    final ratio = (cumulative / totalMaxXp).clamp(0.0, 1.0);
    final level = (ratio * 100).clamp(1.0, 100.0).toInt();
    final leveledUp = !isFirstPoint && level > prevLevel;
    prevLevel = level;
    isFirstPoint = false;

    points.add(
      _LevelHistoryPoint(
        date: day,
        value: cumulative,
        ratio: ratio,
        level: level,
        leveledUp: leveledUp,
      ),
    );
  }

  const maxPoints = 30;
  if (points.length > maxPoints) {
    return points.sublist(points.length - maxPoints);
  }
  return points;
}

class _StatHistoryProxy {
  final dynamic raw;

  const _StatHistoryProxy(this.raw);

  String? get statId => raw.statId as String?;
  String? get skillId => raw.skillId as String?;
  DateTime? get date => raw.date as DateTime?;
  int get xpDelta {
    final xp = raw.xpDelta as int?;
    if (xp != null && xp != 0) return xp;
    return raw.amount as int? ?? 0;
  }

  String? get objectiveId => raw.objectiveId as String?;
}

ObjectiveStreak? _currentStreak(String objectiveId) {
  // Stubbed for now: returns null so the UI shows "No streak data yet".
  // Once we know how your StreakEngine is accessed (singleton / provider),
  // we can wire this up to getObjectiveStreak(objectiveId).
  return null;
}

/// ---------------------------------------------------------------------------
/// TREND CHARTS (reused for skills / stats / consistency)
/// ---------------------------------------------------------------------------

class _ObjectiveTrendChart extends StatelessWidget {
  final List<_LevelHistoryPoint> points;
  final Color accentColor;
  final double maxValue;
  final double valueOffset;
  final bool showAsRatio;
  final bool highlightLevelUps;
  final String valueLabel;

  const _ObjectiveTrendChart({
    required this.points,
    required this.accentColor,
    required this.maxValue,
    required this.valueOffset,
    required this.showAsRatio,
    required this.highlightLevelUps,
    required this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1016),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: const Center(
          child: Text(
            'No history yet',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    final rawRange = maxValue <= 0 ? 1.0 : maxValue;
    final chartMax = showAsRatio ? 1.0 : (rawRange * 1.1).clamp(1.0, double.infinity);
    final baseline = showAsRatio ? 0.0 : valueOffset;
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      final value = showAsRatio
          ? points[i].value.clamp(0.0, 1.0)
          : (points[i].value - baseline).clamp(0.0, double.infinity);
      spots.add(FlSpot(i.toDouble(), value));
    }

    final interval =
        (points.length / 4).ceil().clamp(1, points.length).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1016),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        boundaryMargin: const EdgeInsets.all(60),
        constrained: true,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: showAsRatio ? 1 : chartMax,
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.black.withValues(alpha: 0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots
                    .map((spot) {
                      final idx = spot.x.round();
                      if (idx < 0 || idx >= points.length) {
                        return null;
                      }
                      final point = points[idx];
                      final dateLabel = _formatShortDate(point.date);
                      final valueText = showAsRatio
                          ? '${(point.value * 100).clamp(0, 100).round()}%'
                          : '${_formatXp(point.value)}${valueLabel.isEmpty ? '' : ' $valueLabel'}';
                      final levelText = (!showAsRatio && point.level > 0)
                          ? '\nLv ${point.level}'
                          : '';
                      return LineTooltipItem(
                        '$dateLabel\n$valueText$levelText',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      );
                    })
                    .whereType<LineTooltipItem>()
                    .toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            horizontalInterval: showAsRatio
                ? 0.25
                : _resolveGridInterval(chartMax),
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.06),
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
              right: const BorderSide(color: Colors.transparent),
              top: const BorderSide(color: Colors.transparent),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: showAsRatio ? 26 : 36,
                interval: showAsRatio ? 0.5 : null,
                getTitlesWidget: (value, meta) {
                  if (showAsRatio) {
                    String text;
                    if (value <= 0.0) {
                      text = '0%';
                    } else if ((value - 0.5).abs() < 0.01) {
                      text = '50%';
                    } else if ((value - 1.0).abs() < 0.01) {
                      text = '100%';
                    } else {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                    );
                  }

                  if (value < 0 || value > chartMax + 0.001) {
                    return const SizedBox.shrink();
                  }

                  final actual = (baseline + value).clamp(0.0, double.infinity);
                  final label =
                      '${_formatXp(actual)}${valueLabel.isEmpty ? '' : ' $valueLabel'}';
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  final idx = value.round();
                  if (idx < 0 || idx >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final d = points[idx].date;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      _formatShortDate(d),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                barWidth: 2,
                color: accentColor,
                dotData: FlDotData(
                  show: highlightLevelUps,
                  checkToShowDot: (spot, _) {
                    if (!highlightLevelUps) return false;
                    final idx = spot.x.round();
                    if (idx < 0 || idx >= points.length) return false;
                    return points[idx].leveledUp;
                  },
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 3.5,
                    color: Colors.white,
                    strokeWidth: 1.5,
                    strokeColor: accentColor,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.25),
                      accentColor.withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
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

String _formatShortDate(DateTime d) {
  return '${d.month}/${d.day}';
}

String _formatXp(double value) {
  if (value.abs() >= 1000) {
    final thousands = value / 1000;
    final precision = thousands >= 10 ? 0 : 1;
    return '${thousands.toStringAsFixed(precision)}K';
  }
  return value.round().toString();
}

double _resolveGridInterval(double maxValue) {
  if (maxValue <= 0) return 1;
  final raw = maxValue / 4;
  if (raw <= 10) return 5;
  if (raw <= 50) return 25;
  if (raw <= 100) return 50;
  if (raw <= 250) return 100;
  if (raw <= 500) return 150;
  if (raw <= 1000) return 250;
  return (raw / 100).ceil() * 100;
}

/// ---------------------------------------------------------------------------
/// LEVEL BARS (stats / skills)
/// ---------------------------------------------------------------------------

class _ObjectiveLevelSection extends StatefulWidget {
  final List<_LevelItem> items;

  const _ObjectiveLevelSection({
    required this.items,
  });

  @override
  State<_ObjectiveLevelSection> createState() => _ObjectiveLevelSectionState();
}

class _ObjectiveLevelSectionState extends State<_ObjectiveLevelSection> {
  Map<String, int> _prevXpByKey = {};

  String _keyFor(_LevelItem item) => '${item.label}_${item.maxXp}';

  int _safeMax(int maxXp) => maxXp <= 0 ? 1 : maxXp;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final previousSnapshot = _prevXpByKey;
    final nextSnapshot = <String, int>{};

    final children = <Widget>[];

    for (final item in items) {
      final key = _keyFor(item);
      nextSnapshot[key] = item.xp;
      final safeMax = _safeMax(item.maxXp);
      final prevRaw = previousSnapshot[key] ?? item.xp;
      final prevXp = prevRaw < 0
          ? 0
          : (prevRaw > safeMax ? safeMax : prevRaw);
      final currRaw = item.xp;
      final currXp = currRaw < 0
          ? 0
          : (currRaw > safeMax ? safeMax : currRaw);

      children.add(
        _LevelBarRow(
          item: item,
          previousXp: prevXp,
          currentXp: currXp,
          maxXp: safeMax,
        ),
      );
    }

    final column = Column(children: children);
    _updateSnapshot(nextSnapshot);
    return column;
  }

  void _updateSnapshot(Map<String, int> nextSnapshot) {
    // We don't need setState here; the new snapshot is used on the next build.
    _prevXpByKey = nextSnapshot;
  }
}

class _LevelBarRow extends StatelessWidget {
  final _LevelItem item;
  final int previousXp;
  final int currentXp;
  final int maxXp;

  const _LevelBarRow({
    required this.item,
    required this.previousXp,
    required this.currentXp,
    required this.maxXp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.label} • Lv ${item.level}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${item.xp} XP',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LevelProgressBar(
              previousXp: previousXp,
              currentXp: currentXp,
              maxXp: maxXp,
              color: item.color,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              thickness: 6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.isAtCap
                    ? 'Max level reached'
                    : '${item.xpToNext} XP to next level',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                ),
              ),
              Text(
                '${item.xp}/${item.maxXp} XP total',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GreyOutTransition extends StatelessWidget {
  final bool enabled;
  final Widget child;
  static const Duration _kDuration = Duration(milliseconds: 220);

  const _GreyOutTransition({
    required this.enabled,
    required this.child,
  });

  static const List<double> _identityMatrix = <double>[
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
    0, 0, 0, 0, 1,
  ];

  static const List<double> _greyMatrix = <double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
    0, 0, 0, 0, 1,
  ];

  List<double> _matrixFor(double t) {
    return List<double>.generate(
      20,
      (i) => _identityMatrix[i] * (1 - t) + _greyMatrix[i] * t,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: enabled ? 1 : 0),
      duration: _kDuration,
      builder: (context, value, child) {
        final opacity = ui.lerpDouble(1.0, 0.45, value) ?? 1.0;
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(_matrixFor(value)),
          child: Opacity(
            opacity: opacity,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// ---------------------------------------------------------------------------
/// ACTION SECTION
/// ---------------------------------------------------------------------------

class _ActionSection extends StatelessWidget {
  final Objective live;
  final DateTime selectedDate;
  final void Function(
    BuildContext ctx,
    int before,
    int after,
    String label,
    Color color,
  ) onShowXpOverlay;
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
    final isAbstinence = helpers.isAbstinence;

    final provider = context.read<ObjectiveProvider>();

    Future<void> toggleComplete() async {
      final catName = helpers.primaryCategoryName(live);
      final before = helpers.lookupCategoryXp(provider, catName);
      provider.toggleObjectiveCompletion(selectedDate, live.id);
      final after = helpers.lookupCategoryXp(provider, catName);
      onShowXpOverlay(
        context,
        before,
        after,
        (catName ?? 'TOTAL').toUpperCase(),
        helpers.catColor(catName),
      );
    }

    Future<void> logRelapse() async {
      await provider.logAbstinenceRelapse(live.id, selectedDate);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Relapse logged for “${live.title}”. Streak reset.'),
        ),
      );
    }

    if (isAbstinence) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => AbstinenceSheet(
                  objective: live,
                  selectedDate: selectedDate,
                ),
              );
            },
            icon: const Icon(Icons.shield_moon, size: 18),
            label: const Text('Manage abstinence'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.lightBlueAccent.withAlpha(45),
              foregroundColor: Colors.lightBlueAccent,
              minimumSize: const Size.fromHeight(44),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () async => logRelapse(),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Mark relapse'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent.withAlpha(45),
              foregroundColor: Colors.redAccent,
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      );
    }

    if (isTally) {
      return Selector<ObjectiveProvider, ({int amount, bool isCompleted})>(
        selector: (_, p) {
          final list = p.getObjectivesForDay(selectedDate);
          final idx = list.indexWhere((o) => o.id == live.id);
          if (idx == -1) {
            return (
              amount: live.getCompletedAmount(selectedDate),
              isCompleted: live.isCompleted,
            );
          }
          final obj = list[idx];
          return (
            amount: obj.getCompletedAmount(selectedDate),
            isCompleted: obj.isCompleted,
          );
        },
        builder: (context, state, __) {
          final amount = state.amount;
          final isCompleted = state.isCompleted;
          return Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: AbsorbPointer(
                absorbing: isCompleted,
                child: _GreyOutTransition(
                  enabled: isCompleted,
                  child: TallyStepper(
                    amount: amount,
                    min: 0,
                    max: 1 << 31,
                    target: live.targetAmount,
                    rowHeight: ObjectiveTokens.kRowHeight,
                    numberFontSize: ObjectiveTokens.kStepperNumber,
                    radius: 18,
                    expandToWidth: true,
                    onChanged: (next) {
                      final p = context.read<ObjectiveProvider>();
                      p.updateObjectiveAmountForDate(selectedDate, live.id, next);

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
              ),
            ),
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
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  isScrollControlled: true,
                  builder: (_) => StopwatchSheet(
                    targetMinutes: live.targetAmount,
                    onLogMinutes: (m) {
                      final p = context.read<ObjectiveProvider>();
                      final list = p.getObjectivesForDay(selectedDate);
                      final idx = list.indexWhere((o) => o.id == live.id);
                      final current = (idx == -1
                          ? 0
                          : list[idx].getCompletedAmount(selectedDate));
                      p.updateObjectiveAmountForDate(
                        selectedDate,
                        live.id,
                        current + m,
                      );
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
            selectedDate: selectedDate,
            onToggle: toggleComplete,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

class _CompleteToggleButton extends StatelessWidget {
  final Objective live;
  final DateTime selectedDate;
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
  final bool isAbstinence;
  final String? Function(Objective) primaryCategoryName;
  final Color Function(String?) catColor;
  final int Function(ObjectiveProvider, String?) lookupCategoryXp;

  const _ActionHelpers({
    required this.isStopwatch,
    required this.isTally,
    required this.isWriting,
    required this.isAbstinence,
    required this.primaryCategoryName,
    required this.catColor,
    required this.lookupCategoryXp,
  });
}
