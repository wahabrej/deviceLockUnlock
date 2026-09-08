import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static late SharedPreferences _prefs;

  static const String KEY_IMEI = 'device_imei';
  static const String KEY_FCM_TOKEN = 'fcm_token';
  static const String KEY_DEVICE_LOCKED = 'device_locked';
  static const String KEY_LOCK_REASON = 'lock_reason';
  static const String KEY_CUSTOMER_NAME = 'customer_name';
  static const String KEY_LOAN_STATUS = 'loan_status';
  static const String KEY_NEXT_DUE_DATE = 'next_due_date';
  static const String KEY_ADMIN_ACTIVE = 'admin_active';
  static const String KEY_DEVICE_ID = 'device_id';
  static const String KEY_DEVICE_TRACK_KEY = 'device_track_key';
  static const String _configuredDeviceTrackKey = String.fromEnvironment(
    'DEVICE_TRACK_KEY',
    defaultValue: '',
  );

  // Static initialization - This MUST be called in main.dart
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (_configuredDeviceTrackKey.isNotEmpty) {
      await _prefs.setString(KEY_DEVICE_TRACK_KEY, _configuredDeviceTrackKey);
    }
  }

  // Device ID
  static Future<void> setDeviceId(String deviceId) async {
    await _prefs.setString(KEY_DEVICE_ID, deviceId);
  }

  static String getDeviceId() {
    return _prefs.getString(KEY_DEVICE_ID) ?? '';
  }

  static String getDeviceTrackKey() {
    return _prefs.getString(KEY_DEVICE_TRACK_KEY) ?? '';
  }

  // IMEI
  static Future<void> setIMEI(String imei) async {
    await _prefs.setString(KEY_IMEI, imei);
  }

  static String getIMEI() {
    return _prefs.getString(KEY_IMEI) ?? '';
  }

  // FCM Token
  static Future<void> setFCMToken(String token) async {
    await _prefs.setString(KEY_FCM_TOKEN, token);
  }

  static String? getFCMToken() {
    return _prefs.getString(KEY_FCM_TOKEN);
  }

  // Admin Status
  static Future<void> setAdminActive(bool active) async {
    await _prefs.setBool(KEY_ADMIN_ACTIVE, active);
  }

  static bool isAdminActive() {
    return _prefs.getBool(KEY_ADMIN_ACTIVE) ?? false;
  }

  // Lock Status
  static Future<void> setDeviceLocked(bool locked) async {
    await _prefs.setBool(KEY_DEVICE_LOCKED, locked);
  }

  static bool isDeviceLocked() {
    return _prefs.getBool(KEY_DEVICE_LOCKED) ?? false;
  }

  // Save Lock Data from API
  static Future<void> saveLockData(Map<String, dynamic> data) async {
    await _prefs.setBool(KEY_DEVICE_LOCKED, data['isLocked'] ?? false);
    await _prefs.setString(KEY_LOCK_REASON, data['lockReason'] ?? '');
    await _prefs.setString(KEY_CUSTOMER_NAME, data['customerName'] ?? '');
    await _prefs.setString(KEY_LOAN_STATUS, data['loanStatus'] ?? '');
    await _prefs.setString(KEY_NEXT_DUE_DATE, data['nextDueDate'] ?? '');
  }

  static String getLockReason() => _prefs.getString(KEY_LOCK_REASON) ?? '';
  static String getCustomerName() => _prefs.getString(KEY_CUSTOMER_NAME) ?? '';
}
