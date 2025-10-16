import 'package:kontinuum/models/objective.dart';
import 'objective_type_handler.dart';
import 'objective_type_handlers.dart';

ObjectiveTypeHandler getHandlerForType(ObjectiveType type) {
  switch (type) {
    case ObjectiveType.standard:
      return StandardObjectiveHandler();
    case ObjectiveType.tally:
      return TallyObjectiveHandler();
    case ObjectiveType.stopwatch:
      return StopwatchObjectiveHandler();
    case ObjectiveType.writingPrompt:
      return WritingPromptObjectiveHandler(); // ✅ fixed name
    case ObjectiveType.subtask:
      return SubtaskObjectiveHandler(); // ✅ fixed name
    case ObjectiveType.reflective:
      return ReflectiveObjectiveHandler(); // ✅ fixed name
  }
}
