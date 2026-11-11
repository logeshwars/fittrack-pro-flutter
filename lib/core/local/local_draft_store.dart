import 'package:shared_preferences/shared_preferences.dart';

/// Local-only JSON storage. Not an offline synchronization mechanism.
class LocalDraftStore {
  const LocalDraftStore(this.preferences);
  final SharedPreferences preferences;

  String? read(String key) => preferences.getString(key);
  Future<void> write(String key, String value) async {
    if (!await preferences.setString(key, value)) {
      throw StateError('Failed to persist draft');
    }
  }
}
