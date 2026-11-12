import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fittrack_pro/features/nutrition/domain/food_draft.dart';
import 'package:fittrack_pro/features/nutrition/data/food_draft_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('validates manual nutrition input', () {
    const valid = FoodDraft(
        name: 'Rice', quantityG: 100, proteinG: 3, calories: 130, carbsG: 28);
    expect(valid.isValid, isTrue);
    expect(
        const FoodDraft(name: '', quantityG: 100, proteinG: 3, calories: 130)
            .isValid,
        isFalse);
    expect(
        const FoodDraft(name: 'Rice', quantityG: -1, proteinG: 3, calories: 130)
            .isValid,
        isFalse);
  });

  test('drafts persist locally and totals round-trip', () async {
    final store = FoodDraftStore(await SharedPreferences.getInstance());
    final collection = const FoodDraftCollection([]).add(const FoodDraft(
        name: 'Rice', quantityG: 100, proteinG: 3, calories: 130));
    await store.save(collection);
    expect(store.load().items.single.name, 'Rice');
    expect(store.load().totalCalories, 130);
    expect(store.load().remove(0).items, isEmpty);
  });
}
