// BudgetScreenV2: workout-dashboard style header (progress + carousel + divider)
// wired to the budget module, with the budget ring + cashflow section beneath.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/providers/budget_provider.dart';
import 'package:kontinuum/services/bank_link_service.dart';
import 'package:kontinuum/ui/budget/budget_screen_widget.dart';
import 'package:kontinuum/ui/screens/budget/budget_focus.dart';
import 'package:kontinuum/ui/screens/budget/create_budget_screen.dart';
import 'package:kontinuum/ui/screens/budget/models/budget_models.dart';
import 'package:kontinuum/ui/screens/budget/widgets/budget_ring_and_cashflow_section.dart';
import 'package:kontinuum/ui/widgets/corner_icons.dart';

class BudgetScreenV2 extends StatefulWidget {
  const BudgetScreenV2({
    super.key,
    this.onAddPressed,
    this.onGetStarted,
    this.onExpandCompleted,
    this.ringPageJumpSignal,
    this.focusSignal,
    this.billFocusSignal,
  });

  final VoidCallback? onAddPressed;
  final VoidCallback? onGetStarted;
  final VoidCallback? onExpandCompleted;
  final ValueNotifier<int?>? ringPageJumpSignal;
  final ValueNotifier<BudgetFocusTarget?>? focusSignal;
  final ValueNotifier<BudgetBillFocus?>? billFocusSignal;

  static const Color kBudgetGreen = Color(0xFF051F20); // page bg
  static const Color kButtonGreen = Color(0xFF0B2B26); // square & expanded
  static const Color kPlusMint = Color(0xFFDAF1DE); // icon & text

  @override
  State<BudgetScreenV2> createState() => _BudgetScreenV2State();
}

class _BudgetScreenV2State extends State<BudgetScreenV2> {
  // Debug defaults for Plaid/Link; replace with real env if available.
  static const String _kDebugBaseUrl = 'http://localhost:4000';
  static const String _kDebugUserId = '9892ccbcfe3a4f79bf02147527c3fb61';

  DateTime _selectedDate = DateTime.now();
  String? _selectedBudgetId;
  bool _showStats = false;

  late final BankLinkService _bankLinkService;

  @override
  void initState() {
    super.initState();
    _bankLinkService = BankLinkService(
      baseUrl: _kDebugBaseUrl,
      userId: _kDebugUserId,
    );
  }

  double _budgetProgressForDay(DateTime day) {
    if (_selectedBudgetId == null) return 0.0;
    final provider = context.read<BudgetProvider>();
    final budget = provider.byId(_selectedBudgetId!);
    if (budget == null) return 0.0;

    switch (budget.cadence) {
      case BudgetTimeSpan.weekly:
        final weekdayIndex = (day.weekday - DateTime.monday) % 7;
        final progress = (weekdayIndex + 1) / 7;
        return progress.clamp(0.0, 1.0);
      case BudgetTimeSpan.monthly:
        final daysInMonth = _daysInMonth(day.year, day.month);
        final progress = day.day / daysInMonth;
        return progress.clamp(0.0, 1.0);
      case BudgetTimeSpan.yearly:
        final startOfYear = DateTime(day.year, 1, 1);
        final totalDays =
            DateTime(day.year + 1, 1, 1).difference(startOfYear).inDays;
        final elapsed = day.difference(startOfYear).inDays + 1;
        final progress = elapsed / math.max(1, totalDays);
        return progress.clamp(0.0, 1.0);
      case BudgetTimeSpan.custom:
        final daysInMonth = _daysInMonth(day.year, day.month);
        final progress = day.day / daysInMonth;
        return progress.clamp(0.0, 1.0);
    }
  }

  int _daysInMonth(int year, int month) {
    final date = DateTime(year, month + 1, 0);
    return date.day;
  }

  void _maybePrimeSelection(List<Budget> budgets) {
    final hasSelection = _selectedBudgetId != null &&
        budgets.any((b) => b.id == _selectedBudgetId);
    if (hasSelection) return;

    if (budgets.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedBudgetId = budgets.first.id);
      });
    } else if (_selectedBudgetId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedBudgetId = null);
      });
    }
  }

  Future<void> _openCreateOrEditBudget({Budget? initial}) async {
    final draft = await Navigator.of(context).push<BudgetDraft>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: BudgetScreenV2.kButtonGreen,
          appBar: AppBar(
            backgroundColor: BudgetScreenV2.kButtonGreen,
            elevation: 0,
            iconTheme: const IconThemeData(color: BudgetScreenV2.kPlusMint),
            title: Text(
              initial == null ? 'Create Budget' : 'Edit Budget',
              style: const TextStyle(
                color: BudgetScreenV2.kPlusMint,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
          body: SafeArea(
            child: CreateBudgetScreen(
              initial: initial?.toDraft(),
              onClose: () => Navigator.of(context).maybePop(),
              onComplete: (draft) => Navigator.of(context).pop(draft),
            ),
          ),
        ),
      ),
    );

    if (!mounted || draft == null) return;
    final provider = context.read<BudgetProvider>();

    if (initial == null) {
      final created = await provider.createBudget(draft);
      setState(() => _selectedBudgetId = created.id);
    } else {
      final updated = await provider.updateBudget(initial.id, draft);
      if (updated != null) {
        setState(() => _selectedBudgetId = updated.id);
      }
    }
  }

  void _linkBankAccount() {
    HapticFeedback.selectionClick();
    _bankLinkService.openLink(
      onSuccess: (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank linked successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      onError: (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Link failed: ${err.message ?? err.code ?? 'unknown'}',
            ),
          ),
        );
      },
    );
  }

  void _closeBudgetScreen() {
    HapticFeedback.selectionClick();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final budgets = context.watch<BudgetProvider>().budgets;
    _maybePrimeSelection(budgets);

    final Budget? selectedBudget = _selectedBudgetId == null
        ? null
        : context.read<BudgetProvider>().byId(_selectedBudgetId!);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: BudgetScreenV2.kBudgetGreen,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: BudgetScreenV2.kBudgetGreen,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  // Header: calendar + budget carousel + divider (mirrors workout dashboard)
                  BudgetScreenWidget(
                    selectedDate: _selectedDate,
                    getProgressForDay: _budgetProgressForDay,
                    onDateSelected: (date) =>
                        setState(() => _selectedDate = date),
                    carouselTwoRows: false,
                    carouselColumns: 4,
                    carouselCardColor: BudgetScreenV2.kButtonGreen,
                    carouselPadding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    carouselUnderlap: -24,
                    carouselTopBottomPad: 10,
                    carouselScrollbarBottomInset: 0,
                    enableScrollbar: true,
                    showDivider: true,
                    onCreateTap: () {
                      widget.onAddPressed?.call();
                      if (budgets.isEmpty) {
                        widget.onGetStarted?.call();
                      }
                      _openCreateOrEditBudget();
                    },
                    onBudgetSelected: (id) {
                      setState(() => _selectedBudgetId = id);
                    },
                    selectedBudgetId: _selectedBudgetId,
                  ),
                  const SizedBox(height: 6),
                  if (_selectedBudgetId != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: BudgetRingSection(
                        selectedBudgetId: _selectedBudgetId,
                        bankLinkService: _bankLinkService,
                        showStats: _showStats,
                        onToggleStats: () =>
                            setState(() => _showStats = !_showStats),
                        pageJumpSignal: widget.ringPageJumpSignal,
                        focusSignal: widget.focusSignal,
                        billFocusSignal: widget.billFocusSignal,
                        onTapAmount: selectedBudget == null
                            ? null
                            : () => _openCreateOrEditBudget(
                                  initial: selectedBudget,
                                ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Text(
                        'Select or create a budget to see cash flow.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                ],
              ),
              CornerIcons(
                top: -12,
                leftIcon: Icons.account_balance,
                leftIconSize: 18,
                leftIconColor: Colors.white,
                onLeftPressed: _linkBankAccount,
                leftTooltip: 'Link bank',
                rightIcon: Icons.close,
                onRightPressed: _closeBudgetScreen,
                rightTooltip: 'Close',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
