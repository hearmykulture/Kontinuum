// lib/ui/workout/session_widgets/action_bar_widgets.dart
import 'package:flutter/material.dart';
import 'package:kontinuum/ui/workout/workout_editor_constants.dart';

const Color _kAccentGreen = Color(0xFF21D07A);
const Color _kCompleteShadow = Color(0x3322C55E);

class ActionBarRow extends StatefulWidget {
  const ActionBarRow({
    super.key,
    required this.notesIcon,
    required this.notesLabel,
    required this.notesActive,
    required this.onNotesTap,
    required this.onPlayTap,
    required this.onRewind15Tap,
    required this.onFwd15Tap,
    required this.onInfoTap,
    this.animateSplitOnMount = false,
    this.playing = false,
    this.showComplete = false,
    this.onCompleteTap,
    this.completeLabel = 'Complete',
  });

  final IconData notesIcon;
  final String notesLabel;
  final bool notesActive;
  final VoidCallback onNotesTap;
  final VoidCallback onPlayTap;
  final VoidCallback onRewind15Tap;
  final VoidCallback onFwd15Tap;
  final VoidCallback onInfoTap;
  final bool animateSplitOnMount;
  final bool playing;

  final bool showComplete;
  final VoidCallback? onCompleteTap;
  final String completeLabel;

  @override
  State<ActionBarRow> createState() => _ActionBarRowState();
}

class _ActionBarRowState extends State<ActionBarRow>
    with TickerProviderStateMixin {
  static const _btnSize = 52.0;
  static const _gap = 18.0;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = !widget.animateSplitOnMount;
    if (widget.animateSplitOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 90));
        if (mounted) setState(() => _expanded = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = SessionActionButton(
      icon: widget.notesIcon,
      label: widget.notesLabel,
      onTap: widget.onNotesTap,
      active: widget.notesActive,
    );

    final play = PlaySquareButton(
      onTap: widget.onPlayTap,
      playing: widget.playing,
    );

    final info = SessionActionButton(
      icon: Icons.info_outline_rounded,
      label: 'Exercise details',
      onTap: widget.onInfoTap,
    );

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        notes,
        const SizedBox(width: _gap),
        RevealSlot(
          show: _expanded,
          width: _btnSize,
          child:
              const Skip15Button(forward: false).withTap(widget.onRewind15Tap),
        ),
        const RevealGap(show: true, width: _gap).copyWith(show: _expanded),
        play,
        const RevealGap(show: true, width: _gap).copyWith(show: _expanded),
        RevealSlot(
          show: _expanded,
          width: _btnSize,
          child: const Skip15Button(forward: true).withTap(widget.onFwd15Tap),
        ),
        const SizedBox(width: _gap),
        info,
      ],
    );

    final bool showCompletePill =
        widget.showComplete && widget.onCompleteTap != null;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: IntrinsicHeight(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1.0).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: showCompletePill
                    ? _CompletePill(
                        key: const ValueKey('complete-pill'),
                        label: widget.completeLabel,
                        onTap: widget.onCompleteTap!, // non-null when visible
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('complete-pill-hidden'),
                      ),
              ),
              if (showCompletePill) const SizedBox(height: 4),
              row,
            ],
          ),
        ),
      ),
    );
  }
}

class RevealSlot extends StatelessWidget {
  const RevealSlot({
    super.key,
    required this.show,
    required this.width,
    required this.child,
  });

  final bool show;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: show ? width : 0,
      height: 52,
      alignment: Alignment.center,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        opacity: show ? 1 : 0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          scale: show ? 1 : 0.85,
          child: child,
        ),
      ),
    );
  }
}

class RevealGap extends StatelessWidget {
  const RevealGap({super.key, required this.show, required this.width});
  final bool show;
  final double width;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: show ? width : 0,
    );
  }

  RevealGap copyWith({bool? show, double? width}) =>
      RevealGap(show: show ?? this.show, width: width ?? this.width);
}

class SessionActionButton extends StatelessWidget {
  const SessionActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    final Color foreColor = active
        ? Colors.black87
        : Colors.black.withValues(alpha: enabled ? 0.85 : 0.35);
    final Color background = active
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: enabled ? 0.06 : 0.03);
    final Color borderColor = Colors.black.withValues(
      alpha: active ? 0.20 : (enabled ? 0.12 : 0.06),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTapHint: enabled ? 'Activate' : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: foreColor),
        ),
      ),
    );
  }
}

class PlaySquareButton extends StatelessWidget {
  const PlaySquareButton({
    super.key,
    required this.onTap,
    required this.playing,
  });

  final VoidCallback onTap;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: playing ? 'Pause' : 'Start workout',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _kAccentGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Skip buttons with the plain rotate icon (badge removed).
class Skip15Button extends StatelessWidget {
  const Skip15Button({super.key, required this.forward});
  final bool forward;

  @override
  Widget build(BuildContext context) {
    final Color foreColor = Colors.black.withValues(alpha: 0.9);
    final Color background = Colors.black.withValues(alpha: 0.06);
    final Color borderColor = Colors.black.withValues(alpha: 0.12);
    final IconData baseIcon =
        forward ? Icons.rotate_right_rounded : Icons.rotate_left_rounded;
    final Offset nudge =
        forward ? const Offset(-2.0, -1.0) : const Offset(2.0, -1.0);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: Transform.translate(
        offset: nudge,
        child: Icon(baseIcon, size: 24, color: foreColor),
      ),
    );
  }
}

class _CompletePill extends StatelessWidget {
  const _CompletePill({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _kAccentGreen,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: _kCompleteShadow,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TappableSkip15 extends StatelessWidget {
  const _TappableSkip15(this.child, this.onTap);
  final Skip15Button child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: child.forward ? 'Fast-forward 15 seconds' : 'Rewind 15 seconds',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}

extension Skip15TapExt on Skip15Button {
  Widget withTap(VoidCallback tap) => _TappableSkip15(this, tap);
}

/// Overview (reset/info buttons + play/resume)
class OverviewActionButton extends StatelessWidget {
  const OverviewActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    final Color foreColor = active
        ? Colors.white
        : Colors.white.withValues(alpha: enabled ? 0.85 : 0.35);
    final Color background = active
        ? kCardText.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: enabled ? 0.08 : 0.04);
    final Color borderColor = active
        ? kCardText.withValues(alpha: 0.38)
        : Colors.white.withValues(alpha: enabled ? 0.12 : 0.05);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTapHint: enabled ? 'Activate' : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: foreColor),
        ),
      ),
    );
  }
}

class OverviewPlayButton extends StatelessWidget {
  const OverviewPlayButton({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Start workout',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color:
                enabled ? _kAccentGreen : _kAccentGreen.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.play_arrow_rounded,
              size: 28, color: Colors.white),
        ),
      ),
    );
  }
}

enum OverviewActionBarMode { reset, notes }

class OverviewActionBarRow extends StatelessWidget {
  const OverviewActionBarRow({
    super.key,
    this.mode = OverviewActionBarMode.reset,
    this.onResetTap,
    this.resetEnabled = false,
    this.onNotesTap,
    this.notesEnabled = true,
    this.notesActive = false,
    this.notesIcon = Icons.sticky_note_2_outlined,
    this.notesLabel = 'Notes',
    this.onPlayTap,
    this.onInfoTap,
    this.showResumeButton = false,
    this.onResumeTap,
  });

  final OverviewActionBarMode mode;

  /// Reset/refresh pill on the left; only shown in reset mode.
  final VoidCallback? onResetTap;
  final bool resetEnabled;

  /// Notes pill on the left when mode == notes.
  final VoidCallback? onNotesTap;
  final bool notesEnabled;
  final bool notesActive;
  final IconData notesIcon;
  final String notesLabel;

  final VoidCallback? onPlayTap;
  final VoidCallback? onInfoTap;
  final bool showResumeButton;
  final VoidCallback? onResumeTap;

  @override
  Widget build(BuildContext context) {
    final bool resetAvailable = resetEnabled && onResetTap != null;
    final VoidCallback? effectiveResetTap = resetAvailable ? onResetTap : null;

    final bool notesAvailable = notesEnabled && onNotesTap != null;
    final bool effectiveNotesActive = notesAvailable && notesActive;

    final Widget leftPill;
    if (mode == OverviewActionBarMode.notes) {
      // Use the SAME visual style as the info button.
      leftPill = OverviewActionButton(
        icon: notesIcon,
        label: notesLabel,
        onTap: notesAvailable ? onNotesTap : null,
        active: effectiveNotesActive,
      );
    } else {
      leftPill = OverviewActionButton(
        icon: Icons.restart_alt_rounded,
        label: 'Reset session',
        onTap: effectiveResetTap,
        active: resetAvailable,
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leftPill,
            const SizedBox(width: 18),
            showResumeButton
                ? ResumeButton(onTap: onResumeTap)
                : OverviewPlayButton(onTap: onPlayTap),
            const SizedBox(width: 18),
            OverviewActionButton(
              icon: Icons.info_outline_rounded,
              label: 'Exercise details',
              onTap: onInfoTap,
            ),
          ],
        ),
      ),
    );
  }
}

class ResumeButton extends StatelessWidget {
  const ResumeButton({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Resume workout',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFFF1B73C)
                : const Color(0xFFF1B73C).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.play_arrow_rounded,
              size: 28, color: Colors.white),
        ),
      ),
    );
  }
}
