from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio


async def _make_episode(client, admin_headers, title: str = "Reviewed Series") -> int:
    cat = await client.post("/categories", json={"name": "ReviewCat"}, headers=admin_headers)
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


async def test_create_review(client, admin_headers, auth_headers):
    ep_id = await _make_episode(client, admin_headers, title="Create Rev")
    res = await client.post(
        "/reviews",
        json={"episode_id": ep_id, "text": "Great episode!"},
        headers=auth_headers,
    )
    assert res.status_code == 201, res.text
    assert res.json()["text"] == "Great episode!"
    assert res.json()["is_approved"] is True


async def test_review_accepts_long_text(client, admin_headers, auth_headers):
    ep_id = await _make_episode(client, admin_headers, title="Long Rev")
    long_text = "x" * 2000
    res = await client.post(
        "/reviews",
        json={"episode_id": ep_id, "text": long_text},
        headers=auth_headers,
    )
    assert res.status_code == 201, res.text
    assert res.json()["text"] == long_text


async def test_list_episode_reviews(client, admin_headers, auth_headers):
    ep_id = await _make_episode(client, admin_headers, title="List Rev")
    await client.post(
        "/reviews",
        json={"episode_id": ep_id, "text": "First review"},
        headers=auth_headers,
    )
    res = await client.get(f"/reviews/episode/{ep_id}")
    assert res.status_code == 200
    body = res.json()
    assert body["total"] >= 1
    assert body["items"][0]["text"] == "First review"
    assert body["items"][0]["user_display_name"] is not None


async def test_update_own_review(client, admin_headers, auth_headers):
    ep_id = await _make_episode(client, admin_headers, title="Update Rev")
    create = await client.post(
        "/reviews",
        json={"episode_id": ep_id, "text": "Initial"},
        headers=auth_headers,
    )
    review_id = create.json()["id"]
    res = await client.put(
        f"/reviews/{review_id}",
        json={"text": "Updated text"},
        headers=auth_headers,
    )
    assert res.status_code == 200
    assert res.json()["text"] == "Updated text"


async def test_delete_own_review(client, admin_headers, auth_headers):
    ep_id = await _make_episode(client, admin_headers, title="Delete Rev")
    create = await client.post(
        "/reviews",
        json={"episode_id": ep_id, "text": "To be deleted"},
        headers=auth_headers,
    )
    review_id = create.json()["id"]
    res = await client.delete(f"/reviews/{review_id}", headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["deleted"] is True


async def test_admin_list_reviews_with_filter(client, admin_headers, auth_headers):
    ep_id = await _make_episode(client, admin_headers, title="Admin Rev")
    await client.post(
        "/reviews",
        json={"episode_id": ep_id, "text": "Admin sees me"},
        headers=auth_headers,
    )
    res = await client.get(f"/reviews/admin?episode_id={ep_id}", headers=admin_headers)
    assert res.status_code == 200
    body = res.json()
    assert body["total"] >= 1
    assert any(r["text"] == "Admin sees me" for r in body["items"])


async def test_admin_delete_review(client, admin_headers, auth_headers):
    ep_id = await _make_episode(client, admin_headers, title="Admin Delete Rev")
    create = await client.post(
        "/reviews",
        json={"episode_id": ep_id, "text": "Moderate me"},
        headers=auth_headers,
    )
    review_id = create.json()["id"]
    res = await client.delete(f"/reviews/admin/{review_id}", headers=admin_headers)
    assert res.status_code == 200
    assert res.json()["deleted"] is True

    list_res = await client.get(f"/reviews/episode/{ep_id}")
    assert all(r["id"] != review_id for r in list_res.json()["items"])


async def test_non_admin_cannot_access_admin_reviews(client, auth_headers):
    res = await client.get("/reviews/admin", headers=auth_headers)
    assert res.status_code == 403


async def test_user_cannot_edit_other_users_review(client, admin_headers, auth_headers, demo_user):
    ep_id = await _make_episode(client, admin_headers, title="Other Rev")
    create = await client.post(
        "/reviews",
        json={"episode_id": ep_id, "text": "Mine"},
        headers=auth_headers,
    )
    review_id = create.json()["id"]

    await client.post(
        "/auth/register",
        json={"phone": "+251988877766", "password": "pass1234"},
    )
    login2 = await client.post(
        "/auth/login",
        json={"phone": "+251988877766", "password": "pass1234"},
        headers={"X-Device-Id": "other-dev"},
    )
    other_headers = {"Authorization": f"Bearer {login2.json()['access_token']}", "X-Device-Id": "other-dev"}

    res = await client.put(
        f"/reviews/{review_id}",
        json={"text": "Hacked"},
        headers=other_headers,
    )
    assert res.status_code == 403
