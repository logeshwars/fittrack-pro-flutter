import '../../../core/data/data_gateway.dart';
import '../../workouts/domain/workout_metrics.dart';

const goals = ['bulk', 'cut', 'maintain'];

/// Port of `src/services/profileService.ts`.
class ProfileService {
  ProfileService(this._gateway);

  final DataGateway _gateway;

  Future<Json?> profile() => _gateway.cachedRow('profile', () async {
        final row = await _gateway.client
            .from('profiles')
            .select()
            .eq('google_user_id', _gateway.userId)
            .maybeSingle();
        return row == null ? null : Json.from(row);
      });

  /// Stores onboarding choices and the derived protein goal.
  Future<int> completeOnboarding({
    required String goal,
    required double bodyweightKg,
    double? heightCm,
  }) async {
    final proteinGoal = calculateProteinGoal(
      bodyweightKg: bodyweightKg,
      goal: goal,
      heightCm: heightCm,
    );
    await updateProfile({
      'goal': goal,
      'bodyweight_kg': bodyweightKg,
      if (heightCm != null) 'height_cm': heightCm,
      'protein_goal_g': proteinGoal,
    });
    return proteinGoal;
  }

  Future<void> updateProfile(Json fields) {
    const allowed = {
      'display_name',
      'bodyweight_kg',
      'height_cm',
      'goal',
      'protein_goal_g',
      'avatar_url',
    };
    final clean = {
      for (final e in fields.entries)
        if (allowed.contains(e.key)) e.key: e.value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    return _gateway.update(
      'profiles',
      _gateway.userId,
      clean,
      matchColumn: 'google_user_id',
    );
  }
}
