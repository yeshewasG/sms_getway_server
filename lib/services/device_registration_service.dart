import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceRegistrationException implements Exception {
  final String message;

  DeviceRegistrationException(this.message);

  @override
  String toString() => 'DeviceRegistrationException($message)';
}

/// Registers this device with the CRM so SMS jobs can be routed to it. The
/// gateway token identifies which organization the device belongs to.
class DeviceRegistrationService {
  Future<void> register({
    required String endpoint,
    required String token,
    required String deviceId,
    required String platform,
    String? name,
  }) async {
    final uri = Uri.parse('$endpoint/api/devices/register');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-gateway-token': token,
            },
            body: jsonEncode({
              'deviceId': deviceId,
              'platform': platform,
              if (name != null && name.isNotEmpty) 'name': name,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        throw DeviceRegistrationException(
          'Invalid gateway token. Copy it again from CRM → Channels → SMS.',
        );
      }
      if (response.statusCode >= 400) {
        throw DeviceRegistrationException(
          'Registration failed (${response.statusCode}): ${response.body}',
        );
      }
    } on DeviceRegistrationException {
      rethrow;
    } catch (e) {
      throw DeviceRegistrationException('Could not reach the server: $e');
    }
  }
}
