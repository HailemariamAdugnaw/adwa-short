from __future__ import annotations

import mimetypes
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.database import engine
from app.routers import (
    ad_unlock,
    admin_analytics,
    admin_content,
    admin_revenue,
    admin_staff,
    admin_users,
    admin_wallet,
    auth,
    categories,
    coins,
    creators,
    devices,
    downloads,
    engagement,
    episodes,
    loyalty,
    passes,
    ratings,
    reviews,
    search,
    series,
    settings as settings_router,
    shelves,
    shorts,
    subscriptions,
    uploads,
    users,
    wallet,
)

for _ext, _ctype in (
    (".mkv", "video/x-matroska"),
    (".mov", "video/quicktime"),
    (".avi", "video/x-msvideo"),
    (".webm", "video/webm"),
    (".flv", "video/x-flv"),
    (".wmv", "video/x-ms-wmv"),
    (".m4v", "video/x-m4v"),
    (".mpg", "video/mpeg"),
    (".mpeg", "video/mpeg"),
    (".3gp", "video/3gpp"),
    (".ts", "video/mp2t"),
    (".m3u8", "application/vnd.apple.mpegurl"),
):
    mimetypes.add_type(_ctype, _ext)


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await engine.dispose()


app = FastAPI(
    title="ADWA SHORT API",
    version="1.0.0",
    description="Backend for the ADWA SHORT video streaming platform.",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

for r in (
    auth.router,
    users.router,
    devices.router,
    categories.router,
    series.router,
    episodes.router,
    shorts.router,
    shelves.router,
    search.router,
    engagement.router,
    wallet.router,
    coins.router,
    passes.router,
    subscriptions.router,
    ad_unlock.router,
    loyalty.router,
    settings_router.router,
    uploads.router,
    creators.router,
    ratings.router,
    reviews.router,
    downloads.router,
    admin_content.router,
    admin_users.router,
    admin_wallet.router,
    admin_analytics.router,
    admin_revenue.router,
    admin_staff.router,
):
    app.include_router(r)


Path(settings.UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")


@app.get("/", tags=["meta"])
async def root():
    return {"app": "ADWA SHORT API", "version": "1.0.0", "docs": "/docs"}


@app.get("/health", tags=["meta"])
async def health():
    return {"status": "ok"}
