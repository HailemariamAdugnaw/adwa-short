# ADWA SHORT — Google AdMob Configuration & Architecture

This reference document outlines the technical architecture, environment variables, database schemas, and Server-Side Verification (SSV) callback workflows for the **ADWA SHORT** Google AdMob integration.

---

## 1. System Overview

Google AdMob is the sole, exclusive ad network integrated across the ADWA SHORT platform:
- **Mobile Client**: Flutter application utilizing the official `google_mobile_ads` SDK.
- **Backend API**: FastAPI service providing AdMob rule endpoints (`GET` / `PUT /ad-unlocks/rule`), client batch verification (`POST /ad-unlocks/watched`), and AdMob Server-Side Verification webhooks (`/api/v1/ads/callback`).
- **Super Admin Dashboard**: React dashboard managing AdMob unit IDs, reward thresholds, and auditing unlock logs.

---

## 2. Revenue Retention & Accounting Rules

1. **100% Platform / 0% Creator Attribution**:
   - Ad revenue belongs entirely to ADWA SHORT (`platform_share_birr = gross_amount_birr`, `creator_share_birr = 0.0`).
   - Recorded in `RevenueTransaction` with `source_type = "ad_revenue"` and `creator_id = None`.
2. **Dynamic Payouts vs. Fallbacks**:
   - Dynamic payouts delivered via AdMob SSV postbacks are parsed directly into `AdUnlockLog.revenue_birr`.
   - Missing payout data automatically resolves to `AD_REWARD_VALUE_BIRR` (0.25 ETB default).

---

## 3. Environment Variables Reference

| Variable | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `AD_ENABLED` | bool | `true` | Master switch for ad monetization |
| `AD_TEST_MODE` | bool | `true` | When true, renders official Google sample ad units |
| `AD_NETWORK_PROVIDER` | string | `"admob"` | Exclusive ad provider identifier |
| `AD_NETWORK_APP_ID` | string | `ca-app-pub-3940256099942544~3347511713` | Google AdMob App ID |
| `AD_REWARDED_UNIT_ID` | string | `ca-app-pub-3940256099942544/5224354917` | Rewarded Video Ad Unit ID |
| `AD_INTERSTITIAL_UNIT_ID`| string | `ca-app-pub-3940256099942544/1033173712` | Interstitial Ad Unit ID |
| `AD_BANNER_UNIT_ID` | string | `ca-app-pub-3940256099942544/6300978111` | Banner Ad Unit ID |
| `AD_REWARD_CALLBACK_SECRET`| string | `adwa_ssv_secret_key_change_in_production` | Secret token for AdMob SSV authentication |
| `AD_REWARD_VALUE_BIRR` | float | `0.25` | Static fallback revenue in ETB per rewarded ad |
| `AD_ESTIMATED_CPM_BIRR` | float | `250.0` | Static fallback reference CPM in ETB |
| `AD_ADS_REQUIRED` | int | `2` | Number of rewarded ads required to unlock an episode |
| `AD_EPISODES_UNLOCKED` | int | `1` | Episodes unlocked per completed ad batch |

---

## 4. Webhook Endpoints & Verification

Google AdMob SSV webhooks deliver notifications when users watch rewarded video ads:

- **Primary Route**: `POST` / `GET /api/v1/ads/callback`
- **Aliases**: `/api/v1/ads/postback`, `/ad-unlocks/reward-callback`

### Security
Secret token verification via `Authorization: Bearer <SECRET>`, `X-Ad-Secret: <SECRET>`, or query parameter `secret=<SECRET>`.

### Payload Format (JSON or Form-URLEncoded)
```json
{
  "user_id": 1,
  "episode_id": 5,
  "secret": "adwa_ssv_secret_key_change_in_production",
  "ad_network": "admob",
  "transaction_id": "admob_tx_example_12345",
  "payout_birr": 0.85
}
```

---

## 5. Mobile & Frontend Reference

- Complete documentation with step-by-step setup guides is available in [README_ADS.md](file:///c:/Users/Haile/Documents/adwa-short/README_ADS.md).
