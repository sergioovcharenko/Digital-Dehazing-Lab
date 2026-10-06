FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    AID_ROOT=/opt/AIDTransformer \
    AID_CHECKPOINT=/app/checkpoints/Sate1K_Moderate.pth

RUN apt-get update && apt-get install -y --no-install-recommends git libgomp1 ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app

RUN pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu torch==2.5.1 torchvision==0.20.1
RUN pip install --no-cache-dir fastapi==0.115.6 uvicorn[standard]==0.34.0 python-multipart==0.0.20 pillow==11.1.0 numpy==2.1.3 gdown==5.2.0 timm==1.0.12 einops==0.8.0

RUN git clone --depth 1 https://github.com/AshutoshKulkarni4998/AIDTransformer.git /opt/AIDTransformer
RUN mkdir -p /app/checkpoints && python -c "import gdown; gdown.download(id='1wDjoCggjvG-IsI0jUe0Ok6VZy-QbnLg9', output='/app/checkpoints/Sate1K_Moderate.pth', quiet=False)"

COPY aid_api.py /app/aid_api.py

CMD ["sh","-c","uvicorn aid_api:app --host 0.0.0.0 --port ${PORT:-8000} --workers 1"]
