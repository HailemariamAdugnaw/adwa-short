from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio


async def _make_creator(client, admin_headers, name: str = "Test Creator", split: float = 50.0) -> dict:
    res = await client.post(
        "/creators",
        json={
            "name": name,
            "phone": "+251955500001",
            "email": "creator@test.com",
            "default_revenue_split_pct": split,
            "payment_method": "telebirr",
            "bank_name": "CBE",
        },
        headers=admin_headers,
    )
    assert res.status_code == 201, res.text
    return res.json()


async def test_create_creator(client, admin_headers):
    c = await _make_creator(client, admin_headers, name="Alpha Creator", split=55.0)
    assert c["id"] > 0
    assert c["default_revenue_split_pct"] == 55.0
    assert c["is_active"] is True


async def test_non_admin_cannot_create_creator(client, auth_headers):
    res = await client.post(
        "/creators",
        json={"name": "X", "default_revenue_split_pct": 50.0},
        headers=auth_headers,
    )
    assert res.status_code == 403


async def test_list_creators(client, admin_headers):
    await _make_creator(client, admin_headers, name="Listed One")
    await _make_creator(client, admin_headers, name="Listed Two")
    res = await client.get("/creators", headers=admin_headers)
    assert res.status_code == 200
    assert len(res.json()) >= 2


async def test_get_creator_detail(client, admin_headers):
    c = await _make_creator(client, admin_headers, name="Detail Creator", split=60.0)
    res = await client.get(f"/creators/{c['id']}", headers=admin_headers)
    assert res.status_code == 200
    assert res.json()["default_revenue_split_pct"] == 60.0
    assert "pending_balance_birr" in res.json()


async def test_update_creator(client, admin_headers):
    c = await _make_creator(client, admin_headers, name="Updatable")
    res = await client.put(
        f"/creators/{c['id']}",
        json={"display_name": "Updated Display", "default_revenue_split_pct": 70.0},
        headers=admin_headers,
    )
    assert res.status_code == 200
    assert res.json()["display_name"] == "Updated Display"
    assert res.json()["default_revenue_split_pct"] == 70.0


async def test_deactivate_creator(client, admin_headers):
    c = await _make_creator(client, admin_headers, name="Deactivatable")
    res = await client.delete(f"/creators/{c['id']}", headers=admin_headers)
    assert res.status_code == 200
    assert res.json()["is_active"] is False


async def test_set_custom_split_rule(client, admin_headers):
    c = await _make_creator(client, admin_headers, name="Split Creator", split=50.0)
    cat = await client.post("/categories", json={"name": "CreatorCat"}, headers=admin_headers)
    s = await client.post(
        "/series",
        json={
            "title": "Creator Series",
            "category_id": cat.json()["id"],
            "type": "series",
            "is_published": True,
            "creator_id": c["id"],
            "free_episode_count": 1,
            "total_episodes": 2,
        },
        headers=admin_headers,
    )
    series_id = s.json()["id"]
    ep = await client.post(
        "/episodes",
        json={
            "series_id": series_id,
            "episode_number": 1,
            "title": "E1",
            "creator_id": c["id"],
        },
        headers=admin_headers,
    )
    episode_id = ep.json()["id"]

    res = await client.put(
        f"/creators/{c['id']}/split",
        json={"series_id": series_id, "creator_share_pct": 65.0},
        headers=admin_headers,
    )
    assert res.status_code == 200
    assert res.json()["creator_share_pct"] == 65.0
    assert res.json()["series_id"] == series_id

    res2 = await client.put(
        f"/creators/{c['id']}/split",
        json={"episode_id": episode_id, "creator_share_pct": 75.0},
        headers=admin_headers,
    )
    assert res2.status_code == 200
    assert res2.json()["episode_id"] == episode_id
    assert res2.json()["creator_share_pct"] == 75.0


async def test_creator_content_listing(client, admin_headers):
    c = await _make_creator(client, admin_headers, name="Content Creator")
    cat = await client.post("/categories", json={"name": "ContentCat"}, headers=admin_headers)
    s = await client.post(
        "/series",
        json={
            "title": "Content Series",
            "category_id": cat.json()["id"],
            "type": "series",
            "is_published": True,
            "creator_id": c["id"],
            "free_episode_count": 1,
            "total_episodes": 1,
        },
        headers=admin_headers,
    )
    series_id = s.json()["id"]
    await client.post(
        "/episodes",
        json={"series_id": series_id, "episode_number": 1, "title": "Ep1", "creator_id": c["id"]},
        headers=admin_headers,
    )
    res = await client.get(f"/creators/{c['id']}/content", headers=admin_headers)
    assert res.status_code == 200
    assert any(item["series_id"] == series_id for item in res.json())


async def test_creator_revenue_summary(client, admin_headers):
    c = await _make_creator(client, admin_headers, name="Revenue Creator", split=50.0)
    res = await client.get(f"/creators/{c['id']}/revenue", headers=admin_headers)
    assert res.status_code == 200
    body = res.json()
    assert body["creator_id"] == c["id"]
    assert "by_month" in body
    assert "pending_balance_birr" in body


async def test_create_payout(client, admin_headers):
    from app.database import AsyncSessionLocal
    from app.models.revenue import Creator, RevenueTransaction
    from sqlalchemy import select

    c = await _make_creator(client, admin_headers, name="Payout Creator", split=50.0)
    async with AsyncSessionLocal() as s:
        creator = (await s.execute(select(Creator).where(Creator.id == c["id"]))).scalar_one()
        s.add(
            RevenueTransaction(
                creator_id=creator.id,
                series_id=None,
                episode_id=None,
                user_id=None,
                source_type="coin_payment",
                gross_amount_birr=200.0,
                creator_share_birr=100.0,
                platform_share_birr=100.0,
                reference="test:payout",
            )
        )
        await s.commit()

    res = await client.post(
        f"/creators/{c['id']}/payouts",
        json={"amount_birr": 50.0, "notes": "Monthly payout"},
        headers=admin_headers,
    )
    assert res.status_code == 201, res.text
    assert res.json()["amount_birr"] == 50.0
    assert res.json()["status"] == "pending"

    list_res = await client.get(f"/creators/{c['id']}/payouts", headers=admin_headers)
    assert list_res.status_code == 200
    assert len(list_res.json()) >= 1


async def test_payout_exceeds_pending_balance_rejected(client, admin_headers):
    c = await _make_creator(client, admin_headers, name="Empty Creator")
    res = await client.post(
        f"/creators/{c['id']}/payouts",
        json={"amount_birr": 1000.0, "notes": "Too much"},
        headers=admin_headers,
    )
    assert res.status_code == 400


async def test_get_missing_creator(client, admin_headers):
    res = await client.get("/creators/99999", headers=admin_headers)
    assert res.status_code == 404
