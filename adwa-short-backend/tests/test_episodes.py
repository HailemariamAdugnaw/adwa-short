from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio


async def _seed_series_with_episodes(client, admin_headers, published_count=2, draft_count=1):
    cat = await client.post("/categories", json={"name": "Drama"}, headers=admin_headers)
    cat_id = cat.json()["id"]
    s = await client.post(
        "/series",
        json={
            "title": "Episode Publish Series",
            "category_id": cat_id,
            "type": "series",
            "is_published": True,
            "free_episode_count": 1,
            "total_episodes": published_count + draft_count,
        },
        headers=admin_headers,
    )
    series_id = s.json()["id"]
    created = []
    for n in range(1, published_count + draft_count + 1):
        ep = await client.post(
            "/episodes",
            json={
                "series_id": series_id,
                "episode_number": n,
                "title": f"Episode {n}",
                "coin_cost": 0,
            },
            headers=admin_headers,
        )
        assert ep.status_code == 201
        created.append(ep.json()["id"])
    for ep_id in created[:published_count]:
        pub = await client.post(f"/admin/content/episodes/{ep_id}/publish", headers=admin_headers)
        assert pub.status_code == 200
    return series_id, created


async def test_admin_can_publish_episode(client, admin_headers):
    cat = await client.post("/categories", json={"name": "Romance"}, headers=admin_headers)
    cat_id = cat.json()["id"]
    s = await client.post(
        "/series",
        json={"title": "S1", "category_id": cat_id, "is_published": True},
        headers=admin_headers,
    )
    series_id = s.json()["id"]
    ep = await client.post(
        "/episodes",
        json={"series_id": series_id, "episode_number": 1, "title": "Pilot"},
        headers=admin_headers,
    )
    ep_id = ep.json()["id"]
    assert ep.json()["is_published"] is False
    assert ep.json()["published_at"] is None
    res = await client.post(f"/admin/content/episodes/{ep_id}/publish", headers=admin_headers)
    assert res.status_code == 200
    body = res.json()
    assert body["is_published"] is True
    assert body["published_at"] is not None


async def test_admin_can_unpublish_episode(client, admin_headers):
    series_id, ep_ids = await _seed_series_with_episodes(client, admin_headers, published_count=1, draft_count=0)
    ep_id = ep_ids[0]
    res = await client.post(f"/admin/content/episodes/{ep_id}/unpublish", headers=admin_headers)
    assert res.status_code == 200
    body = res.json()
    assert body["is_published"] is False


async def test_non_admin_cannot_publish(client, auth_headers):
    res = await client.post("/admin/content/episodes/1/publish", headers=auth_headers)
    assert res.status_code == 403


async def test_non_admin_cannot_unpublish(client, auth_headers):
    res = await client.post("/admin/content/episodes/1/unpublish", headers=auth_headers)
    assert res.status_code == 403


async def test_public_listing_excludes_unpublished(client, admin_headers):
    series_id, ep_ids = await _seed_series_with_episodes(
        client, admin_headers, published_count=2, draft_count=1
    )
    res = await client.get("/episodes", params={"series_id": series_id})
    assert res.status_code == 200
    ids = [e["id"] for e in res.json()]
    assert ep_ids[0] in ids
    assert ep_ids[1] in ids
    assert ep_ids[2] not in ids


async def test_admin_listing_includes_unpublished(client, admin_headers):
    series_id, ep_ids = await _seed_series_with_episodes(
        client, admin_headers, published_count=2, draft_count=1
    )
    res = await client.get(
        "/episodes",
        params={"series_id": series_id},
        headers=admin_headers,
    )
    assert res.status_code == 200
    ids = [e["id"] for e in res.json()]
    assert ep_ids[0] in ids
    assert ep_ids[1] in ids
    assert ep_ids[2] in ids


async def test_public_series_detail_excludes_unpublished_episodes(client, admin_headers):
    series_id, ep_ids = await _seed_series_with_episodes(
        client, admin_headers, published_count=2, draft_count=1
    )
    res = await client.get(f"/series/{series_id}")
    assert res.status_code == 200
    ids = [e["id"] for e in res.json()["episodes"]]
    assert ep_ids[0] in ids
    assert ep_ids[1] in ids
    assert ep_ids[2] not in ids


async def test_admin_series_detail_includes_unpublished_episodes(client, admin_headers):
    series_id, ep_ids = await _seed_series_with_episodes(
        client, admin_headers, published_count=2, draft_count=1
    )
    res = await client.get(f"/series/{series_id}", headers=admin_headers)
    assert res.status_code == 200
    ids = [e["id"] for e in res.json()["episodes"]]
    assert ep_ids[0] in ids
    assert ep_ids[1] in ids
    assert ep_ids[2] in ids


async def test_public_get_unpublished_episode_returns_404(client, admin_headers):
    _, ep_ids = await _seed_series_with_episodes(
        client, admin_headers, published_count=0, draft_count=1
    )
    res = await client.get(f"/episodes/{ep_ids[0]}")
    assert res.status_code == 404


async def test_admin_get_unpublished_episode_ok(client, admin_headers):
    _, ep_ids = await _seed_series_with_episodes(
        client, admin_headers, published_count=0, draft_count=1
    )
    res = await client.get(f"/episodes/{ep_ids[0]}", headers=admin_headers)
    assert res.status_code == 200
    assert res.json()["is_published"] is False


async def test_publish_unknown_episode_returns_404(client, admin_headers):
    res = await client.post("/admin/content/episodes/999999/publish", headers=admin_headers)
    assert res.status_code == 404


async def test_publish_writes_audit_log(client, admin_headers):
    series_id, ep_ids = await _seed_series_with_episodes(
        client, admin_headers, published_count=0, draft_count=1
    )
    await client.post(f"/admin/content/episodes/{ep_ids[0]}/publish", headers=admin_headers)
    res = await client.get("/admin/content/audit", headers=admin_headers)
    assert any(
        a["action"] == "publish" and a["entity_type"] == "episode" and a["entity_id"] == ep_ids[0]
        for a in res.json()
    )
