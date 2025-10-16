// lib/ui/widgets/level_up_popup.dart
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:kontinuum/models/stat.dart';
import 'package:kontinuum/data/stat_repository.dart';

class LevelUpPopup extends StatefulWidget {
  final String label;
  final int level;
  final Color color;
  final Map<String, int> previousStats;
  final Map<String, Stat> currentStats;

  const LevelUpPopup({
    super.key,
    required this.label,
    required this.level,
    required this.color,
    required this.previousStats,
    required this.currentStats,
  });

  @override
  State<LevelUpPopup> createState() => _LevelUpPopupState();
}

class _LevelUpPopupState extends State<LevelUpPopup>
    with SingleTickerProviderStateMixin {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    // Compute stat changes for the expanded view
    final Map<String, int> statChanges = {};
    for (final entry in widget.currentStats.entries) {
      final id = entry.key;
      final current = entry.value.count;
      final previous = widget.previousStats[id] ?? 0;
      if (current > previous) {
        statChanges[id] = current - previous;
      }
    }

    final bg = const Color(0xFF0F1218);
    final border = widget.color;
    final glow = widget.color.withAlpha(64);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: border, width: 1.4),
          boxShadow: [BoxShadow(color: glow, blurRadius: 28, spreadRadius: 4)],
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          constraints: BoxConstraints(maxHeight: expanded ? 520 : 260),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title area (Stack keeps the X from pushing the headline)
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxTitleWidth = constraints.maxWidth - 64; // room for X
                  return Stack(
                    children: [
                      // Centered, autosizing headline (always centered)
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxTitleWidth),
                          child: AutoSizeText(
                            "${widget.label.toUpperCase()}\nLEVELED UP",
                            maxLines: 2,
                            minFontSize: 14, // slightly smaller floor
                            stepGranularity: 0.5,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: widget.color,
                              fontSize: 24, // slightly smaller headline
                              height: 1.06,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                      // Close button pinned to top-right
                      Positioned(
                        right: -6,
                        top: -6,
                        child: IconButton(
                          tooltip: 'Close',
                          splashRadius: 18,
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 14),

              // Level line (UPPERCASE)
              Text(
                "LEVEL ${widget.level}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(height: 18),

              // Primary action
              if (!expanded)
                SizedBox(
                  width: 280,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    onPressed: () => setState(() => expanded = true),
                    child: const Text("View Stat Gains"),
                  ),
                ),

              // Expanded stat changes
              if (expanded) ...[
                const SizedBox(height: 8),
                const Divider(color: Colors.white12, height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Stat Gains",
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (statChanges.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      "No stat changes this level.",
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: statChanges.length,
                      itemBuilder: (_, i) {
                        final id = statChanges.keys.elementAt(i);
                        final delta = statChanges[id]!;
                        final meta = StatRepository.getById(id);
                        final label = meta?.display ?? id;
                        final icon = meta?.emoji ?? "📈";
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Text(icon, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_upward,
                                color: Colors.greenAccent,
                                size: 18,
                              ),
                              Text(
                                "+$delta",
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    "Close",
                    style: TextStyle(
                      color: widget.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
