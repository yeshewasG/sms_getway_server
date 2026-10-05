import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Generates a stable per-install device id and persists it locally so the
/// same id is reused across app restarts (instead of a hardcoded socket room name).
class DeviceIdentityService {
  static const _prefsKey = 'device_id';

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = const Uuid().v4();
    await prefs.setString(_prefsKey, generated);
    return generated;
  }

  String get platformName {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return Platform.operatingSystem;
  }
}
