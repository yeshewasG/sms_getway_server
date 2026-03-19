import 'package:flutter/services.dart';

class SmsApi {
  static const _platform = MethodChannel('com.adeylab.sms/sms');

  Future<String> sendSms({
    required String phone,
    required String message,
  }) async {
    try {
      final result = await _platform.invokeMethod<String>('sendSMS', {
        'phone': phone,
        'message': message,
      });
      return result ?? 'SMS sent successfully';
    } on PlatformException catch (e) {
      throw SmsApiException(
        code: e.code,
        message: e.message ?? 'Failed to send SMS',
      );
    }
  }
}

class SmsApiException implements Exception {
  final String code;
  final String message;

  SmsApiException({required this.code, required this.message});

  @override
  String toString() => 'SmsApiException(code: $code, message: $message)';
}
