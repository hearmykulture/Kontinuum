// lib/ui/widgets/mission_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kontinuum/models/mission.dart';
import 'package:kontinuum/providers/mission_provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/data/level_utils.dart';
import 'package:kontinuum/ui/widgets/mission_detail_hero_popup.dart';
import 'package:kontinuum/ui/widgets/xp_gain_bottom_bar.dart'; // overlay

const Color kTotalAccent = Colors.pinkAccent; // distinct color for TOTAL

class MissionCard extends StatefulWidget {
  final Mission mission;
  const MissionCard({super.key, required this.mission});

  @override
  State<MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends State<MissionCard>
    with TickerProviderStateMixin {
  static const double _kBtnSize = 36;
  static const double _kIconSize = 22;
  static const double _kDoneIconSize = 28;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void triggerPulse() {
    _pulseController.forward().then((_) => _pulseController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    final mission = widget.mission;

    // Read-only providers (don’t subscribe whole card)
    final missionProvider =
        Provider.of<MissionProvider>(context, listen: false);
    final objectiveProvider =
        Provider.of<ObjectiveProvider>(context, listen: false);

    final rarityColor = _getRarityColor(mission);
    final isAccepted = mission.isAccepted && !mission.isCompleted;

    // ✅ Border switches to green when accepted
    final Color borderColor =
        isAccepted ? Colors.greenAccent : rarityColor.withAlpha(179);
    final double borderWidth = isAccepted ? 2.2 : 1.6;

    // Cheaper glow per rarity
    double blurForRarity;
    switch (mission.rarity) {
      case MissionRarity.common:
        blurForRarity = 0; // no glow for common
        break;
      case MissionRarity.rare:
        blurForRarity = 6;
        break;
      case MissionRarity.legendary:
        blurForRarity = 9;
        break;
    }

    final BoxShadow borderGlow = BoxShadow(
      color: (isAccepted ? Colors.greenAccent : rarityColor).withAlpha(77),
      blurRadius: blurForRarity,
    );

    return Hero(
      tag: mission.id,
      // Tiny, cheap in-flight hero to avoid moving the whole card layer
      flightShuttleBuilder: (ctx, anim, direction, fromCtx, toCtx) =>
          AnimatedBuilder(
        animation: anim,
        builder: (_, __) => Opacity(
          opacity: Curves.easeOut.transform(anim.value),
          child: Container(
            width: 120,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF161925),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: rarityColor.withOpacity(0.5), width: 1.2),
            ),
          ),
        ),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              barrierColor: Colors.transparent,
              pageBuilder: (_, __, ___) =>
                  MissionDetailHeroPopup(mission: mission),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: ScaleTransition(
            scale: _pulseAnimation,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isAccepted
                    ? const Color(0xFF202840)
                    : const Color(0xFF161925),
                border: Border.all(color: borderColor, width: borderWidth),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [borderGlow],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            if (mission.categoryIds.isNotEmpty)
                              Builder(
                                builder: (context) {
                                  final categoryId = mission.categoryIds.first;
                                  final xp = objectiveProvider
                                      .getCategoryXp(categoryId);
                                  final level =
                                      LevelUtils.getCategoryLevelFromXp(xp);
                                  final prestige =
                                      LevelUtils.getPrestigeTitle(level);
                                  final isRookie = level < 10;
                                  final displayNumeral = isRookie
                                      ? ''
                                      : " ${prestige.title.split(' ').last}";
                                  final prestigeColor =
                                      _getPrestigeColor(prestige.color);

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      "${categoryId.toUpperCase()}$displayNumeral",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: prestigeColor,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(height: 4),
                            // ⬇️ Cheaper than AutoSizeText (fixed size + 3 lines)
                            SizedBox(
                              height: 48,
                              child: Center(
                                child: Text(
                                  mission.title,
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: rarityColor,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${mission.rarity.name.toUpperCase()} • ${mission.xpReward} XP",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: rarityColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (mission.recommendedBySmartSuggestion)
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepPurpleAccent.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text("🧠",
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final offset = Tween<Offset>(
                        begin: const Offset(0.0, 0.35),
                        end: Offset.zero,
                      ).animate(animation);
                      return SlideTransition(
                        position: offset,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: _buildActionButtons(
                        mission, missionProvider, objectiveProvider),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    Mission mission,
    MissionProvider provider,
    ObjectiveProvider objective,
  ) {
    if (mission.isCompleted) {
      return Icon(
        Icons.check_circle,
        key: const ValueKey('done'),
        color: Colors.greenAccent,
        size: _kDoneIconSize,
      );
    }

    if (!mission.isAccepted) {
      return IconButton(
        key: const ValueKey('accept'),
        tooltip: "Accept",
        icon: Icon(Icons.check_circle_outline,
            color: Colors.black, size: _kIconSize),
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: _getRarityColor(mission),
          fixedSize: const Size(_kBtnSize, _kBtnSize),
          padding: EdgeInsets.zero,
        ),
        onPressed: _isProcessing
            ? null
            : () {
                if (provider.acceptedMissions.length >= 3) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("You can only accept 3 missions.")),
                  );
                } else {
                  setState(() => _isProcessing = true);
                  provider.acceptMission(mission);
                  triggerPulse();
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (mounted) setState(() => _isProcessing = false);
                  });
                }
              },
      );
    }

    return Row(
      key: const ValueKey('accepted'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // COMPLETE
        IconButton(
          tooltip: "Complete",
          icon: Icon(Icons.check, color: Colors.black, size: _kIconSize),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: Colors.greenAccent,
            fixedSize: const Size(_kBtnSize, _kBtnSize),
            padding: EdgeInsets.zero,
          ),
          onPressed: _isProcessing
              ? null
              : () {
                  setState(() => _isProcessing = true);

                  // Capture XP BEFORE mutating provider so overlay animates from -> to
                  String label = "TOTAL";
                  Color color = kTotalAccent;
                  int fromXp;
                  int toXp;

                  if (mission.categoryIds.isNotEmpty) {
                    final cat = mission.categoryIds.first;
                    label = cat.toUpperCase();
                    color = _categoryColor(cat);
                    fromXp = objective.getCategoryXp(cat);
                    toXp = fromXp + mission.xpReward;
                  } else {
                    fromXp = objective.totalXp;
                    toXp = fromXp + mission.xpReward;
                  }

                  // Apply completion (updates state)
                  provider.completeMission(mission);
                  triggerPulse();

                  // Show animated XP bar (holds briefly, then slides away)
                  XpGainBottomBar.show(
                    context,
                    label: label,
                    fromXp: fromXp,
                    toXp: toXp,
                    color: color,
                    holdDuration: const Duration(milliseconds: 1200),
                  );

                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (mounted) setState(() => _isProcessing = false);
                  });
                },
        ),
        const SizedBox(width: 6),

        // ABANDON
        IconButton(
          tooltip: "Abandon",
          icon: Icon(Icons.close, color: Colors.white, size: _kIconSize),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: Colors.redAccent,
            fixedSize: const Size(_kBtnSize, _kBtnSize),
            padding: EdgeInsets.zero,
          ),
          onPressed: _isProcessing
              ? null
              : () {
                  setState(() => _isProcessing = true);
                  provider.abandonMission(mission);
                  triggerPulse();
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (mounted) setState(() => _isProcessing = false);
                  });
                },
        ),
      ],
    );
  }

  // ---- helpers ----
  Color _categoryColor(String name) {
    switch (name.toLowerCase()) {
      case 'rapping':
        return Colors.redAccent;
      case 'production':
        return Colors.blueAccent;
      case 'health':
        return Colors.greenAccent;
      case 'knowledge':
        return Colors.deepPurpleAccent;
      case 'networking':
        return Colors.teal;
      default:
        return Colors.amber;
    }
  }

  Color _getPrestigeColor(String colorName) {
    final c = colorName.toLowerCase();
    if (c == 'gray') return Colors.grey;
    if (c == 'white') return Colors.white;
    if (c == 'gold') return Colors.amberAccent;
    if (c == 'aqua') return Colors.cyanAccent;
    if (c == 'green') return Colors.greenAccent;
    if (c == 'blue') return Colors.blueAccent;
    if (c == 'red') return Colors.redAccent;
    if (c == 'purple') return Colors.deepPurpleAccent;
    if (c == 'pink') return Colors.pinkAccent;
    if (c == 'rainbow') return Colors.tealAccent;
    return Colors.white60;
  }

  Color _getRarityColor(Mission mission) {
    switch (mission.rarity) {
      case MissionRarity.common:
        return Colors.grey[300]!;
      case MissionRarity.rare:
        return Colors.cyanAccent;
      case MissionRarity.legendary:
        return Colors.deepPurpleAccent;
    }
  }
}
