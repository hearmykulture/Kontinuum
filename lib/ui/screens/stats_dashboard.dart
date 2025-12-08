import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/screens/stats_overview_panel.dart';
import 'package:kontinuum/ui/widgets/corner_icons.dart';

const Color _kStatsBg = Color(0xFF0A0A0B);

class StatsDashboard extends StatefulWidget {
  const StatsDashboard({super.key});

  @override
  State<StatsDashboard> createState() => _StatsDashboardState();
}

class _StatsDashboardState extends State<StatsDashboard> {
  int _selectedTab = 0; // 0 = Insight, 1 = Overview, 2 = Graph

  void _closeDashboard() {
    Navigator.of(context).maybePop();
  }

  void _showGoalsComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Goals coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kStatsBg,
      body: SafeArea(
        child: Container(
          color: _kStatsBg,
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 64),
                  Center(
                    child: ToggleButtons(
                      borderRadius: BorderRadius.circular(24),
                      isSelected: [
                        _selectedTab == 0,
                        _selectedTab == 1,
                        _selectedTab == 2,
                      ],
                      onPressed: (index) {
                        setState(() => _selectedTab = index);
                      },
                      selectedColor: Colors.black,
                      fillColor: Colors.orangeAccent,
                      color: Colors.white,
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text("🧠 Insight"),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text("🧭 Overview"),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text("📈 Graph"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Consumer<ObjectiveProvider>(
                      builder: (context, provider, _) {
                        if (_selectedTab == 0) return _buildInsightsView();
                        if (_selectedTab == 1) return const StatOverviewPanel();
                        return _buildGraphView();
                      },
                    ),
                  ),
                ],
              ),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.only(top: 11),
                  child: Center(
                    child: Text(
                      "📊 Stats Dashboard",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              CornerIcons(
                top: 0,
                leftIcon: Icons.emoji_events_outlined,
                leftIconColor: Colors.white,
                leftIconSize: 18,
                onLeftPressed: _showGoalsComingSoon,
                leftTooltip: 'Goals coming soon',
                rightIcon: Icons.close,
                onRightPressed: _closeDashboard,
                rightTooltip: 'Close',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInsightCard(title: "🔥 Most Active Stat", content: "Coming soon"),
        _buildInsightCard(
          title: "📈 Most Improved Stat",
          content: "Coming soon",
        ),
        _buildInsightCard(title: "🎯 XP Distribution", content: "Coming soon"),
        _buildInsightCard(
          title: "🏆 Recent Milestones",
          content: "Coming soon",
        ),
      ],
    );
  }

  Widget _buildGraphView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            "Graph Mode Coming Soon",
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard({required String title, required String content}) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orangeAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(content, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
