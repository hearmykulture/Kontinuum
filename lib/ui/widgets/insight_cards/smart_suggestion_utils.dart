import 'package:flutter/material.dart';
import 'package:kontinuum/models/category.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/widgets/insight_cards/suggestion_row.dart';

class SmartSuggestionUtils {
  static List<Widget> getSuggestions(
    ObjectiveProvider provider,
    Category category, {
    DateTime? start,
    DateTime? end,
  }) {
    final skills = provider.getSkillsForCategory(category.id);
    final allStats = skills.expand((s) => s.stats).toList();

    if (skills.isEmpty || allStats.isEmpty) {
      return const [
        SuggestionRow(
          icon: "📌",
          title: "No data yet",
          description: "Complete some objectives to unlock smart suggestions.",
        ),
      ];
    }

    if (allStats.every((s) => s.xp == 0)) {
      return const [
        SuggestionRow(
          icon: "📌",
          title: "No XP yet",
          description: "Complete tasks to unlock smart suggestions.",
        ),
      ];
    }

    final weakestStat = allStats.reduce((a, b) => a.xp < b.xp ? a : b);
    final lowestSkill = skills.reduce((a, b) => a.xp < b.xp ? a : b);
    final topSkill = skills.reduce((a, b) => a.xp > b.xp ? a : b);

    final totalSkillXp = skills.fold<int>(0, (sum, s) => sum + s.xp);
    final topPercent = totalSkillXp > 0
        ? (topSkill.xp / totalSkillXp * 100).round()
        : 0;

    final suggestions = <Widget>[
      SuggestionRow(
        icon: "📌",
        title: "Focus on '${weakestStat.label}'",
        description:
            "This stat has the lowest XP in ${category.name}. Consider giving it some love this week.",
      ),
      SuggestionRow(
        icon: "🧱",
        title: "Weakest Skill: '${lowestSkill.label}'",
        description:
            "Your '${lowestSkill.label}' skill is lagging behind. Try completing objectives tied to it to lift your overall level.",
      ),
    ];

    if (topPercent >= 70) {
      suggestions.add(
        SuggestionRow(
          icon: "📊",
          title: "Spread XP More Evenly",
          description:
              "Over $topPercent% of your XP is in '${topSkill.label}'. Try diversifying your focus for better category growth.",
        ),
      );
    } else {
      suggestions.add(
        const SuggestionRow(
          icon: "📊",
          title: "Great Balance!",
          description: "Your skill growth is well balanced — keep it up!",
        ),
      );
    }

    suggestions.add(
      const SuggestionRow(
        icon: "💡",
        title: "Micro-Mission",
        description:
            "Set a quick win around your weakest stat — consistent reps build mastery faster than perfection.",
      ),
    );

    return suggestions;
  }
}
