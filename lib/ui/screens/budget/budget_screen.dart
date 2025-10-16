import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import 'package:kontinuum/ui/widgets/month_progress_bar.dart';
import 'dialogs/category_dialog.dart';
import 'dialogs/recurring_dialog.dart';
import 'dialogs/daily_expense_dialog.dart';
import 'widgets/budget_overview.dart';
import 'widgets/budget_onboarding.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});
  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  // Storage
  Box<dynamic>? _box;

  // Onboarding state
  bool _loading = true;
  bool _onboarded = false;
  int _step = 0;

  // Selected day in header/month scroller
  DateTime _selectedDate = DateTime.now();

  // Data model
  int _monthlyBudget = 0;
  final List<Map<String, dynamic>> _categories = [];
  final List<Map<String, dynamic>> _recurring = [];

  /// Daily expenses: 'yyyy-MM-dd' => List<{id, name, amount, categoryId}>
  final Map<String, List<Map<String, dynamic>>> _daily = {};

  // Controllers
  final _budgetCtrl = TextEditingController();
  final ScrollController _overviewScroll = ScrollController();
  final GlobalKey _dailySectionKey = GlobalKey();

  // Theme bits
  static const _bg = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E1E);
  static const _accent = Colors.deepPurpleAccent;

  final _categoryColors = const [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.amber,
    Colors.cyanAccent,
    Colors.pinkAccent,
    Colors.tealAccent,
    Colors.deepPurpleAccent,
    Colors.orangeAccent,
  ];

  // ===== lifecycle =====
  @override
  void initState() {
    super.initState();
    _initBox();
  }

  Future<void> _initBox() async {
    final box = await Hive.openBox('budgetBox');
    final onboarded = box.get('onboarded', defaultValue: false) == true;
    final monthly = (box.get('monthlyBudget') ?? 0) as int;
    final categories = (box.get('categories') ?? []) as List;
    final recurring = (box.get('recurring') ?? []) as List;
    final dailyRaw = (box.get('daily') ?? {}) as Map;

    _box = box;
    _onboarded = onboarded;
    _monthlyBudget = monthly;
    _budgetCtrl.text = monthly > 0 ? monthly.toString() : '';

    _categories
      ..clear()
      ..addAll(categories.cast<Map>().map((m) => Map<String, dynamic>.from(m)));
    _recurring
      ..clear()
      ..addAll(recurring.cast<Map>().map((m) => Map<String, dynamic>.from(m)));
    _daily
      ..clear()
      ..addEntries(
        dailyRaw.entries.map(
          (e) => MapEntry(
            e.key.toString(),
            ((e.value as List?) ?? const [])
                .cast<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList(),
          ),
        ),
      );

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _overviewScroll.dispose();
    super.dispose();
  }

  // ===== helpers =====
  String _fmtCurrency(num value) =>
      NumberFormat.currency(symbol: '\$').format(value);

  String _genId() => DateTime.now().microsecondsSinceEpoch.toString();

  String _dayKey(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));

  List<Map<String, dynamic>> _dailyFor(DateTime d) =>
      List<Map<String, dynamic>>.from(_daily[_dayKey(d)] ?? const []);

  int _sumDailyFor(DateTime d) =>
      _dailyFor(d).fold<int>(0, (s, e) => s + (e['amount'] as int? ?? 0));

  int _sumDailyForMonth(DateTime d) {
    int total = 0;
    _daily.forEach((k, list) {
      try {
        final dt = DateTime.parse(k);
        if (dt.year == d.year && dt.month == d.month) {
          total += list.fold<int>(0, (s, e) => s + (e['amount'] as int? ?? 0));
        }
      } catch (_) {}
    });
    return total;
  }

  int _sumRecurring() =>
      _recurring.fold<int>(0, (sum, e) => sum + (e['amount'] as int? ?? 0));

  double _getProgressForDay(DateTime day) {
    if (_monthlyBudget <= 0) return 0.0;
    final dueThroughDay = _recurring.fold<int>(0, (sum, e) {
      final d = (e['day'] as int?) ?? 1;
      final amt = (e['amount'] as int?) ?? 0;
      return sum + (d <= day.day ? amt : 0);
    });
    return (dueThroughDay / _monthlyBudget).clamp(0.0, 1.0);
  }

  Future<void> _saveAll({bool markOnboarded = false}) async {
    if (_box == null) return;
    await _box!.put('monthlyBudget', _monthlyBudget);
    await _box!.put('categories', _categories);
    await _box!.put('recurring', _recurring);
    await _box!.put('daily', _daily);
    if (markOnboarded) {
      await _box!.put('onboarded', true);
      _onboarded = true;
    }
    if (mounted) setState(() {});
  }

  void _handleDateSelected(DateTime d) {
    setState(() => _selectedDate = d);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _dailySectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          alignment: 0.05,
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Small rounded icon button used for the overlaid controls
  Widget _overlayIcon({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Material(
      color: Colors.white10,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  // ===== dialog launchers =====
  Future<void> _showAddCategory({Map<String, dynamic>? existing}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CategoryDialog(
        palette: _categoryColors,
        existing: existing,
        accent: _accent,
      ),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        _categories.add({
          'id': _genId(),
          'name': result['name'],
          'cap': result['cap'],
          'color': result['color'],
        });
      } else {
        existing['name'] = result['name'];
        existing['cap'] = result['cap'];
        existing['color'] = result['color'];
      }
    });
    _saveAll();
  }

  Future<void> _showAddRecurring({Map<String, dynamic>? existing}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => RecurringDialog(
        categories: _categories,
        existing: existing,
        accent: _accent,
      ),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        _recurring.add({
          'id': _genId(),
          'name': result['name'],
          'amount': result['amount'],
          'day': result['day'],
          'categoryId': result['categoryId'],
        });
      } else {
        existing['name'] = result['name'];
        existing['amount'] = result['amount'];
        existing['day'] = result['day'];
        existing['categoryId'] = result['categoryId'];
      }
    });
    _saveAll();
  }

  Future<void> _showAddDailyExpense(DateTime forDate) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => DailyExpenseDialog(
        date: forDate,
        categories: _categories,
        accent: _accent,
      ),
    );
    if (result == null) return;

    final key = _dayKey(forDate);
    setState(() {
      _daily.update(
        key,
        (list) => [
          ...list,
          {
            'id': _genId(),
            'name': (result['name'] as String).trim().isEmpty
                ? 'Expense'
                : result['name'],
            'amount': result['amount'],
            'categoryId': result['categoryId'],
          },
        ],
        ifAbsent: () => [
          {
            'id': _genId(),
            'name': (result['name'] as String).trim().isEmpty
                ? 'Expense'
                : result['name'],
            'amount': result['amount'],
            'categoryId': result['categoryId'],
          },
        ],
      );
    });
    _saveAll();
    _handleDateSelected(forDate);
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                MonthProgressBar(
                  selectedDate: _selectedDate,
                  getProgressForDay: _getProgressForDay,
                  onDateSelected: _handleDateSelected,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _onboarded
                      ? BudgetOverview(
                          key: _dailySectionKey,
                          selectedDate: _selectedDate,
                          monthlyBudget: _monthlyBudget,
                          categories: _categories,
                          recurring: _recurring,
                          dailyFor: _dailyFor,
                          sumDailyFor: _sumDailyFor,
                          sumDailyForMonth: _sumDailyForMonth,
                          sumRecurring: _sumRecurring,
                          fmtCurrency: _fmtCurrency,
                          onAddDaily: () => _showAddDailyExpense(_selectedDate),
                          onDeleteDaily: (date, id) {
                            final k = _dayKey(date);
                            setState(() {
                              _daily[k]?.removeWhere((x) => x['id'] == id);
                            });
                            _saveAll();
                          },
                          onJumpToAddRecurring: () {
                            setState(() {
                              _onboarded = false;
                              _step = 2;
                            });
                          },
                          onJumpToEditCategories: () {
                            setState(() {
                              _onboarded = false;
                              _step = 1;
                            });
                          },
                        )
                      : BudgetOnboarding(
                          step: _step,
                          accent: _accent,
                          cardColor: _cardColor,
                          budgetCtrl: _budgetCtrl,
                          monthlyBudget: _monthlyBudget,
                          onMonthlyBudgetChanged: (v) {
                            _monthlyBudget = max(0, v);
                            _saveAll();
                            setState(() {});
                          },
                          categories: _categories,
                          categoryColors: _categoryColors,
                          onAddOrEditCategory: _showAddCategory,
                          onDeleteCategory: (cat) {
                            setState(() {
                              _categories.removeWhere(
                                (c) => c['id'] == cat['id'],
                              );
                              for (final r in _recurring) {
                                if (r['categoryId'] == cat['id'])
                                  r['categoryId'] = null;
                              }
                            });
                            _saveAll();
                          },
                          recurring: _recurring,
                          onAddOrEditRecurring: _showAddRecurring,
                          onDeleteRecurring: (rec) {
                            setState(() {
                              _recurring.removeWhere(
                                (x) => x['id'] == rec['id'],
                              );
                            });
                            _saveAll();
                          },
                          fmtCurrency: _fmtCurrency,
                          onClose: () => Navigator.of(context).maybePop(),
                          onBack: () => setState(() => _step -= 1),
                          onNext: () async {
                            await _saveAll();
                            setState(() => _step += 1);
                          },
                          onFinish: () async {
                            await _saveAll(markOnboarded: true);
                            if (!context.mounted) return; // ✅ fix linter
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Budget setup saved."),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Top overlay: back + (optional) gear
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _overlayIcon(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                    tooltip: 'Back',
                  ),
                  const Spacer(),
                  if (_onboarded)
                    _overlayIcon(
                      icon: Icons.settings_outlined,
                      onTap: () {
                        setState(() {
                          _step = 0;
                          _onboarded = false;
                        });
                      },
                      tooltip: 'Edit Setup',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
