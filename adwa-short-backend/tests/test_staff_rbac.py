from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio


async def test_super_admin_staff_crud(client, admin_headers):
    # 1. List staff accounts (super_admin only)
    res = await client.get("/admin/staff", headers=admin_headers)
    assert res.status_code == 200
    staff_list = res.json()
    assert isinstance(staff_list, list)

    # 2. Create a new staff account
    create_payload = {
        "name": "Jane Content Editor",
        "email": "jane.editor@adwashort.com",
        "phone": "+251911998877",
        "password": "strongPassword123",
        "role_label": "staff",
        "permissions": "content",
    }
    create_res = await client.post("/admin/staff", json=create_payload, headers=admin_headers)
    assert create_res.status_code == 201
    created = create_res.json()
    assert created["name"] == "Jane Content Editor"
    assert created["email"] == "jane.editor@adwashort.com"
    assert created["role_label"] == "staff"
    assert created["is_active"] is True
    staff_id = created["id"]

    # 3. Staff member login using email
    login_res = await client.post(
        "/auth/login",
        json={"email": "jane.editor@adwashort.com", "password": "strongPassword123"},
        headers={"X-Device-Id": "device-jane-1", "X-Platform": "android"},
    )
    assert login_res.status_code == 200
    login_data = login_res.json()
    assert login_data["admin_role"] == "staff"
    jane_token = login_data["access_token"]
    jane_headers = {"Authorization": f"Bearer {jane_token}", "X-Device-Id": "device-jane-1"}

    # 4. Get staff details
    get_res = await client.get(f"/admin/staff/{staff_id}", headers=admin_headers)
    assert get_res.status_code == 200
    assert get_res.json()["email"] == "jane.editor@adwashort.com"

    # 5. Update staff account
    update_res = await client.put(
        f"/admin/staff/{staff_id}",
        json={"name": "Jane Senior Editor"},
        headers=admin_headers,
    )
    assert update_res.status_code == 200
    assert update_res.json()["name"] == "Jane Senior Editor"

    # 6. Toggle staff active status
    toggle_res = await client.post(f"/admin/staff/{staff_id}/toggle-active", headers=admin_headers)
    assert toggle_res.status_code == 200
    assert toggle_res.json()["is_active"] is False

    # Deactivated staff cannot login
    bad_login = await client.post(
        "/auth/login",
        json={"email": "jane.editor@adwashort.com", "password": "strongPassword123"},
        headers={"X-Device-Id": "device-jane-1", "X-Platform": "android"},
    )
    assert bad_login.status_code == 403

    # Re-activate staff
    reactivate = await client.post(f"/admin/staff/{staff_id}/toggle-active", headers=admin_headers)
    assert reactivate.status_code == 200
    assert reactivate.json()["is_active"] is True

    # 7. Delete staff account
    del_res = await client.delete(f"/admin/staff/{staff_id}", headers=admin_headers)
    assert del_res.status_code == 200

    # Verify deleted
    get_again = await client.get(f"/admin/staff/{staff_id}", headers=admin_headers)
    assert get_again.status_code == 404


async def test_staff_permissions_boundary(client, staff_headers, admin_headers):
    # Staff CAN perform content operations:
    # A) Create category
    cat_res = await client.post(
        "/categories",
        json={"name": "Staff Drama Category", "sort_order": 1},
        headers=staff_headers,
    )
    assert cat_res.status_code == 201
    cat_id = cat_res.json()["id"]

    # B) Create series
    series_res = await client.post(
        "/series",
        json={
            "title": "Staff Created Series",
            "category_id": cat_id,
            "type": "series",
            "is_published": False,
            "free_episode_count": 2,
            "total_episodes": 5,
        },
        headers=staff_headers,
    )
    assert series_res.status_code == 201
    series_id = series_res.json()["id"]

    # C) Create episode
    ep_res = await client.post(
        "/episodes",
        json={
            "series_id": series_id,
            "episode_number": 1,
            "title": "Episode 1 Pilot",
            "duration_seconds": 120,
            "is_free": True,
            "is_published": False,
        },
        headers=staff_headers,
    )
    assert ep_res.status_code == 201

    # Staff CANNOT access sensitive financial/management sections (403 Forbidden):
    # 1. Revenue Overview
    res_rev = await client.get("/admin/revenue/overview", headers=staff_headers)
    assert res_rev.status_code == 403

    # 2. Revenue by Content
    res_rev_content = await client.get("/admin/revenue/by-content", headers=staff_headers)
    assert res_rev_content.status_code == 403

    # 3. Revenue by Creator
    res_rev_creator = await client.get("/admin/revenue/by-creator", headers=staff_headers)
    assert res_rev_creator.status_code == 403

    # 4. Revenue Transactions
    res_tx = await client.get("/admin/revenue/transactions", headers=staff_headers)
    assert res_tx.status_code == 403

    # 5. Staff Management list
    res_staff_list = await client.get("/admin/staff", headers=staff_headers)
    assert res_staff_list.status_code == 403

    # 6. Manual cash deposit
    res_deposit = await client.post(
        "/admin/wallet/manual-deposit",
        json={"user_id": 1, "amount_birr": 100},
        headers=staff_headers,
    )
    assert res_deposit.status_code == 403

    # 7. Staff CANNOT access Creators List or Create Creator (Super Admin Only)
    res_creators_list = await client.get("/creators", headers=staff_headers)
    assert res_creators_list.status_code == 403

    res_split_create = await client.post(
        "/creators",
        json={"name": "Greedy Creator", "default_revenue_split_pct": 70},
        headers=staff_headers,
    )
    assert res_split_create.status_code == 403

    # Super admin creates creator
    res_sa_create = await client.post(
        "/creators",
        json={"name": "Standard Creator", "default_revenue_split_pct": 50},
        headers=admin_headers,
    )
    assert res_sa_create.status_code == 201
    created_c_id = res_sa_create.json()["id"]

    # Staff CANNOT modify creator
    res_split_upd = await client.put(
        f"/creators/{created_c_id}",
        json={"default_revenue_split_pct": 80},
        headers=staff_headers,
    )
    assert res_split_upd.status_code == 403

    # 8. Staff CANNOT access User List (Super Admin Only)
    res_users = await client.get("/admin/users", headers=staff_headers)
    assert res_users.status_code == 403

    # 9. Staff CANNOT access Admin Reviews (Super Admin Only)
    res_reviews = await client.get("/reviews/admin", headers=staff_headers)
    assert res_reviews.status_code == 403

    # 10. Staff CANNOT access Content Performance (Super Admin Only)
    res_content_perf = await client.get("/admin/analytics/content", headers=staff_headers)
    assert res_content_perf.status_code == 403

    # But super admin CAN access all of these
    sa_users = await client.get("/admin/users", headers=admin_headers)
    assert sa_users.status_code == 200

    sa_creators = await client.get("/creators", headers=admin_headers)
    assert sa_creators.status_code == 200

    sa_reviews = await client.get("/reviews/admin", headers=admin_headers)
    assert sa_reviews.status_code == 200

    sa_content_perf = await client.get("/admin/analytics/content", headers=admin_headers)
    assert sa_content_perf.status_code == 200

    # 11. Staff Activity Log verifies actions performed by staff
    activity_res = await client.get("/admin/staff/activity", headers=admin_headers)
    assert activity_res.status_code == 200
    activity_data = activity_res.json()
    assert "items" in activity_data
    assert activity_data["total"] > 0
    # Verify that staff category/series/episode creation was recorded
    logged_actions = [it["action"] for it in activity_data["items"]]
    assert "create" in logged_actions

    # Staff cannot access activity log
    staff_act = await client.get("/admin/staff/activity", headers=staff_headers)
    assert staff_act.status_code == 403


async def test_user_list_excludes_super_admin_and_staff(client, admin_headers):
    # 1. Create a regular user
    u_res = await client.post(
        "/auth/register",
        json={"phone": "+251977112233", "password": "password123", "display_name": "Regular Viewer"},
        headers={"X-Device-Id": "reg-dev-1", "X-Platform": "android"},
    )
    assert u_res.status_code == 201

    # 2. Super admin lists users
    res = await client.get("/admin/users", headers=admin_headers)
    assert res.status_code == 200
    user_list = res.json()

    # The regular user must be present
    regular_matches = [u for u in user_list if u["phone"] == "+251977112233"]
    assert len(regular_matches) == 1

    # Neither super_admin nor staff accounts must be present in the user list
    admin_matches = [u for u in user_list if u.get("role") in ("admin", "super_admin", "staff")]
    assert len(admin_matches) == 0
