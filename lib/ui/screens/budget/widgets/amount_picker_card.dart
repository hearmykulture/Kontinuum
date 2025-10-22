import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/budget_theme.dart';

class AmountPickerCard extends StatefulWidget {
  const AmountPickerCard({
    super.key,
    required this.initial,
    required this.onCancel,
    required this.onConfirm,
  });

  final double initial;
  final VoidCallback onCancel;
  final ValueChanged<double> onConfirm;

  @override
  State<AmountPickerCard> createState() => _AmountPickerCardState();
}

class _AmountPickerCardState extends State<AmountPickerCard> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial.clamp(0, 20000);
  }

  String _fmt(double v) {
    final fmt = NumberFormat.currency(symbol: '\$');
    return fmt.format(v.round());
  }

  @override
  Widget build(BuildContext context) {
    final monthly = (100 * (_value / 100).round()).toDouble();
    final yearly = monthly * 12;
    final daily = monthly * 12 / 365.0;

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: BudgetTheme.bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Monthly budget',
            style: TextStyle(
              color: BudgetTheme.mintDim,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _fmt(monthly),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          _Stat(label: 'Yearly', value: _fmt(yearly)),
          const SizedBox(height: 8),
          _Stat(label: 'Per day', value: _fmt(daily)),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: BudgetTheme.accent,
              inactiveTrackColor: BudgetTheme.accent.withOpacity(0.25),
              trackHeight: 6,
              thumbColor: BudgetTheme.accent,
              overlayColor: BudgetTheme.accent.withOpacity(0.18),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: _value,
              min: 0,
              max: 20000,
              divisions: 200,
              label: _fmt(monthly),
              onChanged: (v) => setState(() => _value = v),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onCancel,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: BudgetTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  onPressed: () => widget.onConfirm(monthly),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
