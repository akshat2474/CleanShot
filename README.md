# CleanShot X (macOS)

An advanced, native macOS screenshot, screen recording, annotation, and productivity utility reproducing the core workflows, aesthetics, and system capabilities of **CleanShot X**.

## Architecture & Features

- **Ephemeral Quick Access Overlay:** Floating HUD (`NSPanel`) for instantaneous copying, saving, pinning, and drag-and-drop without desktop clutter.
- **Capture Modes:** Area capture with real-time magnifier loupe and dimensions, Freeze Screen buffer, Window capture with shadow & background styling, and Fullscreen capture.
- **Screen Recording:** High-performance video & GIF recording via `ScreenCaptureKit` with simultaneous microphone and internal system audio loopback, plus webcam picture-in-picture overlay.
- **Scrolling Capture:** Automated synthetic scrolling and real-time normalized cross-correlation image stitching for long documents and web pages.
- **Vector Annotation Suite:** Arrows, shapes, text callouts, auto-incrementing step counters, highlighters, pencil curves, and non-destructive blur/pixelate/spotlight filters.
- **OCR & QR Scanner:** On-device Apple Vision text recognition and QR code decoding with instant clipboard synchronization.
- **Desktop Clutter Hider:** Instant wallpaper `NSWindow` overlay at desktop icon level for clean captures with zero Finder restart latency.

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 6.0+ / Xcode 16.0+
