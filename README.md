# SMS Gateway App

A Flutter app that turns an Android phone into an SMS-sending gateway device. It registers itself with the [messaging-service](../messaging-service) backend, stays connected over Socket.IO, and sends real SMS messages (via the phone's own SIM) whenever the backend relays a job to it.

---

## How It Works

1. **Device identity** — on first launch, the app generates a UUID (`DeviceIdentityService`) and persists it locally via `shared_preferences`. This id is stable across restarts and is never hardcoded.
2. **Registration** — before connecting the socket, the app calls `POST {endpoint}/api/devices/register` (`DeviceRegistrationService`) with its `deviceId` and platform, so the backend knows this device exists.
3. **Socket connection** — the app connects to the backend's Socket.IO server and joins a room named after its `deviceId` (`SocketService`). The backend tracks this device as online for as long as the socket stays connected.
4. **Receiving SMS jobs** — when the backend has an SMS job addressed to this device's `deviceId`, it emits an `"sms"` event with `{ to, content }`. The app sends the SMS natively via `SmsApi` (an Android `MethodChannel` wrapping `SmsManager`).
5. **Local HTTP server** — the app also runs a local Shelf server on port `8080` with a `POST /send_sms` endpoint, for sending an SMS directly over LAN without going through the backend at all. This is independent of the socket/device-id flow above.

```
App (gateway device)                         Backend (messaging-service)
──────────────────────                       ───────────────────────────
1. generate/load deviceId
2. POST /api/devices/register ───────────────▶ upsert Device row
3. socket.emit("join", deviceId) ────────────▶ join Socket.IO room = deviceId
                                                  (Device.isOnline = true)
                                 ◀──────────── 4. socket.emit("sms", {to, content})
5. SmsApi.sendSms(to, content)
   → native SmsManager → carrier
```

---

## Project Structure

```
lib/
├── main.dart                              # App entry point
├── app.dart                               # UI + wiring (local server, device init, socket lifecycle)
├── sms_api.dart                           # Native SMS send via MethodChannel
└── services/
    ├── device_identity_service.dart       # Generates/persists the device's UUID
    ├── device_registration_service.dart   # Registers the device with the backend
    └── socket_service.dart                # Socket.IO connect/join/listen lifecycle
```

---

## Getting Started

### Prerequisites
- Flutter SDK `^3.7.2`
- An Android device/emulator with SMS capability (SMS permission is requested at runtime)
- A running instance of [messaging-service](../messaging-service) reachable from the device

### Install & Run

```bash
flutter pub get
flutter run
```

On launch, the app:
1. Starts its local HTTP server on port `8080`.
2. Generates (or loads) its device id and registers it with the backend endpoint shown in the "Socket Server Endpoint" field (default: `https://messaging.adeylab.com`).
3. Connects to that backend over Socket.IO and joins its device room.

The device id currently in use is shown on screen for debugging/verification.

### Sending a test SMS through the backend

Once the app shows `Connected: ...`, note the device id displayed in the app, then from the backend send:

```bash
curl -X POST https://messaging.adeylab.com/api/sms \
  -H "Content-Type: application/json" \
  -d '{
    "deviceId": "<the device id shown in the app>",
    "to": "+251912345678",
    "content": "Hello from the gateway"
  }'
```

The backend queues the job and relays it over the socket to this exact device, which then sends the real SMS.

### Sending a test SMS over LAN (bypassing the backend)

```bash
curl -X POST http://<device-ip>:8080/send_sms \
  -H "Content-Type: application/json" \
  -d '{"phone": "+251912345678", "message": "Hello via local server"}'
```
