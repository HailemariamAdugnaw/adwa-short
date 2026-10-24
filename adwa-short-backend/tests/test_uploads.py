from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio


async def test_upload_video_accepts_mkv(client, admin_headers):
    res = await client.post(
        "/uploads/video",
        files={"file": ("episode.mkv", b"0x12 0x34 0x56 0x78 fake-mkv", "video/x-matroska")},
        headers=admin_headers,
    )
    assert res.status_code == 201, res.text
    data = res.json()
    assert data["url"].startswith("/uploads/videos/")
    assert data["filename"].endswith(".mkv")


async def test_upload_video_accepts_mov_via_extension(client, admin_headers):
    res = await client.post(
        "/uploads/video",
        files={"file": ("clip.mov", b"\x00\x00\x00 ftyp", "application/octet-stream")},
        headers=admin_headers,
    )
    assert res.status_code == 201, res.text
    assert res.json()["filename"].endswith(".mov")


async def test_upload_video_rejects_non_video(client, admin_headers):
    res = await client.post(
        "/uploads/video",
        files={"file": ("notes.txt", b"hello", "text/plain")},
        headers=admin_headers,
    )
    assert res.status_code == 415


async def test_serve_video_range_request(client, admin_headers):
    payload = bytes(range(256))
    res = await client.post(
        "/uploads/video",
        files={"file": ("clip.mp4", payload, "video/mp4")},
        headers=admin_headers,
    )
    assert res.status_code == 201
    filename = res.json()["filename"]
    url = res.json()["url"]

    head = await client.get(url, headers={**admin_headers, "range": "bytes=0-9"})
    assert head.status_code == 206, head.text
    assert head.headers["content-range"] == f"bytes 0-9/{len(payload)}"
    assert head.headers["content-length"] == "10"
    assert head.headers["content-type"] == "video/mp4"
    assert len(head.content) == 10
    assert head.content == payload[:10]

    full = await client.get(url, headers=admin_headers)
    assert full.status_code == 200
    assert full.headers["content-type"] == "video/mp4"
    assert full.content == payload

    missing = await client.get("/uploads/videos/does-not-exist.mp4", headers=admin_headers)
    assert missing.status_code == 404


async def test_serve_video_correct_mime_for_exotic_formats(client, admin_headers):
    payload = b"fake-mkv-bytes"
    res = await client.post(
        "/uploads/video",
        files={"file": ("clip.mkv", payload, "video/x-matroska")},
        headers=admin_headers,
    )
    assert res.status_code == 201
    url = res.json()["url"]
    assert url.endswith(".mkv")

    full = await client.get(url, headers=admin_headers)
    assert full.status_code == 200
    assert full.headers["content-type"] == "video/x-matroska"
    assert full.headers.get("accept-ranges") == "bytes"

    head = await client.get(url, headers={**admin_headers, "range": "bytes=0-3"})
    assert head.status_code == 206
    assert head.headers["content-type"] == "video/x-matroska"
    assert head.headers["content-range"] == f"bytes 0-3/{len(payload)}"
    assert head.content == payload[:4]
