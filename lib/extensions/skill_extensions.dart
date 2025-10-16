import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/models/stat.dart';

extension SkillStatHelpers on Skill {
  Stat? getStatById(String statId) {
    try {
      return stats.firstWhere((stat) => stat.id == statId);
    } catch (e) {
      return null;
    }
  }
}
