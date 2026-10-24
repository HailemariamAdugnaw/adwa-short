from __future__ import annotations

import mimetypes
import os
import typing
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import StreamingResponse
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.deps import get_current_user
from app.models.content import Episode, Series
from app.models.download import DownloadToken
from app.models.user import User
from app.schemas.download import (
    DownloadRequest,
    DownloadTokenListResponse,
    DownloadTokenResponse,
    DownloadedEpisodeInfo,
)
from app.services.monetization import AccessDenied, resolve_access

router = APIRouter(prefix="/downloads", tags=["downloads"])

TOKEN_TTL_HOURS = 24
CHUNK_SIZE = 64 * 1024


def _resolve_file_path(video_url: str) -> Optional[str]:
    if not video_url:
        return None
    if video_url.startswith(("http://", "https://")):
        return None
    upload_dir = str(settings.UPLOAD_DIR).rstrip("/")
    if video_url.startswith("/uploads/"):
        rel = video_url[len("/uploads/"):]
        return os.path.join(upload_dir, rel)
    if video_url.startswith("/"):
        return os.path.join(upload_dir, video_url.lstrip("/"))
    return os.path.join(upload_dir, video_url)


def _parse_range(range_header: str, file_size: int) -> tuple[int, int]:
    spec = range_header.strip()
    if spec.startswith("bytes="):
        spec = spec[len("bytes="):]
    start_str, _, end_str = spec.partition("-")
    try:
        start = int(start_str) if start_str else 0
        end = int(end_str) if end_str else file_size - 1
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid range header",
        )
    if end >= file_size:
        end = file_size - 1
    if start < 0 or start > end or start >= file_size:
        raise HTTPException(
            status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE,
            detail="Invalid range",
        )
    return start, end


def _guess_mime(file_path: str) -> str:
    ctype, _ = mimetypes.guess_type(file_path)
    if not ctype:
        ext = Path(file_path).suffix.lower()
        if ext == ".mp4":
            ctype = "video/mp4"
        elif ext == ".webm":
            ctype = "video/webm"
        elif ext == ".mkv":
            ctype = "video/x-matroska"
        elif ext == ".mov":
            ctype = "video/quicktime"
        else:
            ctype = "application/octet-stream"
    return ctype


@router.post("/tokens", response_model=DownloadTokenResponse, status_code=status.HTTP_201_CREATED)
async def create_download_token(
    payload: DownloadRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(select(Episode).where(Episode.id == payload.episode_id))
    episode = res.scalar_one_or_none()
    if episode is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")
    sres = await db.execute(select(Series).where(Series.id == episode.series_id))
    series = sres.scalar_one_or_none()
    if series is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Series not found")

    try:
        await resolve_access(db, user, episode, series, deduct_coins=False)
    except AccessDenied as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Episode not accessible for download",
            headers={"reason": e.reason.value},
        )

    existing_res = await db.execute(
        select(DownloadToken).where(
            DownloadToken.user_id == user.id,
            DownloadToken.episode_id == episode.id,
            DownloadToken.is_active.is_(True),
            DownloadToken.expires_at > datetime.utcnow(),
        )
    )
    existing = existing_res.scalar_one_or_none()
    if existing is not None:
        existing.is_active = False

    token_value = uuid4().hex
    expires_at = datetime.utcnow() + timedelta(hours=TOKEN_TTL_HOURS)
    dt = DownloadToken(
        user_id=user.id,
        episode_id=episode.id,
        series_id=series.id,
        token=token_value,
        expires_at=expires_at,
        is_active=True,
    )
    db.add(dt)
    await db.commit()
    await db.refresh(dt)

    return DownloadTokenResponse(
        token=token_value,
        download_url=f"/downloads/file/{token_value}",
        expires_at=expires_at,
        episode_id=episode.id,
        episode_title=episode.title,
        series_title=series.title,
        duration_seconds=episode.duration_seconds or 0,
    )


@router.get("/tokens", response_model=DownloadTokenListResponse)
async def list_download_tokens(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(
        select(DownloadToken, Episode, Series)
        .join(Episode, Episode.id == DownloadToken.episode_id)
        .join(Series, Series.id == DownloadToken.series_id, isouter=True)
        .where(
            DownloadToken.user_id == user.id,
            DownloadToken.is_active.is_(True),
        )
        .order_by(desc(DownloadToken.created_at))
    )
    items: list[DownloadedEpisodeInfo] = []
    for dt, ep, series in res.all():
        items.append(
            DownloadedEpisodeInfo(
                episode_id=ep.id,
                episode_title=ep.title,
                series_id=ep.series_id,
                series_title=series.title if series is not None else None,
                episode_number=ep.episode_number or 0,
                duration_seconds=ep.duration_seconds or 0,
                thumbnail_url=ep.thumbnail_url,
                downloaded_at=dt.created_at,
            )
        )
    return DownloadTokenListResponse(tokens=items, total=len(items))


@router.get("/file/{token}")
async def download_file(token: str, request: Request, db: AsyncSession = Depends(get_db)):
    res = await db.execute(select(DownloadToken).where(DownloadToken.token == token))
    dt = res.scalar_one_or_none()
    if dt is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Token not found")
    if not dt.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Token revoked")
    if dt.expires_at.tzinfo is not None:
        now = datetime.utcnow().replace(tzinfo=dt.expires_at.tzinfo)
    else:
        now = datetime.utcnow()
    if dt.expires_at < now:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Token expired")

    ep_res = await db.execute(select(Episode).where(Episode.id == dt.episode_id))
    episode = ep_res.scalar_one_or_none()
    if episode is None or not episode.video_url:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video file not found")

    file_path = _resolve_file_path(episode.video_url)
    if not file_path or not os.path.exists(file_path):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="File not found on disk")

    file_size = os.path.getsize(file_path)
    mime_type = _guess_mime(file_path)
    filename = f"episode_{episode.id}{Path(file_path).suffix or '.mp4'}"
    disposition = f'attachment; filename="{filename}"'
    range_header = request.headers.get("range")

    if range_header:
        start, end = _parse_range(range_header, file_size)
        chunk_size = end - start + 1

        def iter_file() -> typing.Iterator[bytes]:
            with open(file_path, "rb") as f:
                f.seek(start)
                remaining = chunk_size
                while remaining > 0:
                    chunk = f.read(min(CHUNK_SIZE, remaining))
                    if not chunk:
                        break
                    remaining -= len(chunk)
                    yield chunk

        headers = {
            "Content-Range": f"bytes {start}-{end}/{file_size}",
            "Accept-Ranges": "bytes",
            "Content-Length": str(chunk_size),
            "Content-Disposition": disposition,
        }
        return StreamingResponse(
            iter_file(),
            media_type=mime_type,
            status_code=status.HTTP_206_PARTIAL_CONTENT,
            headers=headers,
        )

    def iter_full() -> typing.Iterator[bytes]:
        with open(file_path, "rb") as f:
            while True:
                chunk = f.read(CHUNK_SIZE)
                if not chunk:
                    break
                yield chunk

    headers = {
        "Accept-Ranges": "bytes",
        "Content-Length": str(file_size),
        "Content-Disposition": disposition,
    }
    return StreamingResponse(
        iter_full(),
        media_type=mime_type,
        status_code=status.HTTP_200_OK,
        headers=headers,
    )


@router.delete("/tokens/{episode_id}")
async def revoke_token_for_episode(
    episode_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(
        select(DownloadToken).where(
            DownloadToken.user_id == user.id,
            DownloadToken.episode_id == episode_id,
            DownloadToken.is_active.is_(True),
        )
    )
    dt = res.scalar_one_or_none()
    if dt is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Download token not found")
    dt.is_active = False
    await db.commit()
    return {"deleted": True}


@router.delete("/tokens")
async def revoke_all_tokens(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(
        select(DownloadToken).where(
            DownloadToken.user_id == user.id,
            DownloadToken.is_active.is_(True),
        )
    )
    tokens = list(res.scalars().all())
    count = 0
    for dt in tokens:
        dt.is_active = False
        count += 1
    await db.commit()
    return {"deleted": True, "count": count}
