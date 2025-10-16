import 'package:flutter/material.dart';

class SmartSuggestionCard extends StatelessWidget {
  final List<Widget> suggestions;
  final String? timeframe;

  const SmartSuggestionCard({
    super.key,
    required this.suggestions,
    this.timeframe,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasSuggestions = suggestions.isNotEmpty;

    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  "🧠 Smart Suggestions",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                if (timeframe != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      timeframe!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasSuggestions)
              Wrap(spacing: 8, runSpacing: 6, children: suggestions)
            // Option: Convert to ListView.builder if you plan many items
            // SizedBox(
            //   height: 150,
            //   child: ListView.builder(
            //     itemCount: suggestions.length,
            //     itemBuilder: (_, index) => suggestions[index],
            //   ),
            // )
            else
              const Text(
                "No suggestions right now. Keep progressing!",
                style: TextStyle(fontSize: 13, color: Colors.white54),
              ),
          ],
        ),
      ),
    );
  }
}
