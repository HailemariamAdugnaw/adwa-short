from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path

import pytest
from sqlalchemy import select

from app.config import settings
from app.database import AsyncSessionLocal
from app.models.download import DownloadToken

pytestmark = pytest.mark.asyncio


async def _make_series(client, admin_headers, title: str, free_episode_count: int = 3):
    cat = await client.post("/categories", json={"name": f"Cat {title}"}, headers=admin_headers)
    cat_id = cat.json()["id"]
    s = await client.post(
        "/series",
        json={
            "title": title,
            "category_id": cat_id,
            "type": "series",
            "is_published": True,
            "free_episode_count": free_episode_count,
            "total_episodes": 3,
        },
        headers=admin_headers,
    )
    return s.json()["id"]


async def _make_episode(
    client,
    admin_headers,
    series_id: int,
    episode_number: int,
    coin_cost: int = 0,
    video_url: str | None = None,
    duration_seconds: int = 120,
):
    payload = {
        "series_id": series_id,
        "episode_number": episode_number,
        "title": f"Episode {episode_number}",
        "coin_cost": coin_cost,
        "duration_seconds": duration_seconds,
    }
    if video_url is not None:
        payload["video_url"] = video_url
    ep = await client.post("/episodes", json=payload, headers=admin_headers)
    assert ep.status_code == 201, ep.text
    return ep.json()["id"]


async def test_create_download_token_for_free_episode(client, admin_headers, auth_headers):
    series_id = await _make_series(client, admin_headers, "Free Series", free_episode_count=3)
    episode_id = await _make_episode(client, admin_headers, series_id, episode_number=1)

    res = await client.post("/downloads/tokens", json={"episode_id": episode_id}, headers=auth_headers)
    assert res.status_code == 201, res.text
    body = res.json()
    assert "token" in body
    assert len(body["token"]) > 0
    assert body["download_url"] == f"/downloads/file/{body['token']}"
    assert body["episode_id"] == episode_id
    assert body["episode_title"] == "Episode 1"
    assert body["series_title"] == "Free Series"
    assert body["duration_seconds"] == 120
    assert "expires_at" in body


async def test_create_download_token_for_locked_episode(client, admin_headers, auth_headers):
    series_id = await _make_series(client, admin_headers, "Locked Series", free_episode_count=1)
    episode_id = await _make_episode(
        client, admin_headers, series_id, episode_number=2, coin_cost=0
    )

    res = await client.post("/downloads/tokens", json={"episode_id": episode_id}, headers=auth_headers)
    assert res.status_code == 403, res.text
    body = res.json()
    assert body["detail"] == "Episode not accessible for download"


async def test_list_download_tokens(client, admin_headers, auth_headers):
    series_id = await _make_series(client, admin_headers, "List Series", free_episode_count=3)
    ep1 = await _make_episode(client, admin_headers, series_id, episode_number=1)
    ep2 = await _make_episode(client, admin_headers, series_id, episode_number=2)

    r1 = await client.post("/downloads/tokens", json={"episode_id": ep1}, headers=auth_headers)
    assert r1.status_code == 201
    r2 = await client.post("/downloads/tokens", json={"episode_id": ep2}, headers=auth_headers)
    assert r2.status_code == 201

    res = await client.get("/downloads/tokens", headers=auth_headers)
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["total"] == 2
    episode_ids = {t["episode_id"] for t in body["tokens"]}
    assert ep1 in episode_ids
    assert ep2 in episode_ids
    for t in body["tokens"]:
        assert "episode_title" in t
        assert "series_title" in t
        assert t["series_title"] == "List Series"
        assert "thumbnail_url" in t
        assert "downloaded_at" in t
        assert "episode_number" in t


async def test_download_file_streams_video(client, admin_headers, auth_headers, tmp_path):
    upload_dir = Path(settings.UPLOAD_DIR)
    videos_dir = upload_dir / "videos"
    videos_dir.mkdir(parents=True, exist_ok=True)
    mock_name = "test_download_stream.mp4"
    mock_file = videos_dir / mock_name
    content = b"FAKE_MP4_CONTENT_" * 256
    mock_file.write_bytes(content)
    try:
        series_id = await _make_series(client, admin_headers, "Stream Series", free_episode_count=3)
        episode_id = await _make_episode(
            client,
            admin_headers,
            series_id,
            episode_number=1,
            video_url=f"/uploads/videos/{mock_name}",
        )

        tok_res = await client.post("/downloads/tokens", json={"episode_id": episode_id}, headers=auth_headers)
        assert tok_res.status_code == 201, tok_res.text
        token = tok_res.json()["token"]

        res = await client.get(f"/downloads/file/{token}")
        assert res.status_code == 200, res.text
        assert res.content == content
        assert "attachment" in res.headers.get("content-disposition", "")
        assert f"episode_{episode_id}" in res.headers.get("content-disposition", "")
        assert res.headers.get("accept-ranges") == "bytes"
        assert res.headers.get("content-length") == str(len(content))

        range_res = await client.get(
            f"/downloads/file/{token}",
            headers={"range": "bytes=0-15"},
        )
        assert range_res.status_code == 206, range_res.text
        assert range_res.content == content[:16]
        assert range_res.headers.get("content-range") == f"bytes 0-15/{len(content)}"
        assert range_res.headers.get("content-length") == "16"
    finally:
        mock_file.unlink(missing_ok=True)


async def test_download_file_expired_token_returns_403(client, admin_headers, auth_headers):
    upload_dir = Path(settings.UPLOAD_DIR)
    videos_dir = upload_dir / "videos"
    videos_dir.mkdir(parents=True, exist_ok=True)
    mock_name = "test_download_expired.mp4"
    mock_file = videos_dir / mock_name
    mock_file.write_bytes(b"DATA")
    try:
        series_id = await _make_series(client, admin_headers, "Expired Series", free_episode_count=3)
        episode_id = await _make_episode(
            client,
            admin_headers,
            series_id,
            episode_number=1,
            video_url=f"/uploads/videos/{mock_name}",
        )

        tok_res = await client.post("/downloads/tokens", json={"episode_id": episode_id}, headers=auth_headers)
        assert tok_res.status_code == 201
        token = tok_res.json()["token"]

        async with AsyncSessionLocal() as s:
            r = await s.execute(select(DownloadToken).where(DownloadToken.token == token))
            dt = r.scalar_one()
            dt.expires_at = datetime.utcnow() - timedelta(hours=1)
            await s.commit()

        res = await client.get(f"/downloads/file/{token}")
        assert res.status_code == 403, res.text
        assert "expired" in res.json()["detail"].lower()
    finally:
        mock_file.unlink(missing_ok=True)


async def test_download_file_revoked_token_returns_403(client, admin_headers, auth_headers):
    series_id = await _make_series(client, admin_headers, "Revoke Single Series", free_episode_count=3)
    episode_id = await _make_episode(client, admin_headers, series_id, episode_number=1)

    tok_res = await client.post("/downloads/tokens", json={"episode_id": episode_id}, headers=auth_headers)
    assert tok_res.status_code == 201
    token = tok_res.json()["token"]

    del_res = await client.delete(f"/downloads/tokens/{episode_id}", headers=auth_headers)
    assert del_res.status_code == 200, del_res.text
    assert del_res.json() == {"deleted": True}

    res = await client.get(f"/downloads/file/{token}")
    assert res.status_code == 403, res.text
    assert "revoked" in res.json()["detail"].lower()


async def test_revoke_token_by_episode_id(client, admin_headers, auth_headers):
    series_id = await _make_series(client, admin_headers, "Revoke By Ep Series", free_episode_count=3)
    ep1 = await _make_episode(client, admin_headers, series_id, episode_number=1)
    ep2 = await _make_episode(client, admin_headers, series_id, episode_number=2)

    await client.post("/downloads/tokens", json={"episode_id": ep1}, headers=auth_headers)
    await client.post("/downloads/tokens", json={"episode_id": ep2}, headers=auth_headers)

    res = await client.delete(f"/downloads/tokens/{ep1}", headers=auth_headers)
    assert res.status_code == 200, res.text
    assert res.json() == {"deleted": True}

    listing = await client.get("/downloads/tokens", headers=auth_headers)
    assert listing.status_code == 200
    body = listing.json()
    assert body["total"] == 1
    assert body["tokens"][0]["episode_id"] == ep2


async def test_revoke_token_by_episode_id_not_found(client, admin_headers, auth_headers):
    res = await client.delete("/downloads/tokens/999999", headers=auth_headers)
    assert res.status_code == 404


async def test_revoke_all_tokens(client, admin_headers, auth_headers):
    series_id = await _make_series(client, admin_headers, "Revoke All Series", free_episode_count=3)
    ep1 = await _make_episode(client, admin_headers, series_id, episode_number=1)
    ep2 = await _make_episode(client, admin_headers, series_id, episode_number=2)
    ep3 = await _make_episode(client, admin_headers, series_id, episode_number=3)

    await client.post("/downloads/tokens", json={"episode_id": ep1}, headers=auth_headers)
    await client.post("/downloads/tokens", json={"episode_id": ep2}, headers=auth_headers)
    await client.post("/downloads/tokens", json={"episode_id": ep3}, headers=auth_headers)

    res = await client.delete("/downloads/tokens", headers=auth_headers)
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["deleted"] is True
    assert body["count"] == 3

    listing = await client.get("/downloads/tokens", headers=auth_headers)
    assert listing.status_code == 200
    assert listing.json()["total"] == 0


async def test_create_token_requires_auth(client):
    res = await client.post("/downloads/tokens", json={"episode_id": 1})
    assert res.status_code == 401


async def test_list_tokens_requires_auth(client):
    res = await client.get("/downloads/tokens")
    assert res.status_code == 401


async def test_create_token_unknown_episode(client, auth_headers):
    res = await client.post("/downloads/tokens", json={"episode_id": 999999}, headers=auth_headers)
    assert res.status_code == 404
