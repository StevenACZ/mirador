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
- `MiradorClient`: SwiftUI client surface and Bonjour browser for iOS/iPadOS.
- `mirador-host`: SwiftUI macOS host prototype with Bonjour advertising and a permission-aware capture service.

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

Run the macOS host prototype:

```bash
swift run mirador-host
```

Run tests:

```bash
swift test
```

## License

MIT
