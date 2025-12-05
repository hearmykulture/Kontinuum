import 'package:kontinuum/providers/budget_provider.dart';
import 'package:kontinuum/providers/diet_provider.dart';
import 'package:kontinuum/providers/fitness_profile_provider.dart';
import 'package:kontinuum/providers/mission_provider.dart';
import 'package:kontinuum/providers/objective_provider.dart';
import 'package:kontinuum/providers/workout_provider.dart';
import 'package:kontinuum/providers/project_provider.dart';
import 'package:kontinuum/services/exercise_library_service.dart';

class ProviderRefreshService {
  const ProviderRefreshService();

  Future<void> refresh({
    ObjectiveProvider? objectiveProvider,
    MissionProvider? missionProvider,
    WorkoutProvider? workoutProvider,
    DietProvider? dietProvider,
    FitnessProfileProvider? fitnessProfileProvider,
    BudgetProvider? budgetProvider,
    ProjectProvider? projectProvider,
  }) async {
    // Order matters where dependencies exist.
    if (objectiveProvider != null) {
      await objectiveProvider.reloadFromStorage();
    }
    if (missionProvider != null) {
      await missionProvider.reloadFromStorage();
    }
    if (workoutProvider != null) {
      await workoutProvider.reloadFromStorage();
      // Ensure exercise library is reseeded if cleared.
      await ExerciseLibraryService.instance.ensureSeedLoaded();
    }
    if (dietProvider != null) {
      await dietProvider.reloadFromStorage();
    }
    if (fitnessProfileProvider != null) {
      await fitnessProfileProvider.reloadFromStorage();
    }
    if (budgetProvider != null) {
      await budgetProvider.reloadFromStorage();
    }
    projectProvider?.reset();
  }
}
