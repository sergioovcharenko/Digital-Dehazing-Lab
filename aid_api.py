import io
import math
import os
import sys
import time
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from PIL import Image

AID_ROOT = os.environ.get("AID_ROOT", "/opt/AIDTransformer")
CHECKPOINT = os.environ.get("AID_CHECKPOINT", "/app/checkpoints/Sate1K_Moderate.pth")
if AID_ROOT not in sys.path:
    sys.path.insert(0, AID_ROOT)

from model import Network

torch.set_grad_enabled(False)
torch.set_num_threads(max(1, min(4, os.cpu_count() or 2)))

app = FastAPI(title="Digital Dehazing AIDTransformer API", version="1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://sergioovcharenko.github.io",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
    ],
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

_model = None
_model_error = None


def load_model():
    global _model, _model_error
    if _model is not None:
        return _model
    try:
        m = Network(
            img_size=256,
            embed_dim=16,
            win_size=8,
            token_projection="conv",
            token_mlp="leff",
        )
        ckpt = torch.load(CHECKPOINT, map_location="cpu", weights_only=False)
        state = ckpt["state_dict"]
        clean = {(k[7:] if k.startswith("module.") else k): v for k, v in state.items()}
        m.load_state_dict(clean, strict=True)
        m.eval()
        _model = m
        _model_error = None
        return _model
    except Exception as e:
        _model_error = f"{type(e).__name__}: {e}"
        raise


@app.on_event("startup")
def startup():
    try:
        load_model()
    except Exception:
        pass


@app.get("/health")
def health():
    return {
        "ok": _model is not None,
        "engine": "AIDTransformer",
        "checkpoint": "Sate1K_Moderate",
        "device": "cpu",
        "error": _model_error,
    }


def prepare(img: Image.Image, max_side: int):
    original_size = img.size
    w, h = original_size
    scale = min(1.0, max_side / max(w, h))
    rw, rh = max(1, round(w * scale)), max(1, round(h * scale))
    if (rw, rh) != (w, h):
        img = img.resize((rw, rh), Image.Resampling.LANCZOS)
    arr = np.asarray(img, dtype=np.float32) / 255.0
    x = torch.from_numpy(arr).permute(2, 0, 1).unsqueeze(0).contiguous()
    side = int(math.ceil(max(rh, rw) / 128.0) * 128)
    padded = torch.zeros((1, 3, side, side), dtype=torch.float32)
    valid = torch.zeros((1, 1, side, side), dtype=torch.float32)
    top = (side - rh) // 2
    left = (side - rw) // 2
    padded[:, :, top:top + rh, left:left + rw] = x
    valid[:, :, top:top + rh, left:left + rw] = 1.0
    return padded, valid, (left, top, rw, rh), original_size


def tensor_to_image(y, crop, original_size):
    left, top, rw, rh = crop
    y = y[:, :, top:top + rh, left:left + rw].clamp(0, 1)
    arr = (y.squeeze(0).permute(1, 2, 0).cpu().numpy() * 255.0 + 0.5).astype(np.uint8)
    out = Image.fromarray(arr, "RGB")
    if out.size != original_size:
        out = out.resize(original_size, Image.Resampling.LANCZOS)
    return out


@app.post("/dehaze")
async def dehaze(
    file: UploadFile = File(...),
    max_side: int = Query(256, ge=128, le=512),
    quality: int = Query(90, ge=70, le=96),
):
    if file.content_type and not file.content_type.startswith("image/"):
        raise HTTPException(415, "image file required")
    try:
        model = load_model()
    except Exception as e:
        raise HTTPException(503, f"model unavailable: {e}")
    data = await file.read()
    try:
        img = Image.open(io.BytesIO(data)).convert("RGB")
    except Exception:
        raise HTTPException(400, "invalid image")
    x, valid, crop, original_size = prepare(img, max_side)
    t0 = time.perf_counter()
    with torch.inference_mode():
        y = model(x, 1.0 - valid)
    ms = (time.perf_counter() - t0) * 1000.0
    out = tensor_to_image(y, crop, original_size)
    buf = io.BytesIO()
    out.save(buf, "JPEG", quality=quality, optimize=True)
    return Response(
        content=buf.getvalue(),
        media_type="image/jpeg",
        headers={
            "X-Engine": "AIDTransformer",
            "X-Checkpoint": "Sate1K_Moderate",
            "X-Inference-Ms": f"{ms:.1f}",
            "Cache-Control": "no-store",
        },
    )
