import 'package:socket_io_client/socket_io_client.dart' as IO;

enum SocketStatus { connecting, connected, disconnected }

/// Owns the Socket.IO connection lifecycle: connecting, joining this device's
/// room, and relaying incoming "sms" events to the caller.
class SocketService {
  IO.Socket? _socket;

  void connect({
    required String endpoint,
    required String deviceId,
    required void Function(SocketStatus status, String message) onStatusChange,
    required void Function(Map<String, dynamic> data) onSms,
  }) {
    _socket?.dispose();

    final socket = IO.io(endpoint, <String, dynamic>{
      "transports": ["websocket"],
      "autoConnect": false,
    });
    _socket = socket;

    onStatusChange(SocketStatus.connecting, 'Connecting to socket...');

    socket.connect();

    socket.onConnect((_) {
      socket.emit('join', deviceId);
      onStatusChange(SocketStatus.connected, 'Connected: ${socket.id}');
    });

    socket.on('sms', (data) {
      onSms(Map<String, dynamic>.from(data as Map));
    });

    socket.onError((err) {
      onStatusChange(SocketStatus.disconnected, 'Socket error: $err');
    });

    socket.onDisconnect((_) {
      onStatusChange(SocketStatus.disconnected, 'Disconnected from socket server');
    });
  }

  void disconnect() {
    _socket?.disconnect();
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
