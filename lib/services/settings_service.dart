import 'package:shared_preferences/shared_preferences.dart';

/// The connection settings the user enters once: the CRM server address, the
/// organization's gateway token (from CRM → Channels → SMS) and a device name.
class GatewaySettings {
  final String endpoint;
  final String token;
  final String deviceName;

  const GatewaySettings({
    required this.endpoint,
    required this.token,
    required this.deviceName,
  });

  bool get isComplete => endpoint.isNotEmpty && token.isNotEmpty;
}

class SettingsService {
  static const _endpointKey = 'gateway_endpoint';
  static const _tokenKey = 'gateway_token';
  static const _nameKey = 'gateway_device_name';

  Future<GatewaySettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return GatewaySettings(
      endpoint: prefs.getString(_endpointKey) ?? '',
      token: prefs.getString(_tokenKey) ?? '',
      deviceName: prefs.getString(_nameKey) ?? 'Android phone',
    );
  }

  Future<void> save(GatewaySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_endpointKey, settings.endpoint);
    await prefs.setString(_tokenKey, settings.token);
    await prefs.setString(_nameKey, settings.deviceName);
  }
}
