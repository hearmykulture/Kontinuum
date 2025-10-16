import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/screens/stats_overview_panel.dart';

class StatsDashboard extends StatefulWidget {
  const StatsDashboard({super.key});

  @override
  State<StatsDashboard> createState() => _StatsDashboardState();
}

class _StatsDashboardState extends State<StatsDashboard> {
  int _selectedTab = 0; // 0 = Insight, 1 = Graph, 2 = Overview

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📊 Stats Dashboard"),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const SizedBox(height: 8),
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
                  child: Text("📈 Graph"),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("🧭 Overview"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Consumer<ObjectiveProvider>(
              builder: (context, provider, _) {
                if (_selectedTab == 0) return _buildInsightsView();
                if (_selectedTab == 1) return _buildGraphView();
                return const StatOverviewPanel();
              },
            ),
          ),
        ],
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
