import 'package:socket_io_client/socket_io_client.dart' as IO;

enum SocketStatus { connecting, connected, disconnected }

/// Owns the Socket.IO connection lifecycle: authenticating with the
/// organization's gateway token, joining this device's room, and relaying
/// incoming "sms" events to the caller. Reconnects automatically and re-joins.
class SocketService {
  IO.Socket? _socket;

  void connect({
    required String endpoint,
    required String token,
    required String deviceId,
    required void Function(SocketStatus status, String message) onStatusChange,
    required void Function(Map<String, dynamic> data) onSms,
  }) {
    _socket?.dispose();

    final socket = IO.io(endpoint, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': token},
    });
    _socket = socket;

    onStatusChange(SocketStatus.connecting, 'Connecting to server...');

    socket.onConnect((_) {
      socket.emit('join', deviceId);
      onStatusChange(SocketStatus.connected, 'Connected — ready to send SMS');
    });

    socket.on('sms', (data) {
      if (data is Map) onSms(Map<String, dynamic>.from(data));
    });

    socket.onConnectError((err) {
      final text = '$err';
      onStatusChange(
        SocketStatus.disconnected,
        text.contains('Unauthorized')
            ? 'Invalid gateway token. Copy it again from CRM → Channels → SMS.'
            : 'Connection error: $text',
      );
    });

    socket.onError((err) {
      onStatusChange(SocketStatus.disconnected, 'Socket error: $err');
    });

    socket.onDisconnect((_) {
      onStatusChange(SocketStatus.disconnected, 'Disconnected from server');
    });

    socket.connect();
  }

  void disconnect() {
    _socket?.disconnect();
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
