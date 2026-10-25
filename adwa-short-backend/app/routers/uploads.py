from __future__ import annotations

import mimetypes
import uuid
from pathlib import Path
from typing import AsyncIterator

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from fastapi.responses import StreamingResponse

from app.config import settings
from app.database import get_db
from app.deps import get_current_admin
from app.models.user import User
from app.schemas.admin import UploadResponse
from app.services.audit import log_activity

router = APIRouter(prefix="/uploads", tags=["uploads"])

ALLOWED_POSTER_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
ALLOWED_VIDEO_EXTS = {
    ".mp4",
    ".mov",
    ".webm",
    ".m4v",
    ".mkv",
    ".avi",
    ".flv",
    ".wmv",
    ".mpeg",
    ".mpg",
    ".3gp",
    ".ts",
    ".m3u8",
}
VIDEO_MIME_FALLBACK = {
    ".mp4": "video/mp4",
    ".mov": "video/quicktime",
    ".webm": "video/webm",
    ".m4v": "video/x-m4v",
    ".mkv": "video/x-matroska",
    ".avi": "video/x-msvideo",
    ".flv": "video/x-flv",
    ".wmv": "video/x-ms-wmv",
    ".mpeg": "video/mpeg",
    ".mpg": "video/mpeg",
    ".3gp": "video/3gpp",
    ".ts": "video/mp2t",
    ".m3u8": "application/vnd.apple.mpegurl",
}

CHUNK = 1024 * 1024


def _safe_ext(filename: str) -> str:
    return Path(filename).suffix.lower()


def _video_content_type(filename: str) -> str:
    ext = _safe_ext(filename)
    ctype, _ = mimetypes.guess_type(filename)
    if not ctype or ctype == "application/octet-stream":
        ctype = VIDEO_MIME_FALLBACK.get(ext, "application/octet-stream")
    return ctype


def _ensure_dirs() -> None:
    Path(settings.UPLOAD_DIR, "posters").mkdir(parents=True, exist_ok=True)
    Path(settings.UPLOAD_DIR, "videos").mkdir(parents=True, exist_ok=True)


def _optimize_video_faststart(path: Path) -> None:
    tmp_path = path.with_suffix(path.suffix + ".faststart.tmp")
    try:
        import av
        inp = av.open(str(path))
        out = av.open(str(tmp_path), "w", format="mp4", options={"movflags": "+faststart"})
        stream_map = {}
        for stream in inp.streams:
            if stream.type in ("video", "audio"):
                out_stream = out.add_stream_from_template(stream)
                stream_map[stream.index] = out_stream
        for packet in inp.demux():
            if packet.stream.index in stream_map:
                out_stream = stream_map[packet.stream.index]
                if packet.dts is None:
                    continue
                packet.rescale_ts(out_stream.time_base)
                packet.stream = out_stream
                out.mux(packet)
        inp.close()
        out.close()
        if tmp_path.exists() and tmp_path.stat().st_size > 0:
            tmp_path.replace(path)
    except Exception:
        if tmp_path.exists():
            tmp_path.unlink(missing_ok=True)


def _validate_video(file: UploadFile) -> str:
    name = file.filename or ""
    ext = _safe_ext(name)
    if ext in ALLOWED_VIDEO_EXTS:
        return ext or ".mp4"
    ctype = (file.content_type or "").split(";")[0].strip().lower()
    if ctype.startswith("video/"):
        return ext or ".mp4"
    raise HTTPException(
        status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
        detail=f"Unsupported video format (filename={name!r}, content_type={file.content_type!r}). Allowed extensions: {sorted(ALLOWED_VIDEO_EXTS)}",
    )


@router.post("/poster", response_model=UploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_poster(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    ext = _safe_ext(file.filename or "poster.jpg")
    if ext not in ALLOWED_POSTER_EXTS:
        raise HTTPException(status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail=f"Unsupported poster extension: {ext}")
    _ensure_dirs()
    fname = f"{uuid.uuid4().hex}{ext}"
    target = Path(settings.UPLOAD_DIR, "posters", fname)
    data = await file.read()
    if len(data) > settings.MAX_UPLOAD_SIZE:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="File too large")
    target.write_bytes(data)
    await log_activity(db, admin, "upload", "media", None, f"Uploaded poster '{file.filename or fname}' ({len(data)} bytes)")
    await db.commit()
    return UploadResponse(url=f"/uploads/posters/{fname}", filename=fname, size_bytes=len(data))


@router.post("/video", response_model=UploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_video(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    ext = _validate_video(file)
    _ensure_dirs()
    fname = f"{uuid.uuid4().hex}{ext}"
    target = Path(settings.UPLOAD_DIR, "videos", fname)
    size = 0
    max_bytes = settings.MAX_UPLOAD_SIZE
    with target.open("wb") as f:
        while True:
            chunk = await file.read(CHUNK)
            if not chunk:
                break
            size += len(chunk)
            if size > max_bytes:
                f.close()
                target.unlink(missing_ok=True)
                max_mb = max_bytes // (1024 * 1024)
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail=f"Video too large (max {max_mb}MB)",
                )
            f.write(chunk)
    _optimize_video_faststart(target)
    final_size = target.stat().st_size
    await log_activity(db, admin, "upload", "media", None, f"Uploaded video '{file.filename or fname}' ({final_size} bytes)")
    await db.commit()
    return UploadResponse(url=f"/uploads/videos/{fname}", filename=fname, size_bytes=final_size)


def _is_safe_filename(filename: str) -> bool:
    if not filename:
        return False
    if "/" in filename or "\\" in filename:
        return False
    if ".." in filename:
        return False
    if Path(filename).name != filename:
        return False
    return True


async def _stream_full(file_path: Path) -> AsyncIterator[bytes]:
    with file_path.open("rb") as fh:
        while True:
            buf = fh.read(CHUNK)
            if not buf:
                break
            yield buf


async def _stream_range(file_path: Path, start: int, length: int) -> AsyncIterator[bytes]:
    remaining = length
    with file_path.open("rb") as fh:
        fh.seek(start)
        while remaining > 0:
            buf = fh.read(min(CHUNK, remaining))
            if not buf:
                break
            remaining -= len(buf)
            yield buf


@router.get("/videos/{filename}")
async def serve_video(filename: str, request: Request):
    if not _is_safe_filename(filename):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid filename")
    file_path = Path(settings.UPLOAD_DIR, "videos", filename)
    if not file_path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video not found")
    file_size = file_path.stat().st_size
    content_type = _video_content_type(filename)
    range_header = request.headers.get("range")
    base_headers = {
        "Accept-Ranges": "bytes",
        "Content-Type": content_type,
        "Cache-Control": "public, max-age=3600",
    }
    if range_header:
        spec = range_header.strip()
        if spec.startswith("bytes="):
            spec = spec[len("bytes="):]
        start_str, _, end_str = spec.partition("-")
        try:
            start = int(start_str) if start_str else 0
            end = int(end_str) if end_str else file_size - 1
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid range")
        if end >= file_size:
            end = file_size - 1
        if start < 0 or start > end or start >= file_size:
            raise HTTPException(status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE, detail="Invalid range")
        length = end - start + 1
        headers = dict(base_headers)
        headers["Content-Range"] = f"bytes {start}-{end}/{file_size}"
        headers["Content-Length"] = str(length)
        return StreamingResponse(
            _stream_range(file_path, start, length),
            status_code=status.HTTP_206_PARTIAL_CONTENT,
            headers=headers,
        )
    headers = dict(base_headers)
    headers["Content-Length"] = str(file_size)
    return StreamingResponse(_stream_full(file_path), status_code=status.HTTP_200_OK, headers=headers)
