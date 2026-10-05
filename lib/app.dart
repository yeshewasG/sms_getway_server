import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:permission_handler/permission_handler.dart';
import 'services/device_identity_service.dart';
import 'services/device_registration_service.dart';
import 'services/socket_service.dart';
import 'sms_api.dart';

enum SmsStatus { idle, sending, success, error }

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  SocketStatus _socketStatus = SocketStatus.disconnected;
  SmsStatus _smsStatus = SmsStatus.idle;
  final _smsApi = SmsApi();
  final _deviceIdentity = DeviceIdentityService();
  final _deviceRegistration = DeviceRegistrationService();
  final _socketService = SocketService();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  final _endpointController = TextEditingController(
    text: "https://messaging.adeylab.com",
  );

  String _result = '';
  String _serverStatus = 'Starting server...';
  String? _deviceId;
  HttpServer? _server;

  @override
  void initState() {
    super.initState();
    _startServer();
    _initDeviceAndConnect();
  }

  Future<void> _initDeviceAndConnect() async {
    final deviceId = await _deviceIdentity.getOrCreateDeviceId();
    setState(() {
      _deviceId = deviceId;
    });
    await _connectSocket();
  }

  Future<void> _connectSocket() async {
    final deviceId = _deviceId;
    if (deviceId == null) {
      setState(() {
        _result = "Device id not ready yet";
      });
      return;
    }

    final endpoint = _endpointController.text.trim();
    if (endpoint.isEmpty) {
      setState(() {
        _result = "Please enter a valid Socket endpoint";
        _socketStatus = SocketStatus.disconnected;
      });
      return;
    }

    setState(() {
      _socketStatus = SocketStatus.connecting;
      _result = 'Registering device...';
    });

    try {
      await _deviceRegistration.register(
        endpoint: endpoint,
        deviceId: deviceId,
        platform: _deviceIdentity.platformName,
      );
    } on DeviceRegistrationException catch (e) {
      setState(() {
        _socketStatus = SocketStatus.disconnected;
        _result = "Device registration failed: ${e.message}";
      });
      return;
    }

    _socketService.connect(
      endpoint: endpoint,
      deviceId: deviceId,
      onStatusChange: (status, message) {
        setState(() {
          _socketStatus = status;
          _result = message;
        });
      },
      onSms: (data) async {
        await _smsApi.sendSms(phone: data['to'], message: data['content']);
        setState(() {
          _result = "📩 SMS received: To ${data['to']} - ${data['content']}";
        });
      },
    );
  }

  void _disconnectSocket() {
    _socketService.disconnect();
    setState(() {
      _socketStatus = SocketStatus.disconnected;
      _result = "Socket manually disconnected";
    });
  }

  Future<void> _startServer() async {
    final router = shelf_router.Router();

    // API endpoint for sending SMS
    router.post('/send_sms', (Request request) async {
      try {
        final payload = await request.readAsString();
        if (payload.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'status': 'error', 'message': 'Empty payload'}),
          );
        }

        final data = jsonDecode(payload);
        final phone = data['phone'] as String?;
        final message = data['message'] as String?;

        if (phone == null || message == null) {
          return Response.badRequest(
            body: jsonEncode({
              'status': 'error',
              'message': 'Missing phone or message',
            }),
          );
        }

        final result = await _smsApi.sendSms(phone: phone, message: message);
        return Response.ok(
          jsonEncode({'status': 'success', 'message': result}),
        );
      } on FormatException catch (e) {
        return Response.badRequest(
          body: jsonEncode({
            'status': 'error',
            'message': 'Invalid JSON format',
          }),
        );
      } on SmsApiException catch (e) {
        return Response(
          400,
          body: jsonEncode({'status': 'error', 'message': e.message}),
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'status': 'error', 'message': e.toString()}),
        );
      }
    });

    try {
      _server = await shelf_io.serve(router, InternetAddress.anyIPv4, 8080);
      final ip = _server!.address.host;
      setState(() {
        _serverStatus = 'Local Server running on $ip:8080';
      });
    } catch (e) {
      setState(() {
        _serverStatus = 'Failed to start server: $e';
      });
    }
  }

  @override
  void dispose() {
    _server?.close();
    _socketService.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendSMS() async {
    setState(() {
      _smsStatus = SmsStatus.sending;
      _result = 'Checking permissions...';
    });
    final hasPermission = await _requestSmsPermission();
    if (!hasPermission) {
      setState(() {
        _smsStatus = SmsStatus.error;
        _result = 'SMS permission denied';
      });
      return;
    }

    setState(() {
      _smsStatus = SmsStatus.sending;
      _result = 'Sending SMS...';
    });
    try {
      final result = await _smsApi.sendSms(
        phone: _phoneController.text,
        message: _messageController.text,
      );
      _phoneController.clear();
      _messageController.clear();
      setState(() {
        _smsStatus = SmsStatus.success;
        _result = result;
      });
    } on SmsApiException catch (e) {
      setState(() {
        _smsStatus = SmsStatus.error;
        _result = 'Error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _smsStatus = SmsStatus.error;
        _result = 'Unexpected error: $e';
      });
    }
  }

  Future<bool> _requestSmsPermission() async {
    // Check current status
    var status = await Permission.sms.status;

    if (status.isGranted) {
      // Permission already granted
      return true;
    } else if (status.isDenied) {
      // Request permission
      final result = await Permission.sms.request();
      return result.isGranted;
    } else if (status.isPermanentlyDenied) {
      // Permission permanently denied, user must enable in settings
      setState(() {
        _result =
            'SMS permission permanently denied. Please enable it in settings.';
      });
      // Optionally, you can open app settings:
      // openAppSettings();
      return false;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('SMS')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              _serverStatus,
              style: TextStyle(
                color:
                    _serverStatus.contains('Failed')
                        ? Colors.red
                        : Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _deviceId == null
                        ? 'Device id: generating...'
                        : 'Device id: $_deviceId',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_deviceId != null)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: 'Copy device id',
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(ClipboardData(text: _deviceId!));
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Device id copied')),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _endpointController,
              decoration: const InputDecoration(
                labelText: 'Socket Server Endpoint',
                hintText: 'e.g. https://messaging.adeylab.com',
              ),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed:
                      _socketStatus == SocketStatus.disconnected
                          ? _connectSocket
                          : null,
                  child:
                      _socketStatus == SocketStatus.connecting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text("Connect Socket"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed:
                      _socketStatus == SocketStatus.connected
                          ? _disconnectSocket
                          : null,
                  child: const Text("Disconnect Socket"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _smsStatus == SmsStatus.sending ? null : _sendSMS,
              child:
                  _smsStatus == SmsStatus.sending
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text("Send SMS"),
            ),
            Text(
              _result,
              style: TextStyle(
                color:
                    _smsStatus == SmsStatus.error ||
                            _serverStatus.contains('Failed')
                        ? Colors.red
                        : _socketStatus == SocketStatus.connected
                        ? Colors.green
                        : Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
