import 'dart:math';

class PrestigeTier {
  final String title;
  final String color;
  const PrestigeTier(this.title, this.color);
}

class LevelUtils {
  static const int maxLevel = 100;
  static const double categoryA = 60.0;

  /// === CATEGORY LEVELING (fixed curve) ===

  static int getCategoryLevelFromXp(int xp) {
    double level = sqrt(xp / categoryA);
    return level.clamp(1, maxLevel).toInt();
  }

  static int getXpForCategoryLevel(int level) {
    final clamped = level.clamp(1, maxLevel);
    return (categoryA * pow(clamped, 2)).toInt();
  }

  static int getTotalLevelFromXp(int totalXp, int numCategories) {
    if (numCategories == 0) return 1;
    final avgXp = totalXp ~/ numCategories;
    return getCategoryLevelFromXp(avgXp);
  }

  static int getTotalXpForLevel(int level, int numCategories) {
    if (numCategories == 0) return 0;
    return (categoryA * pow(level.clamp(1, maxLevel), 2) * numCategories)
        .toInt();
  }

  /// === DYNAMIC LEVELING (for Skill and Stat) ===

  static int getLevelFromXp(int xp, int maxXp) {
    if (maxXp == 0) return 1;
    final level = (xp / maxXp) * maxLevel;
    return level.clamp(1, maxLevel).toInt();
  }

  static int getXpForLevel(int level, int maxXp) {
    final clamped = level.clamp(1, maxLevel);
    return ((clamped / maxLevel) * maxXp).toInt();
  }

  /// === PRESTIGE TITLES ===

  static PrestigeTier getPrestigeTitle(int level) {
    final tier = level ~/ 10;
    final roman = _romanNumeral(level % 10);
    switch (tier) {
      case 0:
        return const PrestigeTier("Rookie", "Gray");
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
      case 10:
        return const PrestigeTier("Rainbow Prestige", "Rainbow");
      default:
        return const PrestigeTier("??", "Black");
    }
  }

  static String _romanNumeral(int digit) {
    switch (digit) {
      case 1:
        return 'I';
      case 2:
        return 'II';
      case 3:
        return 'III';
      case 4:
        return 'IV';
      case 5:
        return 'V';
      case 6:
        return 'VI';
      case 7:
        return 'VII';
      case 8:
        return 'VIII';
      case 9:
        return 'IX';
      default:
        return '';
    }
  }
}
