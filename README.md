# Stage Talk

<img src="assets/brand/stage-talk.png" alt="Stage Talk" width="128" />

Private booth-to-stage notes on the local network. No cloud account.

A booth and a stage each run Stage Talk. Short text — and the presets **Stand by**, **Mic 2**, and **Hold** — shows up on every other copy on the same LAN. Stage type is the large read. Chime is optional. Awake keeps the display on.

## Run on the desktop

```bash
flutter pub get
flutter run -d linux
```

Open a second window with the same command. Both join multicast `239.255.42.77` port `44771`. A note from one shows on the other, including on a single machine.

Windows and macOS projects are in the tree (`flutter run -d windows` / `flutter run -d macos`). The window title is Stage Talk.

## Android

Public arm64 debug APK (v0.1.0):

https://github.com/owen307/stage-talk/releases/download/v0.1.0/stage-talk-arm64-debug.apk

SHA-256 `8da3298fa6ec98295ddd05d801d69c064511a7491e62dd81e44d8dce7831120e`

Build it again locally:

```bash
scripts/build_apk.sh
adb install -r dist/stage-talk-arm64-debug.apk
```

The launcher name is Stage Talk. The phone and the booth machine must be on the same Wi-Fi. Leave the app in front; Android will not deliver UDP after the process is frozen.

## Loopback demo

Two peers in one process, over multicast loopback:

```bash
flutter test test/loopback_test.dart
```

Booth sends `Stand by`. Stage answers `Hold`. That is the same path a second device uses.

## Alpaca Link

Stage Talk speaks Alpaca Link. Each note is one JSON datagram, UTF-8, multicast to **239.255.42.77:44771** with TTL **1**. Several apps on one host can bind that port (`SO_REUSEADDR` / `SO_REUSEPORT`). Multicast loopback stays on, so two windows on one machine hear each other.

```json
{
  "version": 1,
  "source": {"app": "stage-talk", "instance": "ab12", "name": "Booth"},
  "type": "talk.message",
  "name": "Booth",
  "payload": {"text": "Stand by"},
  "timestamp": 1700000000000,
  "id": "cd34",
  "show": "Main"
}
```

| Field | Value |
| --- | --- |
| `version` | `1` |
| `source.app` | `stage-talk` |
| `source.instance` | Stable id for this running copy |
| `source.name` | Operator name, up to 24 characters |
| `type` | `talk.message` |
| `name` | Same operator name |
| `payload.text` | The note, up to 160 characters |
| `timestamp` | Unix milliseconds |
| `id` | Unique note id |
| `show` | Show name. This app defaults to `Main` and ignores other shows |

Other `type` values and other `source.app` values are ignored. The older `{v, from}` envelope is not accepted.

## Screen

- **Dense** is the booth log. **Stage** enlarges the log and, on a phone, pins the last note in large type. A wide window always shows that stage glass.
- **Chime** plays a short tone for a note that came from someone else.
- **Awake** holds the backlight.
- **Clear** is local. Tap again within two seconds to confirm. It does not tell the other end to forget.
- **Show** is on the about screen. Notes for a different show are not added to the log.
- The log is kept on the device (last 200 notes). Nothing is uploaded.
