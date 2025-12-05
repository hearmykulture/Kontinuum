// lib/ui/workout/workout_dashboard_header_footer.dart
part of 'workout_dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Centered header pill: keeps text centered regardless of trailing chevron.
// ─────────────────────────────────────────────────────────────────────────────
class _CenteredHeaderPill extends StatelessWidget {
  const _CenteredHeaderPill({
    required this.title,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final pillColor = const Color(0xFF161F2A).withValues(alpha: 0.55);

    return Material(
      color: pillColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onToggle,
        splashColor: Colors.white.withValues(alpha: .06),
        highlightColor: Colors.white.withValues(alpha: .03),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  child: AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ),
                const Positioned(
                  left: 6,
                  child: SizedBox(width: 18, height: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer controls
// ─────────────────────────────────────────────────────────────────────────────
class _FooterControls extends StatelessWidget {
  const _FooterControls({
    required this.onBack,
    required this.onProfile,
    required this.onAdd,

    /// Optional one-off rest override flow.
    /// When [showSkipToday] is true, we surface a "Skip today" button
    /// that asks for confirmation and then invokes [onSkipToday] if provided.
    this.onSkipToday,
    this.showSkipToday = false,
  });

  final VoidCallback onBack;
  final VoidCallback onProfile;
  final VoidCallback onAdd;

  final VoidCallback? onSkipToday;
  final bool showSkipToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: const Border(top: BorderSide(color: Color(0x1FFFFFFF))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _FooterIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              label: 'Back',
              onTap: onBack,
            ),
            if (showSkipToday)
              _FooterIconButton(
                icon: Icons.snooze_rounded,
                label: 'Skip today',
                onTap: () async {
                  final theme = Theme.of(context);
                  final bool confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF11151D),
                          title: const Text(
                            'Skip workout for today?',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          content: const Text(
                            "This will mark today as a one-off rest day. "
                            "Your recurring schedule won’t be changed.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Skip today'),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (confirmed && onSkipToday != null) {
                    onSkipToday!();
                  }
                },
              ),
            _FooterIconButton(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: onProfile,
            ),
            _FooterIconButton(
              icon: Icons.add_circle_outline,
              label: 'New',
              onTap: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterIconButton extends StatelessWidget {
  const _FooterIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
