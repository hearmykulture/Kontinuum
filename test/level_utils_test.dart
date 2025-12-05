import 'package:flutter_test/flutter_test.dart';
import 'package:kontinuum/data/level_utils.dart';

void main() {
  group('Category curve', () {
    const maxXp = LevelUtils.categoryMaxXp;

    test('Level thresholds follow eased curve', () {
      expect(LevelUtils.getXpForCategoryLevel(2), 36);
      expect(LevelUtils.getXpForCategoryLevel(30), 11294);
      expect(LevelUtils.getXpForCategoryLevel(150), 183279);
      expect(LevelUtils.getXpForCategoryLevel(LevelUtils.maxLevel), maxXp);
    });

    test('XP converts back to the matching level', () {
      final xpFor150 = LevelUtils.getXpForCategoryLevel(150);
      expect(LevelUtils.getCategoryLevelFromXp(0), 1);
      expect(LevelUtils.getCategoryLevelFromXp(xpFor150), 150);
      expect(LevelUtils.getCategoryLevelFromXp(maxXp), LevelUtils.maxLevel);
      expect(LevelUtils.getCategoryLevelFromXp(maxXp * 2), LevelUtils.maxLevel);
    });

    test('Prestige tiers rotate every 30 levels', () {
      expect(LevelUtils.getPrestigeTitle(1).title.startsWith('Rookie'), isTrue);
      expect(LevelUtils.getPrestigeTitle(30).title.startsWith('Rookie'), isTrue);
      expect(LevelUtils.getPrestigeTitle(31).title.startsWith('Iron'), isTrue);
      expect(LevelUtils.getPrestigeTitle(300).title, 'Rainbow Prestige');
    });
  });

  group('Eased skill/stat helpers', () {
    const statMaxXp = 18750; // matches meditations/cardio stats

    test('Level lookups stay consistent with eased thresholds', () {
      expect(LevelUtils.getLevelFromXp(0, statMaxXp), 1);
      final xpFor2 = LevelUtils.getXpForLevel(2, statMaxXp);
      final xpFor3 = LevelUtils.getXpForLevel(3, statMaxXp);
      expect(xpFor2, greaterThan(0));
      expect(xpFor3, greaterThan(xpFor2));
      expect(LevelUtils.getLevelFromXp(xpFor2, statMaxXp), 2);
      expect(LevelUtils.getLevelFromXp(xpFor3, statMaxXp), 3);
    });

    test('XP thresholds clamp at max level', () {
      expect(LevelUtils.getXpForLevel(1, statMaxXp), 0);
      expect(LevelUtils.getXpForLevel(50, statMaxXp), lessThan(statMaxXp));
      expect(LevelUtils.getLevelFromXp(statMaxXp, statMaxXp), LevelUtils.maxLevel);
      expect(LevelUtils.getXpForLevel(LevelUtils.maxLevel, statMaxXp), statMaxXp);
      expect(LevelUtils.getXpForLevel(LevelUtils.maxLevel + 1, statMaxXp), statMaxXp);
    });
  });
}
