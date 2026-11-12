import 'package:shared_preferences/shared_preferences.dart';
import '../domain/food_draft.dart';

/// Manual food drafts stay local; no server writes or photo upload.
class FoodDraftStore {
  const FoodDraftStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'fittrack_food_drafts_v1';

  FoodDraftCollection load() {
    final raw = preferences.getString(key);
    return raw == null
        ? const FoodDraftCollection([])
        : FoodDraftCollection.decode(raw);
  }

  Future<void> save(FoodDraftCollection collection) async {
    if (!await preferences.setString(key, collection.encode())) {
      throw StateError('Unable to save food drafts');
    }
  }
}
