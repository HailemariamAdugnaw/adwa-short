from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio


async def test_promotional_splash_endpoint_empty(client):
    res = await client.get("/api/v1/promotions/splash")
    assert res.status_code == 200
    data = res.json()
    assert "enabled" in data
    assert "title" in data
    assert "action_text" in data
    assert data["action_text"] == "Watch Now"


async def test_promotional_splash_endpoint_with_series(client, admin_headers):
    # Create category and series with poster
    cat = await client.post("/categories", json={"name": "Romance", "is_active": True}, headers=admin_headers)
    assert cat.status_code == 201
    cat_id = cat.json()["id"]

    series_res = await client.post(
        "/series",
        json={
            "title": "Love in the In-Between",
            "category_id": cat_id,
            "type": "series",
            "is_published": True,
            "is_hot": True,
            "poster_url": "https://example.com/posters/love_in_between.jpg",
            "banner_url": "https://example.com/banners/love_in_between.jpg",
            "free_episode_count": 3,
            "total_episodes": 45,
        },
        headers=admin_headers,
    )
    assert series_res.status_code == 201
    created_id = str(series_res.json()["id"])

    # Test all aliases
    for path in (
        "/api/v1/promotions/splash",
        "/promotions/splash",
        "/api/v1/featured-poster",
        "/featured-poster",
    ):
        res = await client.get(path)
        assert res.status_code == 200
        data = res.json()
        assert data["enabled"] is True
        assert data["series_id"] == created_id
        assert data["title"] == "Love in the In-Between"
        assert data["poster_url"] == "https://example.com/posters/love_in_between.jpg"
        assert data["action_text"] == "Watch Now"
        assert data["countdown_seconds"] == 5
