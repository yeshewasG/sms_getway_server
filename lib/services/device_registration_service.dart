import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceRegistrationException implements Exception {
  final String message;

  DeviceRegistrationException(this.message);

  @override
  String toString() => 'DeviceRegistrationException($message)';
}

/// Registers this device with the backend so messages can be routed to it by [deviceId].
class DeviceRegistrationService {
  Future<void> register({
    required String endpoint,
    required String deviceId,
    required String platform,
  }) async {
    final uri = Uri.parse('$endpoint/api/devices/register');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': deviceId, 'platform': platform}),
      );

      if (response.statusCode >= 400) {
        throw DeviceRegistrationException(
          'Registration failed (${response.statusCode}): ${response.body}',
        );
      }
    } on DeviceRegistrationException {
      rethrow;
    } catch (e) {
      throw DeviceRegistrationException(e.toString());
    }
  }
}
