import 'package:shared_preferences/shared_preferences.dart';

class UserIdStorage {
  static const _key = "user_id";

  /// Save User ID to SharedPreferences
  Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, userId);
  }

  /// Get stored User ID
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  /// Clear User ID from SharedPreferences
  Future<void> clearUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}