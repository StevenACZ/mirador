# Mirador

Mirador is a local-first Apple ecosystem remote viewing project. The goal is to run a lightweight host on a Mac and view that Mac from an iPhone or iPad on the same LAN.

The first milestone is intentionally small: discover the Mac over Bonjour, connect from iPhone or iPad, and stream the selected Mac display at 30 FPS. Remote input, persistent pairing, monitor switching, system audio, shortcuts, and high-quality zoom are planned as later milestones.

## Product Direction

- Host: macOS, Apple Silicon M1 or newer.
- Client: iPhone and iPad only.
- Network: local LAN only, using Bonjour for discovery.
- Runtime: idle host listener first; screen capture and video transport start only after a client connects.
- Privacy: no cloud relay, VPN, Android, Windows, or Linux support in the initial roadmap.

## Current Scaffold

- `MiradorCore`: shared protocol constants, signaling messages, PIN helpers, and LAN discovery models.
- `MiradorClient`: SwiftUI client surface, Bonjour browser, PIN authentication, and preview frame receiver for iOS/iPadOS.
- `MiradorHost`: macOS host module with Bonjour advertising, PIN validation, and permission-aware ScreenCaptureKit capture.
- `Mirador.xcodeproj`: installable macOS and iOS app targets that wrap the SwiftPM modules.
- `mirador-host`: SwiftPM executable kept for local development.

## MVP1 Status

Mirador now has the first real LAN preview vertical slice working on device:

1. The Mac host advertises `_mirador._tcp` with Bonjour.
2. The iPhone/iPad app discovers hosts on the local network.
3. The client opens an `NWConnection` to the selected host.
4. The client sends the temporary PIN.
5. The host validates the PIN.
6. Only after authentication, the host starts ScreenCaptureKit.
7. The host sends downscaled JPEG preview frames over the existing length-prefixed signaling channel.
8. The client renders the latest received frame.

This is intentionally not the final video transport. WebRTC/H.264 hardware encoding is still the target for a production-quality 30 FPS stream; the current JPEG frame path proves the end-to-end auth, capture, transport, and rendering flow first. See [MVP1.md](MVP1.md) for the test flow and current limits.

## Planned MVPs

1. **MVP1: LAN screen preview**
   - Advertise `_mirador._tcp` from the Mac.
   - Browse from iPhone or iPad.
   - Require a temporary host PIN before streaming.
   - Stream the primary display at 30 FPS.

2. **MVP2: Basic control**
   - Persistent pairing.
   - Tap, click, scroll, keyboard, and client-side zoom.

3. **MVP3: Daily-use controls**
   - Monitor selector.
   - System audio.
   - Shortcut tray.
   - Optional 60 FPS.

4. **MVP4: Polish**
   - High-quality zoom crops.
   - Quality profiles.
   - Latency stats.
   - Trusted devices management.

## Development

Build all package products:

```bash
swift build
```

Run the installable macOS host app:

```bash
./scripts/build_and_run.sh
```

Build the macOS host app directly:

```bash
xcodebuild -project Mirador.xcodeproj -scheme MiradorHostApp -destination 'platform=macOS' -derivedDataPath .build/xcode-macos-app build
```

Build the iOS/iPadOS app for device compilation without signing:

```bash
xcodebuild -project Mirador.xcodeproj -scheme MiradorClientApp -destination 'generic/platform=iOS' -derivedDataPath .build/xcode-ios-app CODE_SIGNING_ALLOWED=NO build
```

To install on a real iPhone or iPad, open `Mirador.xcodeproj`, select the `MiradorClientApp` scheme, choose your development team for signing, and run on the device. The app includes the local network usage description and Bonjour service declaration required for `_mirador._tcp`.

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

## License

MIT
