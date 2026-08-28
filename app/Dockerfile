# syntax=docker/dockerfile:1

# ---------- builder ----------
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---------- runtime ----------
FROM python:3.12-slim
ARG APP_VERSION=unknown
ENV APP_VERSION=${APP_VERSION} \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
COPY --from=builder /install /usr/local
WORKDIR /app
COPY main.py .

# non-root
RUN useradd -u 10001 -m appuser
USER 10001

EXPOSE 8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
