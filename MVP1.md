# MVP1 LAN Preview

MVP1 is the first real Mirador vertical slice: a Mac host advertises itself on
the local network, an iPhone or iPad discovers it, authenticates with a temporary
PIN, and receives live display preview frames.

## What Works

- The macOS host app advertises `_mirador._tcp` over Bonjour.
- The iOS/iPadOS app discovers Mirador hosts on the same LAN.
- The client opens an `NWConnection` to the selected host.
- The client sends the current temporary host PIN.
- The host validates the PIN before starting screen capture.
- ScreenCaptureKit stays idle until authentication succeeds.
- After auth, the host captures the primary display and sends repeated JPEG
  preview frames through the length-prefixed signaling channel.
- The client renders the latest received frame and shows a received frame count.

## Current Transport

MVP1 currently uses downscaled JPEG preview frames over the existing TCP
connection. This proves the full LAN discovery, PIN authentication, gated screen
capture, frame transport, and rendering path on real devices.

This is not yet a production video stack. A later transport pass should replace
the JPEG path with WebRTC or another H.264/HEVC hardware-encoded stream for
better bandwidth, latency, and frame pacing.

## How To Test

1. Run the macOS host:

   ```bash
   ./scripts/build_and_run.sh
   ```

2. If the host shows screen capture as not granted, click `Screen Permission`,
   enable Screen Recording for the host app in macOS Settings, then relaunch the
   host.

3. Install the iOS app on a connected device. Set the device UDID and your Apple
   development team in the environment:

   ```bash
   DEVICE_ID=<device-udid> DEVELOPMENT_TEAM=<team-id> ./scripts/install_ios_device.sh
   ```

4. On the iPhone or iPad, allow Local Network access when prompted.

5. Select the Mac host, enter the PIN shown by the host app, and tap Connect.

6. After `PIN accepted`, the preview should start and the received frame counter
   should increase.

## Not In MVP1

- Mouse, keyboard, scroll, or touch forwarding.
- Accessibility permission.
- Persistent pairing or trusted-device management.
- Multi-display selection.
- System audio.
- Cloud relay, VPN, or internet access.
- Production WebRTC/H.264 transport.

## Verification

Use these checks before publishing changes:

```bash
swift build
swift test
xcodebuild -scheme mirador-host -destination 'platform=macOS' -derivedDataPath .build/xcode-macos build
xcodebuild -scheme MiradorClient -destination 'generic/platform=iOS' -derivedDataPath .build/xcode-ios build
xcodebuild -project Mirador.xcodeproj -scheme MiradorHostApp -destination 'platform=macOS' -derivedDataPath .build/xcode-macos-app build
xcodebuild -project Mirador.xcodeproj -scheme MiradorClientApp -destination 'generic/platform=iOS' -derivedDataPath .build/xcode-ios-app CODE_SIGNING_ALLOWED=NO build
```
