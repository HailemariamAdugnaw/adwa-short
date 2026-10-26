from __future__ import annotations

import asyncio
import sys
from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.database import AsyncSessionLocal, create_all, engine
from app.models.ad_unlock import AdUnlockRule
from app.models.admin import AdminUser
from app.models.content import Category, Episode, Series
from app.models.engagement import SearchQuery
from app.models.loyalty import LoyaltyRewardConfig
from app.models.revenue import Creator, RevenueTransaction
from app.models.rating import Rating
from app.models.review import Review
from app.models.settings import AppSettings
from app.models.subscription import SubscriptionPlan, TimePass
from app.models.user import User
from app.models.wallet import CoinPackage, Wallet
from app.security import hash_password


BRAND_BLACK = "#0A0A0A"
BRAND_RED = "#C8102E"
BRAND_WHITE = "#FFFFFF"

DEFAULT_SETTINGS = [
    ("max_devices_per_account", "2", "Maximum simultaneous active devices per account"),
    ("free_trial_default_episodes", "3", "Default number of free episodes per series for new users"),
    ("coin_price_birr", "1.0", "Price in Birr per single coin (display only)"),
    ("maintenance_mode", "false", "If true, mobile clients show maintenance screen"),
    ("support_phone", "+251900000000", "Customer support phone number"),
    ("min_payout_birr", "50", "Minimum deposit amount"),
    ("default_creator_split_pct", "50", "Default revenue split percentage for new creators"),
    ("default_episode_coin_cost", "10", "Default coin cost to unlock an episode when not set per episode"),
]

CATEGORIES = [
    ("Documentary", "Long-form documentary series"),
    ("Ethiopia", "Stories about Ethiopia"),
    ("Biography", "Biographical dramas"),
    ("Celebrity", "Celebrity features and gossip"),
    ("Romance", "Romance dramas"),
    ("Family", "Family-friendly series"),
    ("Drama", "General drama"),
    ("Comedy Shorts", "Vertical comedy shorts"),
]

CREATORS_DEFS = [
    dict(
        name="Selam Tadesse",
        phone="+251920000001",
        email="selam@adwashort.com",
        display_name="Selam T.",
        default_revenue_split_pct=50.0,
        payment_method="telebirr",
        bank_name="CBE",
    ),
    dict(
        name="Daniel Kebede",
        phone="+251920000002",
        email="daniel@adwashort.com",
        display_name="Daniel K.",
        default_revenue_split_pct=60.0,
        payment_method="cbe",
        bank_name="CBE",
    ),
    dict(
        name="Hanna Girma",
        phone="+251920000003",
        email="hanna@adwashort.com",
        display_name="Hanna G.",
        default_revenue_split_pct=70.0,
        payment_method="awash",
        bank_name="Awash Bank",
    ),
]

SERIES_DEFS = [
    dict(
        title="Echoes of Addis",
        description="A documentary tracing the cultural heartbeat of Addis Ababa.",
        type="series",
        category_name="Documentary",
        creator_idx=0,
        is_vip=False,
        is_exclusive=False,
        is_published=True,
        free_episode_count=3,
        total_episodes=5,
        director="Selam T.",
        cast=["Actor A", "Actor B"],
        tags=["documentary", "ethiopia"],
        is_hot=True,
        is_new_release=True,
        episode_count=5,
    ),
    dict(
        title="Crimson Dawn",
        description="A historical biography of an Ethiopian hero.",
        type="series",
        category_name="Biography",
        creator_idx=1,
        is_vip=True,
        is_exclusive=False,
        is_published=True,
        free_episode_count=2,
        total_episodes=4,
        director="Daniel K.",
        cast=["Hero X", "Mentor Y"],
        tags=["biography", "ethiopia"],
        is_hot=False,
        is_new_release=True,
        episode_count=4,
    ),
    dict(
        title="Threads of Love",
        description="A romance drama set in modern Addis.",
        type="series",
        category_name="Romance",
        creator_idx=2,
        is_vip=False,
        is_exclusive=False,
        is_published=True,
        free_episode_count=3,
        total_episodes=6,
        director="Hanna G.",
        cast=["Lover A", "Lover B"],
        tags=["romance", "family"],
        is_hot=True,
        is_new_release=False,
        episode_count=6,
    ),
    dict(
        title="The Last Comedy Skit",
        description="Vertical short-form comedy.",
        type="short",
        category_name="Comedy Shorts",
        creator_idx=0,
        is_vip=False,
        is_exclusive=False,
        is_published=True,
        free_episode_count=3,
        total_episodes=3,
        director="Funny Studio",
        cast=["Comedian Z"],
        tags=["comedy", "shorts"],
        is_hot=False,
        is_new_release=False,
        episode_count=3,
    ),
    dict(
        title="Family Ties",
        description="Family drama exploring modern Ethiopian families.",
        type="series",
        category_name="Family",
        creator_idx=1,
        is_vip=False,
        is_exclusive=True,
        is_published=True,
        free_episode_count=1,
        total_episodes=4,
        director="Marta L.",
        cast=["Father", "Mother", "Child"],
        tags=["family", "drama"],
        is_hot=False,
        is_new_release=True,
        episode_count=4,
    ),
]

COIN_PACKAGES = [
    ("Starter", 50, 50.0, 5, 0),
    ("Standard", 300, 100.0, 15, 1),
    ("Full Series", 500, 150.0, -1, 2),
]

TIME_PASSES = [
    ("Hourly Pass", 1, 5.0, 0),
    ("Daily Pass", 24, 25.0, 1),
    ("Weekly Pass", 24 * 7, 100.0, 2),
    ("Monthly Pass", 24 * 30, 300.0, 3),
    ("Yearly Pass", 24 * 365, 2500.0, 4),
]

SUBSCRIPTION_PLANS = [
    ("Mobile Monthly", "monthly", 200.0),
    ("All Access Yearly", "yearly", 1800.0),
]


async def seed() -> None:
    await create_all()

    async with AsyncSessionLocal() as db:
        res = await db.execute(select(User).where(User.phone == "+251900000000"))
        admin = res.scalar_one_or_none()
        if admin is None:
            admin = User(
                phone="+251900000000",
                email="admin@adwashort.com",
                password_hash=hash_password("admin123"),
                display_name="ADWA Admin",
                role="admin",
                is_active=True,
            )
            db.add(admin)
            await db.flush()
            db.add(AdminUser(user_id=admin.id, role_label="super_admin", permissions="*"))
            db.add(Wallet(user_id=admin.id, balance_birr=0, balance_coins=0))

        res_staff = await db.execute(select(User).where(User.email == "staff@adwashort.com"))
        staff = res_staff.scalar_one_or_none()
        if staff is None:
            staff = User(
                phone="+251922222222",
                email="staff@adwashort.com",
                password_hash=hash_password("staff123"),
                display_name="Content Staff",
                role="admin",
                is_active=True,
            )
            db.add(staff)
            await db.flush()
            db.add(AdminUser(user_id=staff.id, role_label="staff", permissions="content"))
            db.add(Wallet(user_id=staff.id, balance_birr=0, balance_coins=0))

        res = await db.execute(select(User).where(User.phone == "+251911111111"))
        demo = res.scalar_one_or_none()
        if demo is None:
            demo = User(
                phone="+251911111111",
                email="demo@adwashort.com",
                password_hash=hash_password("user123"),
                display_name="Demo Viewer",
                role="user",
                is_active=True,
            )
            db.add(demo)
            await db.flush()
            db.add(Wallet(user_id=demo.id, balance_birr=500.0, balance_coins=100))

        for k, v, d in DEFAULT_SETTINGS:
            res = await db.execute(select(AppSettings).where(AppSettings.key == k))
            if res.scalar_one_or_none() is None:
                db.add(AppSettings(key=k, value=v, description=d))

        cat_map: dict[str, Category] = {}
        res = await db.execute(select(Category))
        for c in res.scalars().all():
            cat_map[c.name] = c
        for i, (name, desc) in enumerate(CATEGORIES):
            if name not in cat_map:
                cat = Category(name=name, description=desc, sort_order=i, is_active=True)
                db.add(cat)
                await db.flush()
                cat_map[name] = cat

        creators_list: list[Creator] = []
        for cd in CREATORS_DEFS:
            res = await db.execute(select(Creator).where(Creator.name == cd["name"]))
            creator = res.scalar_one_or_none()
            if creator is None:
                creator = Creator(**cd, is_active=True)
                db.add(creator)
                await db.flush()

            # Ensure user account for creator login
            u_res = await db.execute(
                select(User).where(
                    (User.email == cd.get("email")) | (User.phone == cd.get("phone"))
                )
            )
            c_user = u_res.scalar_one_or_none()
            if c_user is None:
                c_user = User(
                    phone=cd.get("phone") or f"+2519{creator.id:08d}",
                    email=cd.get("email"),
                    password_hash=hash_password("creator123"),
                    display_name=cd.get("display_name") or cd["name"],
                    role="creator",
                    is_active=True,
                )
                db.add(c_user)
                await db.flush()
                db.add(Wallet(user_id=c_user.id, balance_birr=0, balance_coins=0))

            if creator.user_id != c_user.id:
                creator.user_id = c_user.id
                await db.flush()

            creators_list.append(creator)

        seeded_series: list[tuple[Series, list[Episode]]] = []
        for sd in SERIES_DEFS:
            res = await db.execute(select(Series).where(Series.title == sd["title"]))
            series = res.scalar_one_or_none()
            creator = creators_list[sd["creator_idx"]] if sd.get("creator_idx") is not None else None
            if series is None:
                cat = cat_map.get(sd["category_name"])
                series = Series(
                    title=sd["title"],
                    description=sd["description"],
                    poster_url=f"https://placehold.co/400x600/{BRAND_BLACK[1:]}/{BRAND_RED[1:]}/?text={sd['title'].replace(' ', '+')}",
                    banner_url=f"https://placehold.co/1280x720/{BRAND_BLACK[1:]}/{BRAND_WHITE[1:]}/?text={sd['title'].replace(' ', '+')}",
                    category_id=cat.id if cat else None,
                    creator_id=creator.id if creator else None,
                    type=sd["type"],
                    is_vip=sd["is_vip"],
                    is_exclusive=sd["is_exclusive"],
                    is_published=sd["is_published"],
                    free_episode_count=sd["free_episode_count"],
                    total_episodes=sd["total_episodes"],
                    director=sd["director"],
                    cast=sd["cast"],
                    tags=sd["tags"],
                    is_hot=sd["is_hot"],
                    is_new_release=sd["is_new_release"],
                )
                db.add(series)
                await db.flush()
                eps: list[Episode] = []
                for n in range(1, sd["episode_count"] + 1):
                    ep = Episode(
                        series_id=series.id,
                        creator_id=creator.id if creator else None,
                        episode_number=n,
                        title=f"{sd['title']} - Episode {n}",
                        description=f"Episode {n} of {sd['title']}",
                        video_url=f"https://placehold.co/1280x720/{BRAND_BLACK[1:]}/{BRAND_RED[1:]}/?text=Ep{n}",
                        thumbnail_url=f"https://placehold.co/400x600/{BRAND_BLACK[1:]}/{BRAND_WHITE[1:]}/?text=Ep{n}",
                        duration_seconds=600 + n * 30,
                        is_short=(sd["type"] == "short"),
                        vertical_video_url=(f"https://placehold.co/720x1280/{BRAND_BLACK[1:]}/{BRAND_RED[1:]}/?text=Short{n}" if sd["type"] == "short" else None),
                        coin_cost=0 if n <= sd["free_episode_count"] else 50,
                        is_published=True,
                        published_at=datetime.now(timezone.utc),
                    )
                    db.add(ep)
                    eps.append(ep)
                await db.flush()
                seeded_series.append((series, eps))
            else:
                eres = await db.execute(select(Episode).where(Episode.series_id == series.id).order_by(Episode.episode_number))
                seeded_series.append((series, list(eres.scalars().all())))

        sample_tx_count_res = await db.execute(select(RevenueTransaction).limit(1))
        if sample_tx_count_res.scalar_one_or_none() is None and demo is not None:
            for series, eps in seeded_series[:3]:
                ep = eps[-1] if eps else None
                if ep is None or series.creator_id is None:
                    continue
                creator_id = ep.creator_id or series.creator_id
                cres = await db.execute(select(Creator).where(Creator.id == creator_id))
                creator_obj = cres.scalar_one_or_none()
                split_pct = float(creator_obj.default_revenue_split_pct) if creator_obj else 50.0
                gross = 50.0
                creator_share = gross * split_pct / 100.0
                platform_share = gross - creator_share
                db.add(
                    RevenueTransaction(
                        creator_id=creator_id,
                        series_id=series.id,
                        episode_id=ep.id,
                        user_id=demo.id,
                        source_type="coin_payment",
                        gross_amount_birr=gross,
                        creator_share_birr=creator_share,
                        platform_share_birr=platform_share,
                        reference=f"seed:coins:episode:{ep.id}",
                    )
                )

        sample_rating_res = await db.execute(select(Rating).limit(1))
        if sample_rating_res.scalar_one_or_none() is None and demo is not None:
            for series, eps in seeded_series:
                if not eps:
                    continue
                ep = eps[0]
                db.add(
                    Rating(
                        user_id=demo.id,
                        episode_id=ep.id,
                        series_id=series.id,
                        rating=5 if series.is_hot else 4,
                    )
                )

        sample_review_res = await db.execute(select(Review).limit(1))
        if sample_review_res.scalar_one_or_none() is None and demo is not None:
            for series, eps in seeded_series[:2]:
                if not eps:
                    continue
                ep = eps[0]
                db.add(
                    Review(
                        user_id=demo.id,
                        episode_id=ep.id,
                        series_id=series.id,
                        text=f"Loved {series.title}! Highly recommended.",
                        is_approved=True,
                    )
                )

        for name, coins, price, eps, order in COIN_PACKAGES:
            res = await db.execute(select(CoinPackage).where(CoinPackage.name == name))
            if res.scalar_one_or_none() is None:
                db.add(CoinPackage(name=name, coins=coins, price_birr=price, episodes_unlocked=eps, is_active=True, sort_order=order))

        for name, hours, price, order in TIME_PASSES:
            res = await db.execute(select(TimePass).where(TimePass.name == name))
            if res.scalar_one_or_none() is None:
                db.add(TimePass(name=name, duration_hours=hours, price_birr=price, is_active=True, sort_order=order))

        for name, cycle, price in SUBSCRIPTION_PLANS:
            res = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.name == name))
            if res.scalar_one_or_none() is None:
                db.add(SubscriptionPlan(name=name, billing_cycle=cycle, price_birr=price, is_active=True))

        res = await db.execute(select(AdUnlockRule).limit(1))
        if res.scalar_one_or_none() is None:
            db.add(
                AdUnlockRule(
                    ads_required=2,
                    episodes_unlocked=1,
                    is_active=True,
                    provider="admob",
                    app_id="ca-app-pub-3940256099942544~3347511713",
                    rewarded_unit_id="ca-app-pub-3940256099942544/5224354917",
                    interstitial_unit_id="ca-app-pub-3940256099942544/1033173712",
                    banner_unit_id="ca-app-pub-3940256099942544/6300978111",
                    callback_secret="adwa_ssv_secret_key_change_in_production",
                    test_mode=True,
                )
            )

        res = await db.execute(select(LoyaltyRewardConfig).limit(1))
        if res.scalar_one_or_none() is None:
            db.add(
                LoyaltyRewardConfig(
                    min_balance_birr=3500,
                    max_balance_birr=5000,
                    daily_access_days=7,
                    free_coins=1000,
                    free_full_series_count=2,
                    is_active=True,
                )
            )

        res = await db.execute(select(SearchQuery).limit(1))
        if res.scalar_one_or_none() is None:
            for q in ["Addis", "Romance", "Comedy"]:
                db.add(SearchQuery(query=q, entity_type="series"))

        await db.commit()

    print("✅ Seed complete.")
    print("   Admin: +251900000000 / admin123")
    print("   Demo:  +251911111111 / user123")


if __name__ == "__main__":
    asyncio.run(seed())
