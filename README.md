# Mirador

Mirador is a local-first Apple ecosystem remote viewing project. The product goal
is simple: run a lightweight host on a Mac and control that Mac from an iPhone or
iPad on the same LAN.

The app is currently focused on local smoothness, low latency, and real-time
control. Internet exposure, VPN mode, cloud relay, Android, Windows, and Linux are
outside the current scope.

## Product Direction

- Host: macOS, Apple Silicon M1 or newer.
- Client: iPhone and iPad only.
- Network: local LAN only, using Bonjour for discovery.
- Session model: temporary local test mode without PIN entry.
- Runtime: idle host listener first; screen capture and stream transport start
  only after a compatible local client connects.
- Privacy: no cloud relay, no persistent pairing, and no private LAN identity in
  protocol labels.

## Current Implementation

- `MiradorCore`: shared protocol constants, signaling messages, stream quality,
  viewport, frame metadata, diagnostics, remote input, and LAN discovery models.
- `MiradorClient`: SwiftUI client surface, Bonjour browser, local session flow,
  preview receiver, stream controls for resolution/FPS/bitrate, generic client
  identity, live pointer movement, and remote input sender for iOS/iPadOS.
- `MiradorHost`: macOS host module with generic Bonjour advertising,
  protocol-version gating, permission-aware ScreenCaptureKit capture, stream
  stats, source-frame drop diagnostics, host-only system audio capture readiness,
  and gated input control.
- `Mirador.xcodeproj`: installable macOS and iOS app targets that wrap the
  SwiftPM modules.
- `mirador-host`: SwiftPM executable kept for local development.

The current video path is optimized JPEG-over-TCP with client-selected
resolution, frame rate, and target bitrate. Codec selection is intentionally not
exposed yet because the production-quality path should move to VideoToolbox
low-latency H.264/HEVC and a Metal/AVFoundation-backed client renderer.

## Local Control Target

The target experience is:

1. The Mac advertises the generic `Mirador Host` service over `_mirador._tcp`.
2. The iPhone/iPad app discovers the Mac on the same LAN.
3. The client connects immediately in local test mode.
4. The host validates the protocol version before accepting the session.
5. ScreenCaptureKit starts only after the local session is accepted.
6. The client can switch display, resolution, FPS, target bitrate, and zoom crop.
7. 60 FPS mode aims for low source-frame drop rate and low UI/input churn.
8. The embedded preview is passive; remote pointer, click, and keyboard control
   are reserved for the full-screen viewer.
9. Full-screen landscape mode supports display switching, pinch zoom,
   two-finger pan crop, tap click, two-finger secondary click, live pointer
   movement while dragging, and native iOS keyboard entry for focused Mac text
   fields.
10. The host reports effective FPS, bitrate, capture cost, send cost, latency
   signals, and source-frame drop rate.
11. Remote input remains gated by host-side Accessibility permission.

Future product work should add client-side camera/photo actions, faster
multi-display workflows, persistent pairing, and client audio playback.

## Performance Notes

- ScreenCaptureKit is configured for 60 FPS through
  `SCStreamConfiguration.minimumFrameInterval` when 60 FPS is selected.
- Stream queue depth is kept small to avoid hiding latency in buffered frames.
- Network.framework TCP sessions use interactive parameters with `noDelay`.
- JPEG decode runs off the SwiftUI main render path.
- Pointer movement is emitted during pan gestures at a 60 Hz throttle instead of
  waiting for gesture end.
- Embedded preview frames do not install remote-control gestures, keeping the
  normal session screen as a read-only monitor.
- Drag pointer movement is lifted above the finger on the client so the user's
  touch does not hide the Mac cursor target.
- Native iOS keyboard input sends text, delete, and return events to the focused
  Mac field through the same gated remote-control path.
- High-frequency pointer movement does not publish client/host UI state on every
  event, avoiding extra SwiftUI invalidation while controlling the Mac.
- Diagnostics track source-frame drops separately from effective FPS so stutter
  can be distinguished from pure network send time.

## Development

Recommended local verification before publishing:

```bash
swift build
swift test
xcodebuild -project Mirador.xcodeproj -scheme MiradorHostApp -destination 'platform=macOS' -derivedDataPath .build/xcode-macos-app build
xcodebuild -project Mirador.xcodeproj -scheme MiradorClientApp -destination 'generic/platform=iOS' -derivedDataPath .build/xcode-ios-app CODE_SIGNING_ALLOWED=NO build
git status --short --ignored
```

Run the installable macOS host app:

```bash
./scripts/build_and_run.sh
```

Build all package products:

```bash
swift build
```

Build the macOS host app directly:

```bash
xcodebuild -project Mirador.xcodeproj -scheme MiradorHostApp -destination 'platform=macOS' -derivedDataPath .build/xcode-macos-app build
```

Build the iOS/iPadOS app for device compilation without signing:

```bash
xcodebuild -project Mirador.xcodeproj -scheme MiradorClientApp -destination 'generic/platform=iOS' -derivedDataPath .build/xcode-ios-app CODE_SIGNING_ALLOWED=NO build
```

To install on a real iPhone or iPad, open `Mirador.xcodeproj`, select the
`MiradorClientApp` scheme, choose your development team for signing, and run on
the device. The app includes the local network usage description and Bonjour
service declaration required for `_mirador._tcp`.

Or install from the command line without storing signing details in the repo:

```bash
DEVICE_ID=<device-udid> DEVELOPMENT_TEAM=<team-id> ./scripts/install_ios_device.sh
```

Run the SwiftPM host executable:

```bash
swift run mirador-host
```

Run tests:

```bash
swift test
```

## Public Safety Notes

- The repo should not contain private LAN IPs, Wi-Fi names, real device names,
  screenshots, signing team IDs, pairing secrets, logs, or local planning notes.
- `Docs/`, `AGENTS.md`, `.codex/`, `CLAUDE.md`, `cloud.md`, and `clavo.md` are
  intentionally ignored.
- The current implementation is LAN-only. It does not include cloud relay, VPN
  mode, persistent pairing, or internet access.

## License

MIT
