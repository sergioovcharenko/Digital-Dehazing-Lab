# QGC Dehaze Lab

Target device: Samsung Galaxy Tab S10 FE (arm64-v8a).

## Bases
- QGroundControl v4.4.0 (commit 15bdfd5f16562a09ccb1a57808ed0405049645a7)
- QGroundControl v5.0.8 (commit e0816c957602789200ae5ba0af45217f0f2f1db4)

## Live modes
OFF / AUTO / ADAPTIVE / FAST DCP / LIVE DCP / CLASSIC / DCP BALANCED / DCP STRONG / CAP / CLAHE / RETINEX

AI models are intentionally excluded from this build.

## UI
- DEHAZING button appears only when an active vehicle is connected.
- OFF: button gray, settings gear hidden.
- AUTO or MANUAL: button green, settings gear visible.
- Settings panel: AUTO / MANUAL / OFF, then LOW / MEDIUM / HIGH, then algorithm grid.
- Selected buttons have visible highlighted border/fill.
- Persistent performance badge over video:
  - mode + strength
  - output FPS
  - processing ms/frame
  - added latency
  - dropped frames
- Badge state:
  - white: OFF / unavailable
  - green: good
  - yellow: degraded
  - red: poor
  - smoothed over a short window to avoid flicker.

## Build strategy
The live dehaze stage is inserted after decode and before UI overlays. HUD/telemetry are not processed.

The first laboratory build is optimized for 1080p output with reduced-resolution haze maps for heavier modes.
