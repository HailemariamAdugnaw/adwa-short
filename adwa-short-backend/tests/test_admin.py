from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio


async def _make_series(client, admin_headers, published=False):
    cat = await client.post("/categories", json={"name": "Drama"}, headers=admin_headers)
    cat_id = cat.json()["id"]
    res = await client.post(
        "/series",
        json={
            "title": "Admin Test Series",
            "category_id": cat_id,
            "type": "series",
            "is_published": published,
            "free_episode_count": 1,
            "total_episodes": 2,
        },
        headers=admin_headers,
    )
    return res.json()["id"]


async def test_admin_publish_series(client, admin_headers):
    sid = await _make_series(client, admin_headers, published=False)
    res = await client.post(f"/admin/content/series/{sid}/publish", headers=admin_headers)
    assert res.status_code == 200
    assert res.json()["is_published"] is True


async def test_admin_unpublish_series(client, admin_headers):
    sid = await _make_series(client, admin_headers, published=True)
    res = await client.post(f"/admin/content/series/{sid}/unpublish", headers=admin_headers)
    assert res.status_code == 200
    assert res.json()["is_published"] is False


async def test_non_admin_cannot_publish(client, auth_headers):
    res = await client.post("/admin/content/series/1/publish", headers=auth_headers)
    assert res.status_code == 403


async def test_admin_list_unpublished(client, admin_headers):
    await _make_series(client, admin_headers, published=False)
    res = await client.get("/admin/content/unpublished", headers=admin_headers)
    assert res.status_code == 200
    assert len(res.json()) == 1


async def test_audit_log(client, admin_headers):
    sid = await _make_series(client, admin_headers, published=False)
    await client.post(f"/admin/content/series/{sid}/publish", headers=admin_headers)
    res = await client.get("/admin/content/audit", headers=admin_headers)
    assert res.status_code == 200
    assert any(a["action"] == "publish" for a in res.json())


async def test_admin_user_management(client, admin_headers, demo_user):
    u, _ = demo_user
    res = await client.get("/admin/users", headers=admin_headers)
    assert res.status_code == 200
    assert any(usr["id"] == u.id for usr in res.json())

    ban = await client.post(f"/admin/users/{u.id}/ban", headers=admin_headers)
    assert ban.status_code == 200
    assert ban.json()["is_banned"] is True

    unban = await client.post(f"/admin/users/{u.id}/unban", headers=admin_headers)
    assert unban.json()["is_banned"] is False


async def test_analytics_overview(client, admin_headers):
    res = await client.get("/admin/analytics/overview", headers=admin_headers)
    assert res.status_code == 200
    data = res.json()
    for k in ("total_users", "total_series", "active_subscriptions", "total_birr_deposited"):
        assert k in data


async def test_settings_update(client, admin_headers):
    res = await client.put(
        "/settings/max_devices_per_account",
        json={"value": "5"},
        headers=admin_headers,
    )
    assert res.status_code == 200
    assert res.json()["value"] == "5"

    pub = await client.get("/settings/public")
    assert pub.status_code == 200
    assert pub.json()["max_devices_per_account"] == 5
