// lib/ui/workout/session_widgets/stepper_widgets.dart
import 'package:flutter/material.dart';

const double kStepperBtnSize = 34;
const double kStepperGap = 12;
const double kValuePillWidth = 116;
const double kValuePillHeight = 36;

/// Simple horizontal stepper for doubles
class DoubleStepper extends StatelessWidget {
  const DoubleStepper({
    super.key,
    required this.label,
    required this.value,
    required this.step,
    required this.onChanged,
    this.min,
    this.max,
    this.fmt,
  });

  final String label;
  final double value;
  final double step;
  final ValueChanged<double> onChanged;
  final double? min;
  final double? max;
  final String Function(double)? fmt;

  Future<void> _prompt(BuildContext context) async {
    final controller = TextEditingController(text: value.toString());
    final res = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.0),
      builder: (ctx) => AlertDialog(
        title: const Text('Set load (lb)'),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(signed: false, decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (res == null) return;
    final v = double.tryParse(res);
    if (v == null) return;
    double newV = v;
    if (min != null) newV = newV < min! ? min! : newV;
    if (max != null) newV = newV > max! ? max! : newV;
    onChanged(newV);
  }

  @override
  Widget build(BuildContext context) {
    String display = fmt?.call(value) ?? value.toStringAsFixed(1);

    void bump(double delta) {
      double v = value + delta;
      if (min != null) v = v < min! ? min! : v;
      if (max != null) v = v > max! ? max! : v;
      onChanged(v);
    }

    // The inner Row is wrapped in FittedBox so it scales down instead of overflowing.
    final stepperRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RoundIconButton(
          icon: Icons.remove_rounded,
          onTap: () => bump(-step),
        ),
        const SizedBox(width: kStepperGap),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 80,
            maxWidth: kValuePillWidth,
          ),
          child: IntrinsicWidth(
            child: Container(
              height: kValuePillHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: InkWell(
                onTap: () => _prompt(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
                  ),
                  child: Text(
                    display,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: kStepperGap),
        RoundIconButton(
          icon: Icons.add_rounded,
          onTap: () => bump(step),
        ),
      ],
    );

    return LabeledRow(
      label: label,
      // Scale down on tight widths so we never overflow the slot.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: stepperRow,
      ),
    );
  }
}

/// Simple horizontal stepper for ints
class IntStepper extends StatelessWidget {
  const IntStepper({
    super.key,
    required this.label,
    required this.value,
    required this.step,
    required this.onChanged,
    this.min,
    this.max,
  });

  final String label;
  final int value;
  final int step;
  final ValueChanged<int> onChanged;
  final int? min;
  final int? max;

  Future<void> _prompt(BuildContext context) async {
    final controller = TextEditingController(text: value.toString());
    final res = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.0),
      builder: (ctx) => AlertDialog(
        title: const Text('Set reps'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            signed: false,
            decimal: false,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (res == null) return;
    final v = int.tryParse(res);
    if (v == null) return;
    int newV = v;
    if (min != null && newV < min!) newV = min!;
    if (max != null && newV > max!) newV = max!;
    onChanged(newV);
  }

  @override
  Widget build(BuildContext context) {
    void bump(int delta) {
      int v = value + delta;
      if (min != null && v < min!) v = min!;
      if (max != null && v > max!) v = max!;
      onChanged(v);
    }

    final stepperRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RoundIconButton(
          icon: Icons.remove_rounded,
          onTap: () => bump(-step),
        ),
        const SizedBox(width: kStepperGap),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 80,
            maxWidth: kValuePillWidth,
          ),
          child: IntrinsicWidth(
            child: Container(
              height: kValuePillHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: InkWell(
                onTap: () => _prompt(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
                  ),
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: kStepperGap),
        RoundIconButton(
          icon: Icons.add_rounded,
          onTap: () => bump(step),
        ),
      ],
    );

    return LabeledRow(
      label: label,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: stepperRow,
      ),
    );
  }
}

class LabeledRow extends StatelessWidget {
  const LabeledRow({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // The right side scales down when space is tight to prevent overflow.
          Flexible(
            flex: 5,
            child: Align(
              alignment: Alignment.centerRight,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: kStepperBtnSize,
        height: kStepperBtnSize,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: Colors.black.withValues(alpha: 0.85)),
      ),
    );
  }
}
