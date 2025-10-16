import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:kontinuum/providers/objective_provider.dart';

import 'package:kontinuum/ui/widgets/insight_cards/top_skills_card.dart';
import 'package:kontinuum/ui/widgets/insight_cards/category_xp_card.dart';
import 'package:kontinuum/ui/widgets/insight_cards/most_active_stat_card.dart';
import 'package:kontinuum/ui/widgets/insight_cards/milestones_hit_card.dart';
import 'package:kontinuum/ui/widgets/insight_cards/milestone_breakdown_card.dart';
import 'package:kontinuum/ui/widgets/insight_cards/next_milestone_card.dart';
import 'package:kontinuum/ui/widgets/insight_cards/smart_suggestion_card.dart';
import 'package:kontinuum/ui/widgets/insight_cards/smart_suggestion_utils.dart';
import 'package:kontinuum/ui/widgets/insight_cards/skill_xp_distribution_chart.dart'; // chart widget

class CategoryInsightsTab extends StatefulWidget {
  final String categoryId;

  const CategoryInsightsTab({super.key, required this.categoryId});

  @override
  State<CategoryInsightsTab> createState() => _CategoryInsightsTabState();
}

class _CategoryInsightsTabState extends State<CategoryInsightsTab> {
  String selectedTimeframe = 'All Time';
  bool showChart = false;

  final List<String> timeframes = [
    'All Time',
    'Last 7 Days',
    'Last 30 Days',
    'This Week',
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<ObjectiveProvider>(
      builder: (context, provider, _) {
        final category = provider.getCategoryById(widget.categoryId);
        final skills = provider.getSkillsForCategory(widget.categoryId);
        final sortedSkills = [...skills]..sort((a, b) => b.xp.compareTo(a.xp));
        final skillXpDeltas = provider.getSkillXpDelta(selectedTimeframe);

        final smartSuggestions = SmartSuggestionUtils.getSuggestions(
          provider,
          category,
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _sectionTitle("🔷 Core Metrics"),
                const Spacer(),
                _buildTimeframeDropdown(),
              ],
            ),

            TopSkillsCard(
              skills: sortedSkills,
              previousXpBySkill: skillXpDeltas,
              timeframe: selectedTimeframe,
            ),

            VisibilityDetector(
              key: const Key("skill-chart"),
              onVisibilityChanged: (info) {
                if (info.visibleFraction > 0.1 && !showChart) {
                  setState(() => showChart = true);
                }
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: showChart
                    ? SkillXpDistributionChart(
                        skills: sortedSkills,
                        allStats: provider.getStatsForCategory(
                          widget.categoryId,
                        ),
                        xpDeltas: skillXpDeltas,
                        timeframe: selectedTimeframe,
                      )
                    : const SizedBox(height: 200),
              ),
            ),

            CategoryXpCard(category: category, timeframe: selectedTimeframe),

            _sectionTitle("🔥 Activity"),

            MostActiveStatCard(
              categoryId: widget.categoryId,
              timeframe: selectedTimeframe,
            ),

            _sectionTitle("🎯 Milestone Info"),

            MilestonesHitCard(
              categoryId: widget.categoryId,
              timeframe: selectedTimeframe,
            ),

            MilestoneBreakdownCard(
              categoryId: widget.categoryId,
              timeframe: selectedTimeframe,
            ),

            NextMajorMilestoneCard(
              categoryId: widget.categoryId,
              timeframe: selectedTimeframe,
            ),

            _sectionTitle("🧠 Smart Suggestions"),

            SmartSuggestionCard(
              suggestions: smartSuggestions,
              timeframe: selectedTimeframe,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimeframeDropdown() {
    return DropdownButton<String>(
      value: selectedTimeframe,
      dropdownColor: const Color(0xFF1E1E1E),
      style: const TextStyle(color: Colors.white),
      items: timeframes
          .map(
            (t) => DropdownMenuItem(
              value: t,
              child: Text(t, style: const TextStyle(fontSize: 12)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null && value != selectedTimeframe) {
          setState(() => selectedTimeframe = value);
        }
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.orangeAccent,
        ),
      ),
    );
  }
}
