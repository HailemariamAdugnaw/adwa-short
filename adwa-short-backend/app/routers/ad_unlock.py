from __future__ import annotations

import json
from datetime import datetime
from typing import Any, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.deps import get_current_admin, get_current_user, get_optional_user
from app.models.ad_unlock import AdImpressionLog, AdUnlockLog, AdUnlockRule
from app.models.content import Episode, Series
from app.models.user import User
from app.schemas.admin import (
    AdImpressionCreate,
    AdImpressionOut,
    AdUnlockLogCreate,
    AdUnlockLogOut,
    AdUnlockRuleOut,
    AdUnlockRuleUpdate,
    AdWebhookPostbackResponse,
)
from app.services.monetization import _get_ad_rule, can_use_ad_unlock, record_ad_unlock
from app.services.revenue import RevenueService

# Main admin & client unlocks router
router = APIRouter(prefix="/ad-unlocks", tags=["ad-unlocks"])

# Dedicated S2S (Server-to-Server) Webhook router
api_v1_ads_router = APIRouter(prefix="/api/v1/ads", tags=["ads-s2s"])


def _extract_id(val: Any) -> Optional[int]:
    if val is None:
        return None
    try:
        return int(val)
    except (ValueError, TypeError):
        return None


def _extract_numeric_payout(data: dict[str, Any]) -> Optional[float]:
    """
    Extracts dynamic impression payout from ad network postback data.
    Checks explicit currency payout fields first, then CPM rates.
    """
    priority_keys = [
        "payout_birr",
        "revenue_birr",
        "exact_payout",
        "payout",
        "revenue",
        "payout_amount",
        "amount_birr",
        "reward_value_birr",
        "reward_value",
        "value_birr",
        "value",
    ]
    for k in priority_keys:
        if k in data and data[k] is not None:
            try:
                v = float(data[k])
                if v > 0:
                    return round(v, 4)
            except (ValueError, TypeError):
                continue

    # Fallback check for CPM / eCPM fields: convert to per-impression Birr rate
    cpm_keys = ["cpm_birr", "ecpm_birr", "cpm", "ecpm"]
    for k in cpm_keys:
        if k in data and data[k] is not None:
            try:
                cpm_v = float(data[k])
                if cpm_v > 0:
                    return round(cpm_v / 1000.0, 4)
            except (ValueError, TypeError):
                continue

    return None


@router.get("/rule", response_model=AdUnlockRuleOut)
async def get_rule(db: AsyncSession = Depends(get_db)):
    res = await db.execute(select(AdUnlockRule).limit(1))
    rule = res.scalar_one_or_none()
    if rule is None:
        rule = AdUnlockRule(
            ads_required=settings.AD_ADS_REQUIRED,
            episodes_unlocked=settings.AD_EPISODES_UNLOCKED,
            is_active=settings.AD_ENABLED,
            provider=settings.AD_NETWORK_PROVIDER,
            app_id=settings.AD_NETWORK_APP_ID,
            banner_unit_id=settings.AD_BANNER_UNIT_ID,
            interstitial_unit_id=settings.AD_INTERSTITIAL_UNIT_ID,
            rewarded_unit_id=settings.AD_REWARDED_UNIT_ID,
            api_key=settings.AD_NETWORK_API_KEY,
            callback_secret=settings.AD_REWARD_CALLBACK_SECRET,
            reward_ad_value_birr=settings.AD_REWARD_VALUE_BIRR,
            estimated_cpm_birr=settings.AD_ESTIMATED_CPM_BIRR,
            test_mode=settings.AD_TEST_MODE,
        )
        db.add(rule)
        await db.commit()
        await db.refresh(rule)
    return rule


@router.put("/rule", response_model=AdUnlockRuleOut)
async def update_rule(
    payload: AdUnlockRuleUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(AdUnlockRule).limit(1))
    rule = res.scalar_one_or_none()
    if rule is None:
        rule = AdUnlockRule(
            ads_required=settings.AD_ADS_REQUIRED,
            episodes_unlocked=settings.AD_EPISODES_UNLOCKED,
            is_active=settings.AD_ENABLED,
            provider=settings.AD_NETWORK_PROVIDER,
            app_id=settings.AD_NETWORK_APP_ID,
            banner_unit_id=settings.AD_BANNER_UNIT_ID,
            interstitial_unit_id=settings.AD_INTERSTITIAL_UNIT_ID,
            rewarded_unit_id=settings.AD_REWARDED_UNIT_ID,
            api_key=settings.AD_NETWORK_API_KEY,
            callback_secret=settings.AD_REWARD_CALLBACK_SECRET,
            reward_ad_value_birr=settings.AD_REWARD_VALUE_BIRR,
            estimated_cpm_birr=settings.AD_ESTIMATED_CPM_BIRR,
            test_mode=settings.AD_TEST_MODE,
        )
        db.add(rule)

    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(rule, k, v)

    # Google AdMob is the sole, exclusive ad network provider
    rule.provider = "admob"

    await db.commit()
    await db.refresh(rule)
    return rule


@router.post("/watched", response_model=AdUnlockLogOut, status_code=status.HTTP_201_CREATED)
async def watched_ad(
    payload: AdUnlockLogCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ep_res = await db.execute(select(Episode).where(Episode.id == payload.episode_id))
    ep = ep_res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")

    # Strict rule checking
    rule = await _get_ad_rule(db)
    if rule is None or not rule.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ad unlocks are currently disabled",
        )

    # Check already unlocked
    existing_res = await db.execute(
        select(AdUnlockLog).where(
            AdUnlockLog.user_id == user.id,
            AdUnlockLog.episode_id == payload.episode_id,
        )
    )
    if existing_res.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Episode is already unlocked",
        )

    # Strict completion verification: must watch at least rule.ads_required ads, and > 0
    required_count = max(1, int(rule.ads_required))
    if payload.ads_watched is None or payload.ads_watched < required_count:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Incomplete ad batch: Need to watch {required_count} ads (got {payload.ads_watched or 0})",
        )

    if payload.ads_watched <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid ad count: ads_watched must be greater than zero",
        )

    ad_network = (payload.ad_network or rule.provider or "admob").strip().lower()
    if not ad_network:
        ad_network = "admob"

    # Dynamic payout if supplied by client SDK, otherwise static fallback
    val = float(rule.reward_ad_value_birr if rule and rule.reward_ad_value_birr is not None else settings.AD_REWARD_VALUE_BIRR)
    if payload.revenue_birr is not None and payload.revenue_birr > 0:
        val = float(payload.revenue_birr)
    elif payload.payout is not None and payload.payout > 0:
        val = float(payload.payout)

    # 1. Record unlock log
    log = await record_ad_unlock(
        db,
        user_id=user.id,
        episode_id=payload.episode_id,
        ads_watched=payload.ads_watched,
        ad_network=ad_network,
        verified_via="client",
        revenue_birr=val,
    )

    # 2. Strict Ad Revenue Monetization Rule:
    # 100% of ad revenue belongs to ADWA SHORT (platform), creators earn 0%
    revenue_svc = RevenueService(db)
    await revenue_svc.calculate_ad_revenue(
        episode_id=payload.episode_id,
        user_id=user.id,
        gross_amount_birr=val,
        reference=f"ad_unlock:ep:{ep.id}:user:{user.id}:ads:{payload.ads_watched}",
    )

    await db.commit()
    await db.refresh(log)
    return log


async def handle_ad_s2s_callback(
    request: Request,
    user_id: Optional[int] = Query(None),
    episode_id: Optional[int] = Query(None),
    custom_data: Optional[str] = Query(None),
    secret: Optional[str] = Query(None),
    token: Optional[str] = Query(None),
    payout: Optional[float] = Query(None),
    revenue: Optional[float] = Query(None),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    """
    Google AdMob Server-Side Verification (SSV) callback webhook handler.
    Exclusively handles Google AdMob rewarded video verification and postback events.

    Revenue Attribution Logic:
    1. Dynamic Logging: If an exact payout/revenue is passed in postback body or query params,
       record that exact amount as platform ad revenue.
    2. Static Fallback: If no live impression payout is provided, falls back to the configured
       AD_REWARD_VALUE_BIRR (default 0.25 ETB).
    3. 100% Platform / 0% Creator Rule: All ad viewing revenue is strictly credited to ADWA SHORT.
    """
    body_data: dict[str, Any] = {}
    if request.method == "POST":
        try:
            parsed = await request.json()
            if isinstance(parsed, dict):
                body_data = parsed
        except Exception:
            try:
                form = await request.form()
                body_data = dict(form)
            except Exception:
                pass

    query_params = dict(request.query_params)
    combined = {**query_params, **body_data}

    # 1. Security Verification:
    # Check headers (Authorization Bearer or X-Ad-Secret) and query/body parameters
    auth_header = request.headers.get("Authorization", "")
    bearer_secret = None
    if auth_header:
        if auth_header.lower().startswith("bearer "):
            bearer_secret = auth_header[7:].strip()
        else:
            bearer_secret = auth_header.strip()

    header_secret = (
        request.headers.get("X-Ad-Secret")
        or request.headers.get("X-Webhook-Secret")
        or request.headers.get("X-Callback-Secret")
        or bearer_secret
    )

    incoming_secret = (
        secret
        or token
        or header_secret
        or combined.get("secret")
        or combined.get("token")
        or combined.get("key")
        or combined.get("verifier")
        or combined.get("sig")
        or combined.get("signature")
    )

    rule_res = await db.execute(select(AdUnlockRule).limit(1))
    rule = rule_res.scalar_one_or_none()
    expected_secret = (
        rule.callback_secret
        if (rule and rule.callback_secret)
        else settings.AD_REWARD_CALLBACK_SECRET
    )

    if expected_secret:
        if not incoming_secret or incoming_secret != expected_secret:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invalid callback secret verification",
            )

    # 2. Extract User ID and Episode ID
    user_id_raw = (
        user_id
        or combined.get("user_id")
        or combined.get("userId")
        or combined.get("uid")
        or combined.get("user")
        or combined.get("account_id")
    )
    episode_id_raw = (
        episode_id
        or combined.get("episode_id")
        or combined.get("episodeId")
        or combined.get("ep_id")
        or combined.get("episode")
        or combined.get("content_id")
    )

    custom_data_raw = (
        custom_data
        or combined.get("custom_data")
        or combined.get("customData")
        or combined.get("extra_data")
    )

    if custom_data_raw and isinstance(custom_data_raw, str):
        # Try JSON parse
        try:
            cd_parsed = json.loads(custom_data_raw)
            if isinstance(cd_parsed, dict):
                user_id_raw = user_id_raw or cd_parsed.get("user_id") or cd_parsed.get("userId")
                episode_id_raw = episode_id_raw or cd_parsed.get("episode_id") or cd_parsed.get("episodeId")
        except Exception:
            pass

        # Try delimiter "user_id:episode_id"
        if (not user_id_raw or not episode_id_raw) and ":" in custom_data_raw:
            parts = custom_data_raw.split(":")
            if len(parts) >= 2:
                user_id_raw = user_id_raw or parts[0]
                episode_id_raw = episode_id_raw or parts[1]
        elif custom_data_raw.strip().isdigit():
            if episode_id_raw is None:
                episode_id_raw = custom_data_raw.strip()
            elif user_id_raw is None:
                user_id_raw = custom_data_raw.strip()

    final_user_id = _extract_id(user_id_raw)
    final_episode_id = _extract_id(episode_id_raw)

    if not final_user_id or not final_episode_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing user_id or episode_id in callback parameters",
        )

    # 3. Validate user and episode existence
    u_res = await db.execute(select(User).where(User.id == final_user_id))
    user = u_res.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    ep_res = await db.execute(select(Episode).where(Episode.id == final_episode_id))
    ep = ep_res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")

    # 4. Check idempotency (already unlocked)
    existing_res = await db.execute(
        select(AdUnlockLog).where(
            AdUnlockLog.user_id == final_user_id,
            AdUnlockLog.episode_id == final_episode_id,
        )
    )
    existing = existing_res.scalar_one_or_none()
    if existing is not None:
        return {
            "status": "ok",
            "message": "Episode already unlocked",
            "episode_id": final_episode_id,
            "user_id": final_user_id,
        }

    # 5. Dynamic Revenue Logging vs. Static Fallbacks:
    # If webhook postback provides an exact payout value, record that exact amount;
    # otherwise fall back to AD_REWARD_VALUE_BIRR.
    dynamic_payout = _extract_numeric_payout(combined)
    if payout is not None and payout > 0:
        dynamic_payout = round(payout, 4)
    elif revenue is not None and revenue > 0:
        dynamic_payout = round(revenue, 4)

    if dynamic_payout is not None and dynamic_payout > 0:
        revenue_to_record = dynamic_payout
        revenue_source = "dynamic_payout"
    else:
        static_fallback = (
            float(rule.reward_ad_value_birr)
            if (rule and rule.reward_ad_value_birr is not None)
            else float(settings.AD_REWARD_VALUE_BIRR)
        )
        revenue_to_record = round(static_fallback, 4)
        revenue_source = "static_fallback"

    # Google AdMob is the exclusive ad network
    ad_network = "admob"
    tx_id = (
        combined.get("transaction_id")
        or combined.get("tx_id")
        or combined.get("impression_id")
        or combined.get("id")
    )
    ads_req = rule.ads_required if rule else 1

    # 6. Record Unlock Log with audit details
    log = await record_ad_unlock(
        db,
        user_id=final_user_id,
        episode_id=final_episode_id,
        ads_watched=ads_req,
        ad_network=ad_network,
        verified_via="s2s_webhook",
        revenue_birr=revenue_to_record,
    )

    # 7. Strict Ad Revenue Monetization Rule:
    # 100% of ad revenue belongs to ADWA SHORT (platform), creators earn 0%
    ref_str = f"ad_s2s:{ad_network}:ep:{final_episode_id}:user:{final_user_id}"
    if tx_id:
        ref_str += f":tx:{tx_id}"

    revenue_svc = RevenueService(db)
    await revenue_svc.calculate_ad_revenue(
        episode_id=final_episode_id,
        user_id=final_user_id,
        gross_amount_birr=revenue_to_record,
        reference=ref_str,
    )

    await db.commit()

    return {
        "status": "success",
        "message": "Ad reward verified and episode unlocked successfully",
        "episode_id": final_episode_id,
        "user_id": final_user_id,
        "ad_network": ad_network,
        "revenue_birr": revenue_to_record,
        "revenue_credited_to_platform_birr": revenue_to_record,
        "platform_share_birr": revenue_to_record,
        "creator_share_birr": 0.0,
        "revenue_source": revenue_source,
        "transaction_id": tx_id,
    }


# ==============================================================================
# S2S Webhook Route Registrations
# ==============================================================================
# 1. Standard API v1 Endpoints (/api/v1/ads/callback, /api/v1/ads/postback)
api_v1_ads_router.api_route("/callback", methods=["GET", "POST"])(handle_ad_s2s_callback)
api_v1_ads_router.api_route("/postback", methods=["GET", "POST"])(handle_ad_s2s_callback)
api_v1_ads_router.api_route("/reward-callback", methods=["GET", "POST"])(handle_ad_s2s_callback)

# 2. Existing and backward-compatible endpoints (/ad-unlocks/reward-callback, etc.)
router.api_route("/reward-callback", methods=["GET", "POST"])(handle_ad_s2s_callback)
router.api_route("/callback", methods=["GET", "POST"])(handle_ad_s2s_callback)
router.api_route("/postback", methods=["GET", "POST"])(handle_ad_s2s_callback)


@router.post("/impression", response_model=AdImpressionOut, status_code=status.HTTP_201_CREATED)
async def log_ad_impression(
    payload: AdImpressionCreate,
    db: AsyncSession = Depends(get_db),
    user: Optional[User] = Depends(get_optional_user),
):
    rule_res = await db.execute(select(AdUnlockRule).limit(1))
    rule = rule_res.scalar_one_or_none()

    rev_val = payload.revenue_birr
    if rev_val is None or rev_val <= 0:
        cpm = (
            float(rule.estimated_cpm_birr)
            if (rule and rule.estimated_cpm_birr is not None)
            else float(settings.AD_ESTIMATED_CPM_BIRR)
        )
        rev_val = round(cpm / 1000.0, 4)

    imp = AdImpressionLog(
        user_id=user.id if user else None,
        episode_id=payload.episode_id,
        ad_unit_id=payload.ad_unit_id or (rule.rewarded_unit_id if rule else None),
        ad_network=payload.ad_network or (rule.provider if rule else "admob"),
        ad_type=payload.ad_type,
        revenue_birr=rev_val,
    )
    db.add(imp)

    # Attribute impression revenue 100% to ADWA SHORT platform
    if payload.episode_id:
        revenue_svc = RevenueService(db)
        await revenue_svc.calculate_ad_revenue(
            episode_id=payload.episode_id,
            user_id=user.id if user else 0,
            gross_amount_birr=rev_val,
            reference=f"ad_imp:{imp.ad_type}:ep:{payload.episode_id}",
        )

    await db.commit()
    await db.refresh(imp)
    return imp


@router.get("/logs", response_model=List[AdUnlockLogOut])
async def list_unlock_logs(
    limit: int = Query(default=50, le=200),
    page: int = Query(default=1, ge=1),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    stmt = (
        select(AdUnlockLog, User.display_name, Episode.title, Series.title)
        .join(User, User.id == AdUnlockLog.user_id)
        .join(Episode, Episode.id == AdUnlockLog.episode_id)
        .join(Series, Series.id == Episode.series_id)
        .order_by(desc(AdUnlockLog.unlocked_at))
        .limit(limit)
        .offset((page - 1) * limit)
    )
    res = await db.execute(stmt)
    out = []
    for log, u_name, ep_title, ser_title in res.all():
        out.append(
            AdUnlockLogOut(
                id=log.id,
                user_id=log.user_id,
                episode_id=log.episode_id,
                ads_watched=log.ads_watched,
                revenue_birr=float(log.revenue_birr or 0),
                ad_network=log.ad_network,
                verified_via=log.verified_via,
                unlocked_at=log.unlocked_at,
                user_display_name=u_name,
                episode_title=ep_title,
                series_title=ser_title,
            )
        )
    return out
