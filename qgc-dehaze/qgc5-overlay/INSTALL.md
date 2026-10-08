# QGC 5.0.8 Dehaze Lab — Android install

Target: Samsung Galaxy Tab S10 FE / arm64-v8a

Package ID: `org.mavlink.qgroundcontrol.dehazelab`

This build is intentionally installed as a separate Android application so it can coexist with the regular QGroundControl package.

The CI build is signed with a dedicated Dehaze Lab test key and is verified with Android `apksigner` before the APK artifact is uploaded.

## Dehazing
All dehazing processing is local/offline. No cloud inference or remote API is required.

Modes:
OFF, AUTO, ADAPTIVE, FAST DCP, LIVE DCP, CLASSIC, DCP BALANCED, DCP STRONG, CAP, CLAHE, RETINEX.

Strength:
LOW, MEDIUM, HIGH.

The performance badge shows active mode/strength plus render FPS and frame time.
