import 'dart:async';

import 'package:devicelocunlock/models/device_status_profile.dart';
import 'package:devicelocunlock/services/api_service.dart';
import 'package:devicelocunlock/services/shared_preferences_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceControlService extends ChangeNotifier {
  static final DeviceControlService _instance =
      DeviceControlService._internal();
  static DeviceControlService get instance => _instance;
  DeviceControlService._internal();

  factory DeviceControlService() => _instance;

  static const MethodChannel _controlsChannel = MethodChannel(
    'com.example.devicelocunlock/controls',
  );
  static const MethodChannel _deviceInfoChannel = MethodChannel(
    'com.example.devicelocunlock/device',
  );

  final ApiService _apiService = ApiService();
  Timer? _syncTimer;
  bool _syncInProgress = false;
  bool _isLocked = false;
  bool _isDeviceOwner = false;
  DeviceStatusProfile _profile = const DeviceStatusProfile(isLocked: false);
  Map<String, dynamic> _localDeviceInfo = const {};
  DateTime? _lastSuccessfulSync;
  String? _syncError;

  bool get isLocked => _isLocked;
  bool get isDeviceOwner => _isDeviceOwner;
  DeviceStatusProfile get profile => _profile;
  Map<String, dynamic> get localDeviceInfo =>
      Map<String, dynamic>.unmodifiable(_localDeviceInfo);
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync;
  String? get syncError => _syncError;
  String get lockReason => _profile.lockReason ?? '';

  Future<void> init() async {
    _controlsChannel.setMethodCallHandler(_handleNativeMethodCall);
    _isLocked = SharedPreferencesService.isDeviceLocked();
    _profile = SharedPreferencesService.getDeviceProfile();

    _localDeviceInfo = await getFullDeviceInfo();
    _mergeLocalDeviceInfo();
    await getDeviceId();
    await checkDeviceOwnerStatus();

    if (_trackingImei.isNotEmpty) {
      startLockStatusSync();
    }
  }

  String get _trackingImei {
    final stored = SharedPreferencesService.getIMEI().trim();
    if (stored.isNotEmpty) return stored;
    return _profile.canonicalImei.trim();
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (call.method != 'lockStateChanged') return null;

    final arguments = call.arguments is Map
        ? Map<String, dynamic>.from(call.arguments as Map)
        : const <String, dynamic>{};
    final locked = _asBool(arguments['isLocked'] ?? arguments['is_locked']);
    final revision = _asInt(
      arguments['lockRevision'] ?? arguments['lock_revision'],
    );

    _isLocked = locked;
    await SharedPreferencesService.setDeviceLocked(locked);
    _profile = _profile.copyWith(
      isLocked: locked,
      lockRevision: revision == null || revision < _profile.lockRevision
          ? _profile.lockRevision
          : revision,
      lockReason: arguments['lockReason']?.toString(),
      lockMessage: arguments['lockMessage']?.toString(),
    );
    await SharedPreferencesService.saveDeviceProfile(_profile);
    notifyListeners();

    // Native FCM/service delivery carries only the command. Refresh immediately
    // to obtain the corresponding customer, loan and payment snapshot.
    unawaited(syncWithServer());
    return null;
  }

  void startLockStatusSync() {
    _syncTimer?.cancel();
    unawaited(syncWithServer());
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(syncWithServer());
    });
  }

  Future<void> syncWithServer() async {
    final imei = _trackingImei;
    if (imei.isEmpty || _syncInProgress) return;

    _syncInProgress = true;
    try {
      final serverProfile = await _apiService.getLockStatus(imei);
      if (serverProfile == null) {
        _syncError = 'Unable to refresh device status';
        return;
      }

      if (serverProfile.lockRevision > 0 &&
          _profile.lockRevision > serverProfile.lockRevision) {
        debugPrint(
          '[Sync] Ignored stale lock revision '
          '${serverProfile.lockRevision}; current is ${_profile.lockRevision}',
        );
        return;
      }

      final mergedProfile = _withLocalDeviceFallback(serverProfile);
      await _applyServerProfile(mergedProfile);
      _lastSuccessfulSync = DateTime.now();
      _syncError = null;
    } catch (error) {
      _syncError = 'Unable to refresh device status';
      debugPrint('[Sync] Status refresh failed: $error');
    } finally {
      _syncInProgress = false;
    }
  }

  Future<bool> applyServerProfile(DeviceStatusProfile profile) async {
    final mergedProfile = _withLocalDeviceFallback(profile);
    return _applyServerProfile(mergedProfile);
  }

  Future<bool> _applyServerProfile(DeviceStatusProfile nextProfile) async {
    _profile = nextProfile;
    await SharedPreferencesService.saveDeviceProfile(nextProfile);

    final applied = nextProfile.isLocked
        ? await _executeLock()
        : await _executeUnlock();

    if (!applied) {
      _syncError = nextProfile.isLocked
          ? 'Lock pending: this APK must be provisioned as Device Owner.'
          : 'Unlock is pending on the device.';
    }
    notifyListeners();
    return applied;
  }

  Future<bool> _executeLock() async {
    try {
      final result =
          await _controlsChannel.invokeMethod<bool>('lockDevice') ?? false;
      if (result) {
        _isLocked = true;
        await SharedPreferencesService.setDeviceLocked(true);
      }
      return result;
    } catch (error) {
      debugPrint('[DeviceControl] Native lock failed: $error');
      return false;
    }
  }

  Future<bool> _executeUnlock() async {
    try {
      final result =
          await _controlsChannel.invokeMethod<bool>('unlockDevice') ?? false;
      if (result) {
        _isLocked = false;
        await SharedPreferencesService.setDeviceLocked(false);
      }
      return result;
    } catch (error) {
      debugPrint('[DeviceControl] Native unlock failed: $error');
      return false;
    }
  }

  Future<bool> isDeviceLocked() async => _isLocked;

  Future<bool> checkDeviceOwnerStatus() async {
    try {
      _isDeviceOwner =
          await _controlsChannel.invokeMethod<bool>('isDeviceOwner') ?? false;
    } catch (_) {
      _isDeviceOwner = false;
    }
    notifyListeners();
    return _isDeviceOwner;
  }

  Future<bool> requestDeviceAdmin() async {
    try {
      return await _controlsChannel.invokeMethod<bool>('requestDeviceAdmin') ??
          false;
    } catch (error) {
      debugPrint('[DeviceControl] Device Admin request failed: $error');
      return false;
    }
  }

  Future<String> getDeviceId() async {
    try {
      final id =
          await _controlsChannel.invokeMethod<String>('getDeviceId') ?? '';
      if (id.isNotEmpty) {
        await SharedPreferencesService.setDeviceId(id);
      }
      return id;
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, dynamic>> getFullDeviceInfo() async {
    try {
      final info = await _deviceInfoChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getDeviceInfo',
      );
      return Map<String, dynamic>.from(info ?? const {});
    } catch (error) {
      debugPrint('[DeviceControl] Device info unavailable: $error');
      return {};
    }
  }

  Future<Map<String, dynamic>> refreshLocalDeviceInfo() async {
    _localDeviceInfo = await getFullDeviceInfo();
    _mergeLocalDeviceInfo();
    notifyListeners();
    return localDeviceInfo;
  }

  void _mergeLocalDeviceInfo() {
    _profile = _withLocalDeviceFallback(_profile);
  }

  DeviceStatusProfile _withLocalDeviceFallback(
    DeviceStatusProfile serverProfile,
  ) {
    final local = DeviceDetails.fromJson(_localDeviceInfo);
    final mergedDevice = serverProfile.device.merge(local);
    final canonicalImei = serverProfile.canonicalImei.isNotEmpty
        ? serverProfile.canonicalImei
        : SharedPreferencesService.getIMEI();
    return serverProfile.copyWith(
      imei: canonicalImei.isEmpty ? null : canonicalImei,
      device: mergedDevice,
    );
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'locked';
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
