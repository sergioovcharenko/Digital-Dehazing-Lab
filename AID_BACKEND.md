# AIDTransformer backend

Optional server runtime for the **AIDTransformer** mode in Digital Dehazing Lab.

- Uses the public WACV 2023 AIDTransformer implementation.
- Uses the authors' Sate1K Moderate checkpoint from their published Google Drive.
- The static GitHub Pages app remains client-side for WebL, Classic DCP and EDN-GTM.
- AIDTransformer is server-side because its deformable-convolution operators are not supported by the Safari/Web browser runtime used by the app.

The API exposes `GET /health` and `POST /dehaze`.
