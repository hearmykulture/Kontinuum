import 'package:flutter/material.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/ui/widgets/milestone_node.dart';
import 'package:provider/provider.dart';
import 'package:kontinuum/ui/screens/stat_insights_tab.dart';
import 'package:kontinuum/ui/screens/category_insights_tab.dart';

class MilestoneTreeScreen extends StatefulWidget {
  final String statId;

  const MilestoneTreeScreen({super.key, required this.statId});

  @override
  State<MilestoneTreeScreen> createState() => _MilestoneTreeScreenState();
}

class _MilestoneTreeScreenState extends State<MilestoneTreeScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 50), _scrollToFirstAchieved);
    });
  }

  void _scrollToFirstAchieved() {
    final provider = Provider.of<ObjectiveProvider>(context, listen: false);
    final milestone = provider.getMilestoneForStat(widget.statId);

    if (milestone == null) return;

    final currentCount = provider.stats.containsKey(widget.statId)
        ? provider.getStatCount(widget.statId)
        : provider.skills.containsKey(widget.statId)
        ? provider.skills[widget.statId]!.xp
        : provider.categories.containsKey(widget.statId)
        ? provider.categories[widget.statId]!.xp
        : 0;

    final thresholds = milestone.thresholds.reversed.toList();

    for (int i = 0; i < thresholds.length; i++) {
      if (milestone.isAchieved(currentCount, thresholds[i])) {
        _scrollController.animateTo(
          i * 90.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
        break;
      }
    }
  }

  String _formatLabel(String id) {
    return id
        .split(RegExp(r'[_\s]+'))
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ObjectiveProvider>(context);
    final milestone = provider.getMilestoneForStat(widget.statId);

    final currentCount = provider.stats.containsKey(widget.statId)
        ? provider.getStatCount(widget.statId)
        : provider.skills.containsKey(widget.statId)
        ? provider.skills[widget.statId]!.xp
        : provider.categories.containsKey(widget.statId)
        ? provider.categories[widget.statId]!.xp
        : 0;

    final label = _formatLabel(widget.statId);

    if (milestone == null) {
      return const Center(
        child: Text(
          'No milestones found.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final thresholds = milestone.thresholds.reversed.toList();

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: MediaQuery.of(context).size.width * 0.88,
        height: MediaQuery.of(context).size.height * 0.75,
        child: Material(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(24),
          elevation: 10,
          shadowColor: Colors.black87,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 4, top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        indicatorColor: Colors.deepPurpleAccent,
                        indicatorWeight: 3,
                        tabs: const [
                          Tab(text: 'Milestones'),
                          Tab(text: 'Insights'),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),

              // 🔁 TabBarView
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCategory = provider.categories.containsKey(
                      widget.statId,
                    );
                    final isStat = provider.stats.containsKey(widget.statId);
                    final isSkill = provider.skills.containsKey(widget.statId);

                    Widget insightsTab;

                    if (isCategory) {
                      insightsTab = CategoryInsightsTab(
                        categoryId: widget.statId,
                      );
                    } else if (isStat || isSkill) {
                      insightsTab = StatInsightsTab(statId: widget.statId);
                    } else {
                      insightsTab = const Center(
                        child: Text(
                          'No insights available',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        // Milestones Tab
                        SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 12,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                children: [
                                  const Center(
                                    child: Text(
                                      'MILESTONES',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4.0,
                                      bottom: 16.0,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'For: $label',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                  ...List.generate(thresholds.length, (index) {
                                    final threshold = thresholds[index];
                                    final achieved = milestone.isAchieved(
                                      currentCount,
                                      threshold,
                                    );
                                    return Column(
                                      children: [
                                        MilestoneNode(
                                          value: threshold,
                                          achieved: achieved,
                                        ),
                                        if (index < thresholds.length - 1)
                                          _MilestoneConnectorLine(),
                                        const SizedBox(height: 24),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Insights Tab (now robust)
                        insightsTab,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MilestoneConnectorLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade700,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
