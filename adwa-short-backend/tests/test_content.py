from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio


async def _seed_category_and_series(client, admin_headers):
    cat = await client.post("/categories", json={"name": "Drama", "is_active": True}, headers=admin_headers)
    assert cat.status_code == 201
    cat_id = cat.json()["id"]
    s = await client.post(
        "/series",
        json={
            "title": "Test Series",
            "category_id": cat_id,
            "type": "series",
            "is_published": True,
            "free_episode_count": 2,
            "total_episodes": 3,
        },
        headers=admin_headers,
    )
    assert s.status_code == 201
    series_id = s.json()["id"]
    for n in range(1, 4):
        ep = await client.post(
            "/episodes",
            json={
                "series_id": series_id,
                "episode_number": n,
                "title": f"Episode {n}",
                "coin_cost": 50 if n > 2 else 0,
            },
            headers=admin_headers,
        )
        assert ep.status_code == 201
        pub = await client.post(
            f"/admin/content/episodes/{ep.json()['id']}/publish",
            headers=admin_headers,
        )
        assert pub.status_code == 200
        assert pub.json()["is_published"] is True
    return cat_id, series_id


async def test_list_categories_empty(client):
    res = await client.get("/categories")
    assert res.status_code == 200
    assert res.json() == []


async def test_admin_creates_category(client, admin_headers):
    res = await client.post("/categories", json={"name": "Drama", "is_active": True}, headers=admin_headers)
    assert res.status_code == 201


async def test_non_admin_cannot_create_category(client, auth_headers):
    res = await client.post("/categories", json={"name": "Drama"}, headers=auth_headers)
    assert res.status_code == 403


async def test_series_listing(client, admin_headers):
    _, _ = await _seed_category_and_series(client, admin_headers)
    res = await client.get("/series")
    assert res.status_code == 200
    data = res.json()
    assert len(data) == 1
    assert data[0]["title"] == "Test Series"


async def test_series_detail(client, admin_headers):
    _, series_id = await _seed_category_and_series(client, admin_headers)
    res = await client.get(f"/series/{series_id}")
    assert res.status_code == 200
    assert len(res.json()["episodes"]) == 3


async def test_episode_access_free(client, admin_headers, auth_headers):
    _, series_id = await _seed_category_and_series(client, admin_headers)
    res = await client.get("/episodes")
    ep_id = res.json()[0]["id"]
    acc = await client.get(f"/episodes/{ep_id}/access", headers=auth_headers)
    assert acc.status_code == 200
    assert acc.json()["access"] == "allowed"
    assert acc.json()["method"] == "free"


async def test_shelves_home(client, admin_headers):
    await _seed_category_and_series(client, admin_headers)
    res = await client.get("/shelves/home")
    assert res.status_code == 200
    data = res.json()
    assert "shelves" in data
    keys = {s["key"] for s in data["shelves"]}
    assert "hot_new" in keys
    assert "trending" in keys
    assert any(k.startswith("genre_") for k in keys)
