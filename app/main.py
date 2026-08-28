"""nks-demo — NCP NKS CI/CD 실습용 데모 앱."""
import os
import socket
import time

from fastapi import FastAPI
from fastapi.responses import JSONResponse

APP_VERSION = os.getenv("APP_VERSION", "unknown")
POD_NAME = os.getenv("HOSTNAME", socket.gethostname())

app = FastAPI(title="nks-demo", version=APP_VERSION)


@app.get("/")
def root():
    return {"app": "nks-demo", "version": APP_VERSION, "pod": POD_NAME}


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/work")
def work(ms: int = 100):
    """ms 밀리초 동안 CPU 를 소모한다 (HPA 부하테스트용)."""
    ms = max(0, min(ms, 5000))
    deadline = time.perf_counter() + ms / 1000.0
    n = 0
    while time.perf_counter() < deadline:
        n += 1
    return JSONResponse({"burned_ms": ms, "iterations": n, "pod": POD_NAME})
