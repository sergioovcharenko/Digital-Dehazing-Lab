# Digital Dehazing Lab

Experimental web lab for comparing multiple dehazing pipelines on photo, recorded video and live camera input.

## Modes
- Original
- Classic DCP
- WebL / Adaptive MAX
- EDN-GTM (AI runtime hook)
- AIDTransformer (AI runtime hook)
- Hybrid (reserved for measured best combination)

## Sources
- Photo
- Local video
- Live camera

## Evaluation
The UI exposes processing strength, 50/50 comparison, FPS and per-frame processing time.

The classic and WebL paths are browser-native and run locally. EDN-GTM and AIDTransformer are wired as model-backed engines; model assets are kept separate so the lab can use optimized ONNX/WebGPU builds without pretending a CSS/WebGL filter is the AI model.

Target use: identify the best quality/latency trade-off on real foggy aerial footage, then reuse the winning pipeline for live video.
