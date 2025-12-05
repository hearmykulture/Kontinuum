// lib/utils/level_utils.dart
import 'dart:math';

class PrestigeTier {
  final String title;
  final String color;
  const PrestigeTier(this.title, this.color);
}

class LevelProgress {
  final int level;
  final int levelStartXp;
  final int nextLevelXp;
  final int xpIntoLevel;
  final int levelSpan;
  final double progress;

  const LevelProgress({
    required this.level,
    required this.levelStartXp,
    required this.nextLevelXp,
    required this.xpIntoLevel,
    required this.levelSpan,
    required this.progress,
  });

  int get xpRemaining => (levelSpan - xpIntoLevel).clamp(0, levelSpan);
}

class LevelUtils {
  static const int maxLevel = 300;
  static const int categoryMaxXp = 600000; // 10,000 hours of XP minutes

  /// Curve knobs for the eased leveling experience.
  ///
  /// `_levelCurveBase` ensures the very first XP instantly nudges the player
  /// above level 1, while `_levelCurveExponent` (< 1.0) compresses the early
  /// game so low amounts of XP feel impactful before stretching back to the
  /// traditional 10,000-hour cap.
  static const double _levelCurveBase = 1 / maxLevel; // ties base to cap
  static const double _levelCurveExponent = 0.5873073654933278;

  // === CATEGORY LEVELING (fixed curve) ===
  static int getCategoryLevelFromXp(int xp) {
    final xpRatio = (max(0, xp) / categoryMaxXp).clamp(0.0, 1.0);
    return _levelFromXpRatio(xpRatio);
  }

  static int getXpForCategoryLevel(int level) {
    final ratio = _xpRatioFromLevel(level);
    final xpValue = (ratio * categoryMaxXp).floor();
    if (xpValue < 0) return 0;
    if (xpValue > categoryMaxXp) return categoryMaxXp;
    return xpValue;
  }

  static int getTotalLevelFromXp(int totalXp, int numCategories) {
    if (numCategories <= 0) return 1;
    final avgXp = max(0, totalXp) ~/ numCategories;
    return getCategoryLevelFromXp(avgXp);
  }

  static int getTotalXpForLevel(int level, int numCategories) {
    if (numCategories <= 0) return 0;
    final clamped = level.clamp(1, maxLevel);
    return getXpForCategoryLevel(clamped) * numCategories;
  }

  static LevelProgress getCategoryProgress(int xp) {
    return getProgress(xp: xp, maxXp: categoryMaxXp);
  }

  static LevelProgress getProgress({required int xp, required int maxXp}) {
    if (maxXp <= 0) {
      return const LevelProgress(
        level: 1,
        levelStartXp: 0,
        nextLevelXp: 0,
        xpIntoLevel: 0,
        levelSpan: 0,
        progress: 0.0,
      );
    }

    final safeXp = max(0, xp);
    final lvl = getLevelFromXp(safeXp, maxXp);
    final nextLevel = lvl >= maxLevel ? lvl : (lvl + 1);
    final startXp = getXpForLevel(lvl, maxXp);
    final nextXp = getXpForLevel(nextLevel, maxXp);
    final span = max(0, nextXp - startXp);
    final xpIntoLevel = span == 0
        ? 0
        : (safeXp - startXp).clamp(0, span).toInt();
    final prog = span == 0 ? 1.0 : xpIntoLevel / span;

    return LevelProgress(
      level: lvl,
      levelStartXp: startXp,
      nextLevelXp: nextXp,
      xpIntoLevel: xpIntoLevel,
      levelSpan: span,
      progress: prog,
    );
  }

  // === WEIGHT HELPERS ===
  /// Normalize a list of weights to sum to 1.0, replacing non-positive values
  /// with 1 before normalization. Keeps ordering intact.
  static List<double> normalizeWeights(List<double> weights) {
    if (weights.isEmpty) return const [];
    final cleaned = weights
        .map((w) => (w.isFinite && w > 0) ? w : 1.0)
        .toList(growable: false);
    final total = cleaned.fold<double>(0, (sum, w) => sum + w);
    if (total <= 0) {
      final even = 1.0 / cleaned.length;
      return List<double>.filled(cleaned.length, even, growable: false);
    }
    return cleaned.map((w) => w / total).toList(growable: false);
  }

  static int getSkillCap(double weight) {
    if (!weight.isFinite || weight <= 0) return 0;
    return categoryMaxXp * weight.round();
  }

  static int getStatCap(double skillWeight, double statWeight) {
    if (!skillWeight.isFinite || !statWeight.isFinite) return 0;
    if (skillWeight <= 0 || statWeight <= 0) return 0;
    return categoryMaxXp * skillWeight * statWeight.round();
  }

  // === DYNAMIC LEVELING (for Skill/Stat) ===
  static int getLevelFromXp(int xp, int maxXp) {
    if (maxXp <= 0) return 1;
    final xpRatio = (max(0, xp) / maxXp).clamp(0.0, 1.0);
    return _levelFromXpRatio(xpRatio);
  }

  static int getXpForLevel(int level, int maxXp) {
    if (maxXp <= 0) return 0;
    if (level <= 1) return 0;
    if (level >= maxLevel) return maxXp;
    final ratio = _xpRatioFromLevel(level);
    final xpValue = (ratio * maxXp).floor();
    if (xpValue < 0) return 0;
    if (xpValue > maxXp) return maxXp;
    return xpValue;
  }

  // === PRESTIGE TITLES ===
  static PrestigeTier getPrestigeTitle(int level) {
    final safe = max(1, level);
    const int levelsPerPrestige = 30;
    const int numeralsPerPrestige = 10; // I-X inside each prestige
    if (safe >= maxLevel) {
      return const PrestigeTier("Rainbow Prestige", "Rainbow");
    }

    final tier = ((safe - 1) ~/ levelsPerPrestige).clamp(0, 9);
    final levelsPerNumeral = levelsPerPrestige ~/ numeralsPerPrestige; // 3
    final subIndex = ((safe - 1) % levelsPerPrestige) ~/ levelsPerNumeral;
    final roman = _romanNumeralFromIndex(subIndex);

    switch (tier) {
      case 0:
        return PrestigeTier("Rookie $roman", "Gray");
      case 1:
        return PrestigeTier("Iron $roman", "White");
      case 2:
        return PrestigeTier("Gold $roman", "Gold");
      case 3:
        return PrestigeTier("Diamond $roman", "Aqua");
      case 4:
        return PrestigeTier("Emerald $roman", "Green");
      case 5:
        return PrestigeTier("Sapphire $roman", "Blue");
      case 6:
        return PrestigeTier("Ruby $roman", "Red");
      case 7:
        return PrestigeTier("Crystal $roman", "Purple");
      case 8:
        return PrestigeTier("Opal $roman", "Gray");
      case 9:
        return PrestigeTier("Amethyst $roman", "Pink");
      default:
        return const PrestigeTier("??", "Black");
    }
  }

  static int _levelFromXpRatio(double xpRatio) {
    final levelRatio = _levelRatioFromXp(xpRatio);
    final lvl = (levelRatio * maxLevel).floor();
    if (lvl < 1) return 1;
    if (lvl > maxLevel) return maxLevel;
    return lvl;
  }

  static double _levelRatioFromXp(double xpRatio) {
    final safeRatio = xpRatio.clamp(0.0, 1.0);
    final eased = pow(safeRatio, _levelCurveExponent).toDouble();
    return _levelCurveBase + (1 - _levelCurveBase) * eased;
  }

  static double _xpRatioFromLevel(int level) {
    final clamped = level.clamp(1, maxLevel);
    final levelRatio = clamped / maxLevel;
    if (levelRatio <= _levelCurveBase) {
      return 0.0;
    }
    final normalized = (levelRatio - _levelCurveBase) / (1 - _levelCurveBase);
    return pow(normalized, 1 / _levelCurveExponent)
        .toDouble()
        .clamp(0.0, 1.0);
  }

  static String _romanNumeralFromIndex(int index) {
    const numerals = [
      'I',
      'II',
      'III',
      'IV',
      'V',
      'VI',
      'VII',
      'VIII',
      'IX',
      'X',
    ];
    if (index < 0) return numerals.first;
    if (index >= numerals.length) return numerals.last;
    return numerals[index];
  }
}
