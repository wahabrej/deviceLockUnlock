import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  static const _tokenKey = "token";
  static const _userIdKey = "user_id";
  static const _userNameKey = "user_name";
  static const _userEmailKey = "user_email";
  static const _userRoleKey = "user_role";

  // --- Token Operations ---
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    debugPrint("💾 [Storage] Token saved: ${token.substring(0, 20)}...");
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    debugPrint("🔍 [Storage] Get Token: ${token != null ? "Found (${token.length} chars)" : "NULL"}");
    return token;
  }

  // --- User ID Operations ---
  Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // --- User Name Operations ---
  Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  // --- User Email Operations ---
  Future<void> saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userEmailKey, email);
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  // --- User Role Operations ---
  Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userRoleKey, role);
    debugPrint("💾 [Storage] Role saved: $role");
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(_userRoleKey);
    debugPrint("🔍 [Storage] Get Role: ${role ?? "NULL"}");
    return role;
  }

  // --- Clear Session (Logout) ---
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clears all saved data on logout
    debugPrint("🗑️ [Storage] All data cleared");
  }

  // --- Check if User is Logged In ---
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}