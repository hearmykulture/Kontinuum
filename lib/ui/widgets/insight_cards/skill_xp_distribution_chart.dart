import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kontinuum/models/skill.dart';
import 'package:kontinuum/models/stat.dart';

class SkillXpDistributionChart extends StatefulWidget {
  final List<Skill> skills;
  final List<Stat>? allStats;
  final Map<String, int>? xpDeltas;
  final String timeframe;

  const SkillXpDistributionChart({
    super.key,
    required this.skills,
    required this.timeframe,
    this.allStats,
    this.xpDeltas,
  });

  @override
  State<SkillXpDistributionChart> createState() =>
      _SkillXpDistributionChartState();
}

class _SkillXpDistributionChartState extends State<SkillXpDistributionChart> {
  bool showStats = false;
  int? selectedSkillIndex;
  late List<Color> _colorPool;
  final Map<String, Color> _colorCache = {};

  @override
  void initState() {
    super.initState();
    if (widget.skills.isNotEmpty) selectedSkillIndex = 0;
    _colorPool = [
      Colors.blueAccent,
      Colors.deepPurpleAccent,
      Colors.amber,
      Colors.tealAccent,
      Colors.greenAccent,
      Colors.redAccent,
      Colors.cyanAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSkills = widget.skills.isNotEmpty;
    final isStatMode =
        showStats &&
        selectedSkillIndex != null &&
        selectedSkillIndex! >= 0 &&
        selectedSkillIndex! < widget.skills.length;

    final List<dynamic> data = isStatMode
        ? widget.skills[selectedSkillIndex!].stats
        : widget.skills;

    final filteredData = data.where((item) {
      final xp = (item is Skill) ? item.xp : (item as Stat).xp;
      return xp > 0;
    }).toList();

    final totalXp = filteredData.fold<int>(
      0,
      (sum, item) => sum + ((item is Skill) ? item.xp : (item as Stat).xp),
    );

    if (filteredData.isEmpty || totalXp == 0) return _buildNoDataCard();

    final sections = _buildSections(filteredData, totalXp);

    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🧭 Chart title
            const Text(
              "🧭 XP Distribution",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.white,
              ),
            ),

            // 🔍 Stat label
            if (isStatMode)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '🔍 ${widget.skills[selectedSkillIndex!].label}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),

            // ⏱ Timeframe
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                _formatTimeframeLabel(widget.timeframe),
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),

            // 📊 Pie chart
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                  borderData: FlBorderData(show: false),
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!showStats &&
                          response?.touchedSection != null &&
                          response!.touchedSection!.touchedSectionIndex <
                              widget.skills.length) {
                        setState(
                          () => selectedSkillIndex =
                              response.touchedSection!.touchedSectionIndex,
                        );
                      }
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 🪄 Toggle button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  if (!showStats && selectedSkillIndex == null && hasSkills) {
                    setState(() => selectedSkillIndex = 0);
                  }
                  setState(() => showStats = !showStats);
                },
                child: Text(
                  showStats ? "View Skills" : "View Stats",
                  style: const TextStyle(color: Colors.deepPurpleAccent),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 🧷 Scrollable legend
            SizedBox(
              height: (filteredData.length * 22).clamp(40, 160).toDouble(),
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredData.length,
                itemBuilder: (context, index) {
                  final item = filteredData[index];
                  final String id = (item is Skill)
                      ? item.id
                      : (item as Stat).id;
                  final String label = (item is Skill)
                      ? item.label
                      : (item as Stat).label;

                  return Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getColor(id),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections(List<dynamic> data, int totalXp) {
    return data.map((item) {
      final String id = (item is Skill) ? item.id : (item as Stat).id;
      final int xp = (item is Skill) ? item.xp : (item as Stat).xp;
      final double percent = xp / totalXp;

      final grew = widget.xpDeltas?[id] != null && widget.xpDeltas![id]! > 0;

      return PieChartSectionData(
        value: percent * 100,
        color: grew ? Colors.greenAccent.shade200 : _getColor(id),
        radius: grew ? 56 : 48,
        title: percent < 0.05 ? '' : "${(percent * 100).toStringAsFixed(1)}%",
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
        badgeWidget: grew
            ? const Icon(Icons.trending_up, color: Colors.greenAccent, size: 14)
            : null,
        badgePositionPercentageOffset: 1.15,
      );
    }).toList();
  }

  Widget _buildNoDataCard() {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No XP data available yet.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Color _getColor(String id) {
    if (_colorCache.containsKey(id)) return _colorCache[id]!;
    final color = _colorPool[id.hashCode % _colorPool.length];
    _colorCache[id] = color;
    return color;
  }

  String _formatTimeframeLabel(String tf) {
    switch (tf) {
      case 'This Week':
      case 'Last 7 Days':
      case 'Last 30 Days':
      case 'All Time':
        return tf;
      default:
        return "Timeframe";
    }
  }
}
