import 'package:devicelocunlock/models/device_status_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static late SharedPreferences _prefs;

  static const String KEY_IMEI = 'device_imei';
  static const String KEY_IMEI_2 = 'device_imei_2';
  static const String KEY_FCM_TOKEN = 'fcm_token';
  static const String KEY_DEVICE_LOCKED = 'device_locked';
  static const String KEY_LOCK_REASON = 'lock_reason';
  static const String KEY_CUSTOMER_NAME = 'customer_name';
  static const String KEY_LOAN_STATUS = 'loan_status';
  static const String KEY_NEXT_DUE_DATE = 'next_due_date';
  static const String KEY_ADMIN_ACTIVE = 'admin_active';
  static const String KEY_DEVICE_ID = 'device_id';
  static const String KEY_DEVICE_TRACK_KEY = 'device_track_key';
  static const String KEY_DEVICE_STATUS_PROFILE = 'device_status_profile';
  static const String KEY_LOCK_REVISION = 'lock_revision';
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

  // IMEI 2
  static Future<void> setIMEI2(String imei) async {
    await _prefs.setString(KEY_IMEI_2, imei);
  }

  static String getIMEI2() {
    return _prefs.getString(KEY_IMEI_2) ?? '';
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

  // Save rich status/profile data from the API. The applied lock flag is
  // intentionally stored separately and is updated only after native policy
  // enforcement succeeds.
  static Future<void> saveDeviceProfile(DeviceStatusProfile profile) async {
    await _prefs.setString(KEY_DEVICE_STATUS_PROFILE, profile.toStorage());
    await _prefs.setInt(KEY_LOCK_REVISION, profile.lockRevision);

    if (profile.canonicalImei.isNotEmpty) {
      await _prefs.setString(KEY_IMEI, profile.canonicalImei);
    }
    await _prefs.setString(KEY_LOCK_REASON, profile.lockReason ?? '');
    await _prefs.setString(KEY_CUSTOMER_NAME, profile.customer?.name ?? '');
    await _prefs.setString(KEY_LOAN_STATUS, profile.loan?.status ?? '');
    await _prefs.setString(
      KEY_NEXT_DUE_DATE,
      profile.payment?.nextDueDate ?? profile.loan?.nextDueDate ?? '',
    );
  }

  static DeviceStatusProfile getDeviceProfile() {
    final cached = _prefs.getString(KEY_DEVICE_STATUS_PROFILE);
    if (cached != null && cached.isNotEmpty) {
      return DeviceStatusProfile.fromStorage(cached);
    }

    return DeviceStatusProfile(
      isLocked: isDeviceLocked(),
      lockRevision: _prefs.getInt(KEY_LOCK_REVISION) ?? 0,
      lockReason: getLockReason(),
      imei: getIMEI(),
      customer: CustomerDetails(
        name: getCustomerName(),
      ),
      loan: LoanDetails(
        status: _prefs.getString(KEY_LOAN_STATUS),
        nextDueDate: _prefs.getString(KEY_NEXT_DUE_DATE),
      ),
    );
  }

  // Backward-compatible adapter for older callers.
  static Future<void> saveLockData(Map<String, dynamic> data) async {
    await saveDeviceProfile(DeviceStatusProfile.fromJson(data));
  }

  static String getLockReason() => _prefs.getString(KEY_LOCK_REASON) ?? '';
  static String getCustomerName() => _prefs.getString(KEY_CUSTOMER_NAME) ?? '';
}
