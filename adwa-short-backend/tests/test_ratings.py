from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio


async def _make_episode(client, admin_headers, title: str = "Rated Series") -> int:
    cat = await client.post("/categories", json={"name": "RatingCat"}, headers=admin_headers)
    s = await client.post(
        "/series",
        json={
            "title": title,
            "category_id": cat.json()["id"],
            "type": "series",
            "is_published": True,
            "free_episode_count": 1,
            "total_episodes": 1,
        },
        headers=admin_headers,
    )
    series_id = s.json()["id"]
    ep = await client.post(
        "/episodes",
        json={"series_id": series_id, "episode_number": 1, "title": "E1"},
        headers=admin_headers,
    )
    await client.post(
        f"/admin/content/episodes/{ep.json()['id']}/publish",
        headers=admin_headers,
    )
    return ep.json()["id"]


async def test_create_rating(client, admin_headers, auth_headers):
    ep_id = await _make_episode(client, admin_headers)
    res = await client.post(
        "/ratings",
        json={"episode_id": ep_id, "rating": 5},
        headers=auth_headers,
    )
    assert res.status_code == 200, res.text
    assert res.json()["rating"] == 5
    assert res.json()["episode_id"] == ep_id


async def test_update_rating(client, admin_headers, auth_headers):
    ep_id = await _make_episode(client, admin_headers, title="Update Series")
    await client.post("/ratings", json={"episode_id": ep_id, "rating": 3}, headers=auth_headers)
    res = await client.post("/ratings", json={"episode_id": ep_id, "rating": 5}, headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["rating"] == 5


async def test_invalid_rating_value(client, admin_headers, auth_headers):
    ep_id = await _make_episode(client, admin_headers, title="Invalid Series")
    res = await client.post(
        "/ratings",
        json={"episode_id": ep_id, "rating": 6},
        headers=auth_headers,
    )
    assert res.status_code == 422


async def test_rating_aggregate(client, admin_headers, auth_headers, demo_user):
    ep_id = await _make_episode(client, admin_headers, title="Agg Series")
    await client.post("/ratings", json={"episode_id": ep_id, "rating": 5}, headers=auth_headers)

    res = await client.get(f"/ratings/episode/{ep_id}")
    assert res.status_code == 200
    body = res.json()
    assert body["episode_id"] == ep_id
    assert body["count"] == 1
    assert body["average"] == 5.0
    assert body["distribution"]["5"] == 1
    assert body["distribution"]["1"] == 0


async def test_my_ratings(client, admin_headers, auth_headers):
    ep_id = await _make_episode(client, admin_headers, title="My Series")
    await client.post("/ratings", json={"episode_id": ep_id, "rating": 4}, headers=auth_headers)
    res = await client.get("/ratings/my", headers=auth_headers)
    assert res.status_code == 200
    assert any(r["episode_id"] == ep_id for r in res.json())


async def test_delete_my_rating(client, admin_headers, auth_headers):
    ep_id = await _make_episode(client, admin_headers, title="Del Series")
    await client.post("/ratings", json={"episode_id": ep_id, "rating": 4}, headers=auth_headers)
    res = await client.delete(f"/ratings/{ep_id}", headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["deleted"] is True

    agg = await client.get(f"/ratings/episode/{ep_id}")
    assert agg.json()["count"] == 0


async def test_unauthenticated_cannot_rate(client, admin_headers):
    ep_id = await _make_episode(client, admin_headers, title="Unauth Series")
    res = await client.post("/ratings", json={"episode_id": ep_id, "rating": 5})
    assert res.status_code == 401


async def test_rating_aggregate_missing_episode(client):
    res = await client.get("/ratings/episode/99999")
    assert res.status_code == 404
