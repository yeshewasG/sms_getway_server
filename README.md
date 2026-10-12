# SMS Gateway App

A Flutter app that turns an Android phone into an SMS-sending gateway for the **Adey CRM**. The phone connects to
your CRM server, authenticates with your organization's **gateway token**, and sends a real SMS from its own SIM
whenever the CRM asks it to.

## Setup

1. In the CRM open **Channels → SMS → Set up SMS gateway**. It shows a **server address** and a **gateway token**.
2. Install and open this app on the phone, then enter:
   - **CRM server address** — the API address shown in the CRM (e.g. `https://api.yourcompany.com`)
   - **Gateway token** — copied from the CRM
   - **Device name** — anything, shown in the CRM's phone list
3. Tap **Connect** and allow the SMS permission. The phone appears as **Online** in the CRM, and **Send test SMS** there should arrive.

Settings are saved on the phone and the app reconnects automatically on launch.

## How it works

```
Phone (this app)                                 CRM backend
────────────────                                 ───────────
1. device id (UUID, generated once, persisted)
2. POST /api/devices/register
   header x-gateway-token ──────────────────────▶ token → organization, upsert Device
3. socket.io connect, auth {token} ─────────────▶ rejected unless token is valid
   emit "join" deviceId ────────────────────────▶ Device online (this organization)
                                 ◀────────────── 4. emit "sms" { to, content }
5. SmsManager → SIM → carrier
```

- The token identifies the **organization**, so a phone only ever receives that organization's messages.
- If the token is regenerated in the CRM, connected phones are disconnected; paste the new token and tap **Connect**.
- The socket reconnects on its own after network drops and re-joins its room.
- Incoming jobs are sent natively through `SmsApi` (Android `MethodChannel` over `SmsManager`). Failures are shown on screen.

> The CRM marks a message **Sent** when it has been handed to this app. Carrier delivery receipts are not reported back yet.

## Local HTTP endpoint

The app also serves `POST /send_sms` on port `8080` for sending over the LAN. It now requires the same gateway token:

```bash
curl -X POST http://<phone-ip>:8080/send_sms \
  -H "Content-Type: application/json" \
  -H "x-gateway-token: <your gateway token>" \
  -d '{"phone": "+251912345678", "message": "Hello via local server"}'
```

## Project structure

```
lib/
├── main.dart                              # entry point
├── app.dart                               # UI + wiring (local server, connect, SMS handling)
├── sms_api.dart                           # native SMS send via MethodChannel
└── services/
    ├── settings_service.dart              # persists server address, token, device name
    ├── device_identity_service.dart       # generates/persists the device UUID
    ├── device_registration_service.dart   # token-authenticated registration
    └── socket_service.dart                # authenticated Socket.IO lifecycle
```

## Run

```bash
flutter pub get
flutter run        # Android device with a SIM
```

Keep the phone awake/unrestricted for the app (battery optimisation can stop the connection in the background).
