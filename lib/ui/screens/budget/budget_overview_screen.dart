import 'dart:math' as math;
import 'dart:ui' as ui show TextDirection;

import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/budget_provider.dart';
import 'controller/create_budget_controller.dart';
import 'models/budget_models.dart';
import 'painters/ring_painters.dart';
import 'sheets/category_creator_sheet.dart';
import 'sheets/recurring_creator_sheet.dart';
import 'theme/budget_theme.dart';
import 'widgets/amount_picker_card.dart';
import 'widgets/common_widgets.dart';

class BudgetOverviewScreen extends StatefulWidget {
  const BudgetOverviewScreen({super.key, required this.budgetId});

  final String budgetId;

  /// Kept for source-side usage if needed.
  static String folderHeroTagFor(String id) => 'budget_folder_hero_$id';

  @override
  State<BudgetOverviewScreen> createState() => _BudgetOverviewScreenState();
}

class _BudgetOverviewScreenState extends State<BudgetOverviewScreen>
    with TickerProviderStateMixin {
  // Layout
  static const double _topInsetFraction = 0.12;
  static const double _pillInitialTop = 12;
  static const double _chartTopPad = 6;

  // Ring sizing
  static const double _ringSize = 248;
  static const double _ringStroke = 14;

  // Title
  final _titleCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  static const int _maxTitleChars = 48;
  static const double _titleMaxFont = 44;
  static const double _titleMinFont = 24;
  static const int _titleMaxLinesWhenWrapped = 2;

  // Controller
  late final CreateBudgetController _ctrl;

  // Expand/collapse
  bool _categoriesExpanded = false;
  bool _recurringExpanded = false;

  // Animations
  late final AnimationController _ringScaleCtrl;
  late final CurvedAnimation _ringScale;
  late final AnimationController _sweepCtrl;
  late final CurvedAnimation _sweep;
  late final AnimationController _divideCtrl;
  late final CurvedAnimation _divide;

  static const _layoutDuration = Duration(milliseconds: 360);
  static const _layoutCurve = Curves.easeOutCubic;
  static const _pillsFadeDuration = Duration(milliseconds: 260);

  // Heroes
  static const String _kAmountHero = 'budget_amount_hero';

  // Measure pill
  final GlobalKey _pillKey = GlobalKey();
  Size? _pillSize;

  ScaffoldMessengerState? _scaffold;
  final _currencyFmt = NumberFormat.currency(symbol: '\$');

  Budget? _budget; // cached selected budget

  @override
  void initState() {
    super.initState();

    final provider = Provider.of<BudgetProvider>(context, listen: false);
    _budget = _findBudget(provider);

    _ctrl = CreateBudgetController(initial: _budget?.toDraft())
      ..addListener(() {
        if (mounted) setState(() {});
      });

    // Title prefill
    _titleCtrl.text = _ctrl.title;
    _titleCtrl.addListener(() => _ctrl.setTitle(_titleCtrl.text));

    // Animations
    _ringScaleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _ringScale =
        CurvedAnimation(parent: _ringScaleCtrl, curve: Curves.easeOutCubic);
    _sweepCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _sweep = CurvedAnimation(parent: _sweepCtrl, curve: Curves.easeOutCubic);
    _divideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _divide = CurvedAnimation(parent: _divideCtrl, curve: Curves.easeOutCubic);

    if (_budget != null) {
      _ringScaleCtrl.value = 1.0;
      _sweepCtrl.value = 1.0;
      _divideCtrl.value = 1.0;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measurePill();
    });
  }

  // Keep view synced with persisted model during hot-reload
  @override
  void reassemble() {
    super.reassemble();
    if (!mounted || !kDebugMode) return;
    final provider = context.read<BudgetProvider>();
    final fresh = _findBudget(provider);
    if (fresh == null) return;
    setState(() {
      _budget = fresh;
      if (!_titleFocus.hasFocus && _titleCtrl.text != fresh.title) {
        _titleCtrl.text = fresh.title;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffold = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _titleFocus.dispose();
    _ringScaleCtrl.dispose();
    _sweepCtrl.dispose();
    _divideCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  // —— Helpers

  Budget? _findBudget(BudgetProvider provider) {
    try {
      return provider.budgets.firstWhere((b) => b.id == widget.budgetId);
    } catch (_) {
      return null;
    }
  }

  void _measurePill() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rb = _pillKey.currentContext?.findRenderObject() as RenderBox?;
      if (rb == null || !mounted) return;
      final newSize = rb.size;
      if (_pillSize == null || _pillSize != newSize) {
        setState(() => _pillSize = newSize);
      }
    });
  }

  void _handleCloseTap() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _toggleCategories() {
    HapticFeedback.selectionClick();
    setState(() => _categoriesExpanded = !_categoriesExpanded);
  }

  void _toggleRecurring() {
    HapticFeedback.selectionClick();
    setState(() => _recurringExpanded = !_recurringExpanded);
  }

  Future<void> _openAmountPicker() async {
    await showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Set amount',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, a1, a2) {
        return Center(
          child: Hero(
            tag: _kAmountHero,
            child: Material(
              color: Colors.transparent,
              child: AmountPickerCard(
                initial: (_ctrl.monthlyAmount ?? 2000).toDouble(),
                onCancel: () => Navigator.of(context).pop(),
                onConfirm: (value) {
                  Navigator.of(context).pop();
                  Future.microtask(() => _applyAmountAndAnimate(value.round()));
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Opacity(
          opacity: anim.value,
          child: Transform.scale(
            scale: 0.9 + 0.1 * curved.value,
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _applyAmountAndAnimate(int value) async {
    if (!mounted) return;
    _ctrl.setMonthlyAmount(value);
    await Future.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    _measurePill();
    _ringScaleCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    _sweepCtrl.forward(from: 0);

    if (_ctrl.isOverBudget) {
      final over = _currencyFmt.format(_ctrl.overageCents() / 100.0);
      _scaffold?.clearSnackBars();
      _scaffold?.showSnackBar(
        SnackBar(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          content: Text(
            'You’re over budget by $over.',
            style: const TextStyle(color: Colors.white),
          ),
          action: SnackBarAction(
            label: 'Edit amount',
            textColor: BudgetTheme.mint,
            onPressed: _openAmountPicker,
          ),
        ),
      );
    }
  }

  Future<void> _openCategoryCreator({int? editIndex}) async {
    HapticFeedback.selectionClick();
    final initial = (editIndex != null) ? _ctrl.categories[editIndex] : null;
    final BudgetCategory? result = await showModalBottomSheet<BudgetCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BudgetTheme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => CategoryCreatorSheet(
        initial: initial,
        onSubmit: (c) => Navigator.of(ctx).pop(c),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      if (editIndex != null) {
        _ctrl.updateCategoryAt(editIndex, result);
      } else {
        _ctrl.addCategory(result);
        _categoriesExpanded = true;
      }
      _sweepCtrl.forward(from: 0.0);
      _divideCtrl.forward(from: 0.0);
    }
  }

  Future<void> _openRecurringCreator({int? editIndex}) async {
    HapticFeedback.selectionClick();
    final initial = (editIndex != null) ? _ctrl.recurrings[editIndex] : null;
    final RecurringExpense? result =
        await showModalBottomSheet<RecurringExpense>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BudgetTheme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => RecurringCreatorSheet(
        initial: initial,
        categories: _ctrl.categories,
        onSubmit: (r) => Navigator.of(ctx).pop(r),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      if (editIndex != null) {
        _ctrl.updateRecurringAt(editIndex, result);
      } else {
        _ctrl.addRecurring(result);
        _recurringExpanded = true;
      }
      _sweepCtrl.forward(from: 0.0);
      _divideCtrl.forward(from: 0.0);

      if (_ctrl.isOverBudget) {
        final over = _currencyFmt.format(_ctrl.overageCents() / 100.0);
        _scaffold?.clearSnackBars();
        _scaffold?.showSnackBar(
          SnackBar(
            backgroundColor: Colors.black.withValues(alpha: 0.9),
            content: Text(
              'You’re over budget by $over.',
              style: const TextStyle(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'Edit amount',
              textColor: BudgetTheme.mint,
              onPressed: _openAmountPicker,
            ),
          ),
        );
      }
    }
  }

  void _deleteCategory(int index) {
    if (index < 0 || index >= _ctrl.categories.length) return;
    final removed = _ctrl.removeCategoryAt(index);
    _sweepCtrl.forward(from: 0.0);
    _divideCtrl.forward(from: 0.0);

    _scaffold?.clearSnackBars();
    _scaffold?.showSnackBar(
      SnackBar(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        content: Text('Deleted "${removed.name}"',
            style: const TextStyle(color: Colors.white)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: BudgetTheme.mint,
          onPressed: () {
            if (!mounted) return;
            _ctrl.addCategory(removed);
            _sweepCtrl.forward(from: 0.0);
            _divideCtrl.forward(from: 0.0);
          },
        ),
      ),
    );
  }

  void _deleteRecurring(int index) {
    if (index < 0 || index >= _ctrl.recurrings.length) return;
    final removed = _ctrl.removeRecurringAt(index);
    _sweepCtrl.forward(from: 0.0);
    _divideCtrl.forward(from: 0.0);
    _scaffold?.clearSnackBars();
    _scaffold?.showSnackBar(
      SnackBar(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        content: Text('Deleted "${removed.name}"',
            style: const TextStyle(color: Colors.white)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: BudgetTheme.mint,
          onPressed: () {
            if (!mounted) return;
            _ctrl.addRecurring(removed);
            _sweepCtrl.forward(from: 0.0);
            _divideCtrl.forward(from: 0.0);
          },
        ),
      ),
    );
  }

  bool get _canShowCompleteButton =>
      _ctrl.categories.isNotEmpty && _ctrl.recurrings.isNotEmpty;

  bool get _canSave =>
      _canShowCompleteButton &&
      _ctrl.monthlyAmount != null &&
      (_titleCtrl.text.trim().isNotEmpty);

  _TitleLayout _computeTitleLayout({
    required String text,
    required double maxWidth,
    required double maxFont,
    required double minFont,
    required int maxWrapLines,
  }) {
    if (text.isEmpty) {
      return const _TitleLayout(
        fontSize: _titleMaxFont,
        maxLines: 1,
        wrapped: false,
      );
    }
    final painter =
        TextPainter(textDirection: ui.TextDirection.ltr, maxLines: 1);

    bool fits(double font, int lines) {
      painter
        ..text = TextSpan(
          text: text,
          style: TextStyle(
            fontSize: font,
            fontWeight: FontWeight.w700,
            height: 1.05,
            letterSpacing: 0.2,
          ),
        )
        ..maxLines = lines
        ..layout(maxWidth: maxWidth);
      return !(painter.didExceedMaxLines || painter.size.width > maxWidth);
    }

    double f = maxFont;
    while (f > minFont && !fits(f, 1)) f -= 1;
    if (fits(f, 1)) {
      return _TitleLayout(fontSize: f, maxLines: 1, wrapped: false);
    }
    final wrappedLines = math.max(2, maxWrapLines);
    return _TitleLayout(
        fontSize: minFont, maxLines: wrappedLines, wrapped: true);
  }

  void _saveChanges() {
    if (!_canSave || _budget == null) {
      HapticFeedback.heavyImpact();
      _scaffold?.clearSnackBars();
      _scaffold?.showSnackBar(
        const SnackBar(
          content: Text('Add a title, monthly amount, categories & recurring.'),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    final draft = _ctrl.toDraft();
    if (draft != null) {
      final provider = context.read<BudgetProvider>();
      provider.updateBudget(_budget!.id, draft); // persist via provider
      setState(() {
        _budget = _findBudget(provider); // refresh local cache
      });
      _scaffold?.clearSnackBars();
      _scaffold?.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.black87,
          content: Text('Budget saved.'),
        ),
      );
    }
  }

  Future<void> _confirmAndDeleteBudget() async {
    final provider = context.read<BudgetProvider>();
    final budget = _budget ?? _findBudget(provider);
    if (budget == null) return;

    final bool confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) {
            return AlertDialog(
              backgroundColor: BudgetTheme.bg,
              title: const Text(
                'Delete budget?',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              content: Text(
                'This will delete “${budget.title}”. This action can’t be undone.',
                style: const TextStyle(color: Colors.white70),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Delete',
                      style: TextStyle(color: Color(0xFFFF6B6B))),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    HapticFeedback.heavyImpact();
    await provider.removeBudget(budget.id);
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    // Keep in sync with provider state.
    final provider = context.watch<BudgetProvider>();
    final watched = _findBudget(provider);
    _budget = watched ?? _budget;

    if (_budget == null) {
      return Scaffold(
        backgroundColor: BudgetTheme.bg,
        appBar: AppBar(
          backgroundColor: BudgetTheme.bg,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text('Budget'),
        ),
        body: const Center(
          child: Text(
            'Budget not found.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    final media = MediaQuery.of(context);
    final topInset = media.size.height * _topInsetFraction;
    final showChart = _ctrl.monthlyAmount != null;
    final pillH = _pillSize?.height ?? 44.0);

    final areaHeight = showChart ? _ringSize : (pillH + _pillInitialTop);
    final pillTop = showChart ? (_ringSize - pillH) / 2 : _pillInitialTop;

    final allocation = _ctrl.hasAllocation
        ? _ctrl.buildAllocation(includeZeroCategories: true)
        : null;

    final List<BudgetCategory> legendCats;
    if (_ctrl.hasAllocation && allocation != null) {
      legendCats = _ctrl.categories
          .map((c) =>
              BudgetCategory(name: c.name, icon: Icons.circle, color: c.color))
          .toList();

      final rem = _ctrl.remainderCents();
      if (rem > 0) {
        legendCats.add(
          BudgetCategory(
            name: _ctrl.unallocatedAsSavings ? 'Savings' : 'Unallocated',
            icon: Icons.circle,
            color: BudgetTheme.unallocatedGray,
          ),
        );
      }
    } else {
      legendCats = _ctrl.categories;
    }

    final contentMaxW = math.min(media.size.width, 640.0);
    const horizontalPad = 20.0;
    final titleWidth = contentMaxW - horizontalPad * 2;

    final layout = _computeTitleLayout(
      text: _titleCtrl.text,
      maxWidth: titleWidth,
      maxFont: _titleMaxFont,
      minFont: _titleMinFont,
      maxWrapLines: _titleMaxLinesWhenWrapped,
    );

    final overCents = _ctrl.overageCents();

    return Scaffold(
      backgroundColor: BudgetTheme.bg,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Scrollable content (drawn first)
                Positioned.fill(
                  child: ScrollConfiguration(
                    behavior: NoGlowScrollBehavior(),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          SizedBox(height: topInset),

                          // Title line
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: horizontalPad),
                            child: TitleField(
                              controller: _titleCtrl,
                              focusNode: _titleFocus,
                              width: titleWidth,
                              fontSize: layout.fontSize,
                              maxLines: layout.maxLines,
                              autofocus: false,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(
                                    _maxTitleChars),
                              ],
                            ),
                          ),

                          AnimatedContainer(
                            duration: _layoutDuration,
                            curve: _layoutCurve,
                            height: showChart ? _chartTopPad : 0,
                          ),

                          // Chart area
                          Center(
                            child: AnimatedContainer(
                              duration: _layoutDuration,
                              curve: _layoutCurve,
                              height: areaHeight,
                              width: _ringSize,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  if (showChart)
                                    Align(
                                      alignment: Alignment.topCenter,
                                      child: ScaleTransition(
                                        scale: _ringScale,
                                        child: SizedBox.square(
                                          dimension: _ringSize,
                                          child: AnimatedBuilder(
                                            animation: Listenable.merge(
                                                [_sweep, _divide]),
                                            builder: (_, __) {
                                              if (!_ctrl.hasAllocation &&
                                                  _ctrl.categories.isEmpty) {
                                                final sweep = math.min(
                                                  _sweep.value * 2 * math.pi,
                                                  (2 * math.pi) - 1e-3,
                                                );
                                                return CustomPaint(
                                                  painter: RingPainter(
                                                    sweepRadians: sweep,
                                                    trackColor: Colors.white
                                                        .withValues(alpha: 0.10),
                                                    ringColor: BudgetTheme.mint,
                                                    stroke: _ringStroke,
                                                    cap: StrokeCap.round,
                                                  ),
                                                );
                                              }

                                              if (_ctrl.hasAllocation &&
                                                  allocation != null) {
                                                final totals =
                                                    _ctrl.buildAllocation(
                                                        includeZeroCategories:
                                                            true);
                                                final values = <double>[];
                                                final colors = <Color>[];

                                                for (final c
                                                    in _ctrl.categories) {
                                                  final item =
                                                      totals.items.firstWhere(
                                                    (i) => i.name == c.name,
                                                    orElse: () =>
                                                        AllocationItem(
                                                      name: c.name,
                                                      color: c.color,
                                                      cents: 0,
                                                    ),
                                                  );
                                                  values.add(
                                                      item.cents.toDouble());
                                                  colors.add(c.color);
                                                }
                                                final rem =
                                                    _ctrl.remainderCents();
                                                if (rem > 0) {
                                                  values.add(rem.toDouble());
                                                  colors.add(BudgetTheme
                                                      .unallocatedGray);
                                                }

                                                return CustomPaint(
                                                  painter:
                                                      ProportionalRingPainter(
                                                    values: values,
                                                    colors: colors,
                                                    progress: _sweep.value,
                                                    splitT: _divide.value,
                                                    stroke: _ringStroke,
                                                    trackColor: Colors.white
                                                        .withValues(alpha: 0.10),
                                                    gapRadians: 0.018,
                                                  ),
                                                );
                                              }

                                              // Equal slices (no allocation yet)
                                              return CustomPaint(
                                                painter: CategoryRingPainter(
                                                  colors: _ctrl.categories
                                                      .map((c) => c.color)
                                                      .toList(),
                                                  progress: _sweep.value,
                                                  splitT: _divide.value,
                                                  stroke: _ringStroke,
                                                  trackColor: Colors.white
                                                      .withValues(alpha: 0.10),
                                                  gapRadians: 0.018,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Amount pill
                                  AnimatedPositioned(
                                    duration: _layoutDuration,
                                    curve: _layoutCurve,
                                    top: pillTop,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        key: _pillKey,
                                        child: Hero(
                                          tag: _kAmountHero,
                                          child: PillButton.primary(
                                            icon: Icons.payments_rounded,
                                            label: _ctrl.monthlyAmount == null
                                                ? 'Set amount'
                                                : _currencyFmt.format(
                                                    _ctrl.monthlyAmount),
                                            onTap: _openAmountPicker,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Over budget warning
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: (_ctrl.isOverBudget)
                                ? Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(20, 8, 20, 0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB00020)
                                            .withValues(alpha: 0.12),
                                        border: Border.all(
                                          color: const Color(0xFFB00020)
                                              .withValues(alpha: 0.35),
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                              Icons.warning_amber_rounded,
                                              size: 20,
                                              color: Color(0xFFFFCDD2)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Over budget by ${_currencyFmt.format(overCents / 100)}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: _openAmountPicker,
                                            child: const Text(
                                              'Edit amount',
                                              style: TextStyle(
                                                color: BudgetTheme.mint,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // Legend
                          AnimatedSize(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            child: (legendCats.isEmpty)
                                ? const SizedBox(height: 6)
                                : Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(20, 6, 20, 0),
                                    child:
                                        CategoryLegend(categories: legendCats),
                                  ),
                          ),

                          // Unallocated -> Savings toggle
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: (_ctrl.hasAllocation)
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 6),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: InkWell(
                                        onTap: () {
                                          _ctrl.toggleUnallocatedAsSavings();
                                          _divideCtrl.forward(from: 0);
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Checkbox(
                                              value: _ctrl.unallocatedAsSavings,
                                              onChanged: (v) {
                                                _ctrl
                                                    .toggleUnallocatedAsSavings(
                                                        v ?? false);
                                                _divideCtrl.forward(from: 0);
                                              },
                                              activeColor: BudgetTheme.mint,
                                              checkColor: Colors.black,
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Treat unallocated as savings',
                                              style: TextStyle(
                                                color: BudgetTheme.textMuted,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // Option group
                          AnimatedSwitcher(
                            duration: _pillsFadeDuration,
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: (showChart)
                                ? Padding(
                                    key: const ValueKey('utility_group'),
                                    padding: const EdgeInsets.only(
                                        top: 8, bottom: 6),
                                    child: FractionallySizedBox(
                                      widthFactor: 0.86,
                                      child: OptionGroup(
                                        categoriesExpanded: _categoriesExpanded,
                                        onTapCategories: _toggleCategories,
                                        onAddCategory: () =>
                                            _openCategoryCreator(),
                                        categories: _ctrl.categories,
                                        onEditCategory: (i) =>
                                            _openCategoryCreator(editIndex: i),
                                        onDeleteCategory: _deleteCategory,
                                        recurringExpanded: _recurringExpanded,
                                        onTapRecurring: _toggleRecurring,
                                        onAddRecurring: () =>
                                            _openRecurringCreator(),
                                        recurring: _ctrl.recurrings,
                                        onEditRecurring: (i) =>
                                            _openRecurringCreator(editIndex: i),
                                        onDeleteRecurring: _deleteRecurring,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // Save button
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _canShowCompleteButton
                                ? Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(20, 8, 20, 0),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: _canSave
                                              ? BudgetTheme.accent
                                              : Colors.white12,
                                          foregroundColor: _canSave
                                              ? Colors.black
                                              : Colors.white54,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        onPressed:
                                            _canSave ? _saveChanges : null,
                                        child: const Text(
                                          'Save changes',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          SizedBox(height: 24 + media.padding.bottom),
                        ],
                      ),
                    ),
                  ),
                ),

                // DELETE ICON (top-left, plain icon)
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    tooltip: 'Delete budget',
                    onPressed: _confirmAndDeleteBudget,
                    icon: const Icon(Icons.delete_outline),
                    color: BudgetTheme.mint,
                    splashRadius: 22,
                    padding: const EdgeInsets.all(8),
                  ),
                ),

                // Close X on top so it’s always tappable
                Positioned(
                  top: 8,
                  right: 8,
                  child: CloseFab(onTap: _handleCloseTap),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TitleLayout {
  const _TitleLayout(
      {required this.fontSize, required this.maxLines, required this.wrapped});
  final double fontSize;
  final int maxLines;
  final bool wrapped;
}
