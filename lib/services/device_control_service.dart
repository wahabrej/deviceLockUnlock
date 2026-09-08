import 'dart:async';
import 'package:devicelocunlock/services/api_service.dart';
import 'package:devicelocunlock/services/shared_preferences_service.dart';
import 'package:flutter/material.dart';
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

  Timer? _syncTimer;
  final ApiService _apiService = ApiService();

  bool _isLocked = false;
  String _lockReason = "";
  DateTime? _lastManualActionTime;

  bool get isLocked => _isLocked;
  String get lockReason => _lockReason;

  Future<void> init() async {
    _isLocked = SharedPreferencesService.isDeviceLocked();
    _lockReason = SharedPreferencesService.getLockReason();

    await getDeviceId();
    await checkAdminStatus();

    // ব্যাকগ্রাউন্ডে ইন্টারনেট পারমিশন নিশ্চিত করা
    await requestIgnoreBatteryOptimizations();

    final imei = SharedPreferencesService.getIMEI();
    if (imei.isNotEmpty) {
      startLockStatusSync();
    }
  }

  // ব্যাটারি অপ্টিমাইজেশন অফ করার রিকোয়েস্ট (যাতে ব্যাকগ্রাউন্ডে ইন্টারনেট থাকে)
  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _controlsChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('⚠️ Error requesting battery optimization skip: $e');
    }
  }

  void startLockStatusSync() {
    _syncTimer?.cancel();
    debugPrint('🔄 [Sync] Starting periodic sync...');

    _syncTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await syncWithServer();
    });
  }

  Future<void> syncWithServer() async {
    final imei = SharedPreferencesService.getIMEI();
    if (imei.isEmpty) return;

    if (_lastManualActionTime != null &&
        DateTime.now().difference(_lastManualActionTime!).inSeconds < 60) {
      return;
    }

    try {
      final response = await _apiService.getLockStatus(imei);

      if (response != null && response['success'] == true) {
        final data = response['data'];
        if (data == null) return;

        final dynamic rawStatus = data['isLocked'] ?? data['is_locked'];
        bool serverLockStatus = false;

        if (rawStatus is bool) {
          serverLockStatus = rawStatus;
        } else if (rawStatus is int) {
          serverLockStatus = rawStatus == 1;
        } else if (rawStatus is String) {
          serverLockStatus =
              rawStatus.toLowerCase() == 'true' || rawStatus == '1';
        }

        if (serverLockStatus != _isLocked) {
          if (serverLockStatus) {
            await _executeLock();
          } else {
            await _executeUnlock();
          }
        }

        await SharedPreferencesService.saveLockData(data);
        _lockReason = data['lockReason']?.toString() ?? "";
      }
    } catch (e) {
      // ব্যাকগ্রাউন্ডে নেটওয়ার্ক এরর আসলে চুপচাপ থাকবে, ক্রাশ করবে না
      debugPrint('📡 [Sync] Background Sync suppressed error: $e');
    }
  }

  Future<bool> _executeLock() async {
    try {
      final bool result = await _controlsChannel.invokeMethod('lockDevice');
      if (result) {
        _isLocked = true;
        await SharedPreferencesService.setDeviceLocked(true);
        notifyListeners();
      }
      return result;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _executeUnlock() async {
    try {
      await _controlsChannel.invokeMethod('unlockDevice');
      _isLocked = false;
      await SharedPreferencesService.setDeviceLocked(false);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> lockDevice() async {
    _lastManualActionTime = DateTime.now();
    final bool result = await _executeLock();
    if (result) {
      final imei = SharedPreferencesService.getIMEI();
      if (imei.isNotEmpty) {
        await _apiService.trackDevice({
          'imei': imei,
          'isLocked': true,
          'status': 'locked_manual',
        });
      }
    }
    return result;
  }

  Future<bool> unlockDevice() async {
    _lastManualActionTime = DateTime.now();
    final bool result = await _executeUnlock();
    if (result) {
      final imei = SharedPreferencesService.getIMEI();
      if (imei.isNotEmpty) {
        await _apiService.trackDevice({
          'imei': imei,
          'isLocked': false,
          'status': 'active_manual',
        });
      }
    }
    return result;
  }

  Future<bool> isDeviceLocked() async =>
      SharedPreferencesService.isDeviceLocked();

  Future<bool> checkAdminStatus() async {
    try {
      final bool active = await _controlsChannel.invokeMethod('isAdminActive');
      await SharedPreferencesService.setAdminActive(active);
      return active;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isDeviceOwner() async {
    try {
      return await _controlsChannel.invokeMethod<bool>('isDeviceOwner') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> activateAdmin() async {
    try {
      await _controlsChannel.invokeMethod('activateAdmin');
      await Future.delayed(const Duration(seconds: 1));
      return await checkAdminStatus();
    } catch (e) {
      return false;
    }
  }

  // ✅ ডিভাইস ওনার বা অ্যাডমিন স্ট্যাটাস রিমুভ করার মেথড
  Future<void> removeManagement() async {
    try {
      await _controlsChannel.invokeMethod('removeManagement');
    } catch (e) {
      debugPrint('Error removing management: $e');
    }
  }

  Future<String> getDeviceId() async {
    try {
      final String id = await _controlsChannel.invokeMethod('getDeviceId');
      await SharedPreferencesService.setDeviceId(id);
      return id;
    } catch (_) {
      return 'UNKNOWN';
    }
  }

  Future<Map<String, dynamic>> getFullDeviceInfo() async {
    try {
      final Map<dynamic, dynamic>? info = await _deviceInfoChannel.invokeMethod(
        'getDeviceInfo',
      );
      return Map<String, dynamic>.from(info ?? {});
    } catch (e) {
      return {};
    }
  }
}
