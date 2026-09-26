import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:devicelocunlock/models/device_status_profile.dart';
import 'package:devicelocunlock/services/shared_preferences_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'SMART_PAY_APK_API_BASE_URL',
    defaultValue: 'https://api.smartpay.click/apk',
  );
  static const String deviceTrackKey = String.fromEnvironment(
    'DEVICE_TRACK_KEY',
    defaultValue: '',
  );

  String get _deviceTrackKey {
    final storedKey = SharedPreferencesService.getDeviceTrackKey();
    return storedKey.isNotEmpty ? storedKey : deviceTrackKey;
  }

  Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json',
    if (_deviceTrackKey.isNotEmpty) 'x-device-key': _deviceTrackKey,
  };

  Future<DeviceStatusProfile?> trackDevice(
    Map<String, dynamic> deviceData,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/devices/track'),
            headers: _jsonHeaders,
            body: jsonEncode(deviceData),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _parseProfileResponse(response.body);
      }
      debugPrint(
        '[API] trackDevice failed: ${response.statusCode} ${response.body}',
      );
      return null;
    } catch (e) {
      debugPrint('❌ [API] trackDevice Error: $e');
      return null;
    }
  }

  Future<DeviceStatusProfile?> getLockStatus(String imei) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/devices/${Uri.encodeComponent(imei)}/lock-status',
            ),
            headers: _jsonHeaders,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return _parseProfileResponse(response.body);
      }
      debugPrint(
        '[API] getLockStatus failed: ${response.statusCode} ${response.body}',
      );
      return null;
    } on SocketException {
      debugPrint('🌐 [API] No Internet connection or server unreachable.');
      return null;
    } on TimeoutException {
      debugPrint('⏳ [API] Connection timed out.');
      return null;
    } catch (e) {
      // Software caused connection abort হ্যান্ডেল করা হচ্ছে
      debugPrint('⚠️ [API] getLockStatus Exception: $e');
      return null;
    }
  }

  DeviceStatusProfile? _parseProfileResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map) return null;
      final response = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      if (response['success'] == false) return null;
      return DeviceStatusProfile.fromApiResponse(response);
    } on FormatException catch (error) {
      debugPrint('[API] Invalid device status response: $error');
      return null;
    }
  }
}
