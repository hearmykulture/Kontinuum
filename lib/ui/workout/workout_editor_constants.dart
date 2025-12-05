// lib/ui/workout/workout_editor_constants.dart
import 'package:flutter/material.dart';
import 'package:kontinuum/models/workout_models.dart';

const kEditorBg = Color(0xFF090A0E);
const kPrimaryText = Colors.white;
const kSecondaryText = Color(0xFFA5ACBD);
const kCardBg = Color(0xFF16171C);
const kCardText = Colors.white;
const kEditorSurface = Color(0xFF15161C);
const kEditorOutline = Color(0xFF252730);
const kEditorAccent = Color(0xFFFFC857);

class BlockTypeInfo {
  final String label;
  final String hint;
  const BlockTypeInfo(this.label, this.hint);
}

const Map<BlockType, BlockTypeInfo> blockTypeInfo = {
  BlockType.set: BlockTypeInfo('Set', 'Standard 3×10, 5×5, etc.'),
  BlockType.superset: BlockTypeInfo('Superset', 'Alternate 2 exercises'),
  BlockType.circuit: BlockTypeInfo('Circuit', '3+ moves in a loop'),
  BlockType.emom: BlockTypeInfo('EMOM', 'Every minute on the minute'),
  BlockType.amrap: BlockTypeInfo('AMRAP', 'As many reps/rounds as possible'),
};

const double kFooterH = 44.0;
const int kMaxWorkoutTitleChars = 48;

enum WeightUnit { kg, lb }

extension WeightUnitLabel on WeightUnit {
  String get label => switch (this) {
        WeightUnit.kg => 'kg',
        WeightUnit.lb => 'lb',
      };
}
