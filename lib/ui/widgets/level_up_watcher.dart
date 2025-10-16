// lib/ui/widgets/level_up_watcher.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/data/level_utils.dart';
import 'package:kontinuum/main.dart'; // navigatorKey
import 'package:kontinuum/ui/widgets/level_up_popup.dart';

const Color kTotalAccent = Colors.pinkAccent; // distinct color for TOTAL

class LevelUpWatcher extends StatefulWidget {
  final Widget child;
  const LevelUpWatcher({super.key, required this.child});

  @override
  State<LevelUpWatcher> createState() => _LevelUpWatcherState();
}

class _LevelUpWatcherState extends State<LevelUpWatcher> {
  ObjectiveProvider? _provider;

  late final VoidCallback _onTotalLevelUp = () {
    final p = _provider;
    if (p == null) return;

    final newLevel = p.levelUpNotifier.value;
    if (newLevel == null) return;

    // clear immediately to avoid re-entrancy
    p.levelUpNotifier.value = null;

    final navCtx = navigatorKey.currentContext ?? (mounted ? context : null);
    if (navCtx == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!(navigatorKey.currentState?.mounted ?? mounted)) return;
      showDialog(
        context: navCtx,
        builder: (_) => LevelUpPopup(
          label: "Total Level",
          level: newLevel,
          color: kTotalAccent, // ⬅️ was amber
          previousStats: p.previousStats,
          currentStats: p.stats,
        ),
      );
    });
  };

  late final VoidCallback _onCategoryLevelUp = () {
    final p = _provider;
    if (p == null) return;

    final category = p.categoryLevelUpNotifier.value;
    if (category == null) return;

    // clear immediately to avoid re-entrancy
    p.categoryLevelUpNotifier.value = null;

    final navCtx = navigatorKey.currentContext ?? (mounted ? context : null);
    if (navCtx == null) return;

    final color = _getColorForCategory(category.name);
    final level = LevelUtils.getCategoryLevelFromXp(category.xp);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!(navigatorKey.currentState?.mounted ?? mounted)) return;
      showDialog(
        context: navCtx,
        builder: (_) => LevelUpPopup(
          label: category.name,
          level: level,
          color: color,
          previousStats: p.previousStats,
          currentStats: p.stats,
        ),
      );
    });
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<ObjectiveProvider>();
    if (!identical(_provider, next)) {
      _provider?.levelUpNotifier.removeListener(_onTotalLevelUp);
      _provider?.categoryLevelUpNotifier.removeListener(_onCategoryLevelUp);

      _provider = next;
      _provider!.levelUpNotifier.addListener(_onTotalLevelUp);
      _provider!.categoryLevelUpNotifier.addListener(_onCategoryLevelUp);
    }
  }

  @override
  void dispose() {
    _provider?.levelUpNotifier.removeListener(_onTotalLevelUp);
    _provider?.categoryLevelUpNotifier.removeListener(_onCategoryLevelUp);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Color _getColorForCategory(String name) {
    switch (name.toLowerCase()) {
      case 'rapping':
        return Colors.redAccent;
      case 'production':
        return Colors.blueAccent;
      case 'health':
        return Colors.greenAccent;
      case 'knowledge':
        return Colors.deepPurpleAccent;
      case 'networking':
        return const Color(0xFF11A08D);
      default:
        return Colors.grey;
    }
  }
}
