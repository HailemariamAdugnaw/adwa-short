# ADWA SHORT — Ad Monetization & Ad Network Configuration Guide

This guide details the ad configuration, ad network integration (Google AdMob, Unity Ads, AppLovin MAX, or Custom Ad Networks), dynamic impression revenue attribution, static fallback economics, and Server-to-Server (S2S) postback/callback webhooks for the **ADWA SHORT** platform.

---

## 1. Monetization & Revenue Attribution Rule

In the ADWA SHORT platform, ad monetization operates under a strict platform-retention rule:

- **100% Platform Revenue**: All revenue generated from ad views, ad-unlocked episodes, and impressions belongs entirely to **ADWA SHORT**.
- **0% Creator Revenue**: Content creators earn **0% (0.00 Birr)** from ad-supported episode unlocks and impressions. (Creators are monetized exclusively through Coin pay-per-view unlocks and prorated Time Pass / Subscription watch-time attribution).
- **Ledger Recording**:
  - Whenever an ad-unlocked watch is completed or an S2S reward callback is verified, a `RevenueTransaction` entry is logged with:
    - `source_type = "ad_revenue"`
    - `creator_id = None`
    - `creator_share_birr = 0.0`
    - `platform_share_birr = gross_ad_revenue_birr`
  - In creator analytics and statements, ad views are tallied in the **View by Ad** metric for transparency, but their revenue share strictly remains `0.00 Birr`.

---

## 2. Dynamic Revenue Logging vs. Static Fallbacks

To ensure revenue attribution is both robust and accurate:

1. **Dynamic Revenue Logging (Live Impression Payouts)**:
   - When an ad network postback or client completion callback delivers an exact payout amount (e.g., via `payout_birr`, `revenue_birr`, `payout`, `revenue`, `exact_payout`, or `payout_amount`), the backend records that exact Birr value into `AdUnlockLog.revenue_birr` and credits 100% of it to platform revenue in `RevenueTransaction`.
   - The response tag indicates `"revenue_source": "dynamic_payout"`.

2. **Static Fallbacks (When Live Data Is Unavailable)**:
   - When no live payout value is provided in the postback, the system automatically falls back to the configured static default:
     - `AD_REWARD_VALUE_BIRR` (default: **0.25 ETB** per completed rewarded ad watch).
     - `AD_ESTIMATED_CPM_BIRR` (default: **250.0 ETB** reference CPM, equivalent to 0.25 ETB per impression).
   - The response tag indicates `"revenue_source": "static_fallback"`.

---

## 3. Environment Variables (.env)

### Backend Configuration (`adwa-short-backend/.env`)

Configure the following variables in your FastAPI `.env` file or host environment:

```env
# ==============================================================================
# AD NETWORK CONFIGURATION & REWARDED ADS
# ==============================================================================
AD_ENABLED=true
AD_TEST_MODE=true
AD_NETWORK_PROVIDER=admob                 # Options: admob, unity, applovin, custom
AD_NETWORK_APP_ID=ca-app-pub-3940256099942544~3347511713
AD_REWARDED_UNIT_ID=ca-app-pub-3940256099942544/5224354917
AD_INTERSTITIAL_UNIT_ID=ca-app-pub-3940256099942544/1033173712
AD_BANNER_UNIT_ID=ca-app-pub-3940256099942544/6300978111
AD_NETWORK_API_KEY=adm_live_secret_key_placeholder
AD_REWARD_CALLBACK_SECRET=adwa_ssv_secret_key_change_in_production

# Ad Reward Thresholds & Static Fallbacks
AD_ADS_REQUIRED=2                         # Number of ads required to unlock an episode
AD_EPISODES_UNLOCKED=1                    # Episodes unlocked per completed ad watch
AD_REWARD_VALUE_BIRR=0.25                 # Default fallback Birr value credited to platform per ad watch
AD_ESTIMATED_CPM_BIRR=250.0               # Default fallback reference CPM in ETB
```

### Frontend Configuration (`adwa-short-admin/.env`)

```env
VITE_API_URL=http://localhost:8000
VITE_AD_NETWORK_PROVIDER=admob
VITE_AD_TEST_MODE=true
```

---

## 4. Supported Ad Networks & Account Setup

### A. Google AdMob
1. Register or sign in at [Google AdMob Console](https://admob.google.com/).
2. Create an Application for **Android** and/or **iOS**.
3. Copy your **AdMob App ID** (format: `ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX`).
4. Create an Ad Unit:
   - Select **Rewarded** (`ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX`).
   - Enable **Server-Side Verification (SSV)** in the Ad Unit settings.
   - Enter your Callback URL: `https://api.yourdomain.com/api/v1/ads/callback`.
   - Enter your Secret / Token in the AdMob SSV setup: `adwa_ssv_secret_key_change_in_production`.
5. Optional: Create **Interstitial** and **Banner** ad units if enabling UI banner/interstitial placements.

> **Google AdMob Official Test Unit IDs (Test Mode):**
> - **App ID**: `ca-app-pub-3940256099942544~3347511713`
> - **Rewarded Video**: `ca-app-pub-3940256099942544/5224354917`
> - **Interstitial**: `ca-app-pub-3940256099942544/1033173712`
> - **Banner**: `ca-app-pub-3940256099942544/6300978111`

### B. Unity Ads
1. Go to the [Unity Cloud Monetization Dashboard](https://cloud.unity.com/).
2. Create a Project and enable **Monetization**.
3. Retrieve your **Unity Game ID** (Project App ID).
4. Create a **Rewarded Placement** (e.g., `Rewarded_Android`).
5. Configure the **Server-to-Server Callback** with `https://api.yourdomain.com/api/v1/ads/postback` and your shared secret.

### C. AppLovin MAX
1. Go to [AppLovin MAX Dashboard](https://dash.applovin.com/).
2. Create an App and generate a **MAX Ad Unit ID**.
3. Under S2S Rewarded Callbacks, set the callback URL to `https://api.yourdomain.com/api/v1/ads/callback` and secret key.

### D. Custom / Direct S2S Network
Send an HTTP POST or GET request to `/api/v1/ads/callback` or `/api/v1/ads/postback` with your secret token and optional impression payout.

---

## 5. Server-to-Server (S2S) Webhook Specification

Episodes can be unlocked and monetized automatically via Server-to-Server postback callbacks when a user completes watching an ad.

### Webhook Endpoints:
- Primary: `POST` or `GET /api/v1/ads/callback`
- Postback alias: `POST` or `GET /api/v1/ads/postback`
- Backward compatible: `POST` or `GET /ad-unlocks/reward-callback`

### Request Authentication:
Provide the secret via one of:
- HTTP Header: `X-Ad-Secret: <SECRET>`, `X-Webhook-Secret: <SECRET>`, or `Authorization: Bearer <SECRET>`
- Query or JSON field: `secret`, `token`, `key`, or `signature`

### Payload Formats:

#### 1. Dynamic Payout Example (`POST /api/v1/ads/callback`):
```json
{
  "user_id": 42,
  "episode_id": 105,
  "secret": "adwa_ssv_secret_key_change_in_production",
  "ad_network": "admob",
  "transaction_id": "admob_tx_9876543210",
  "payout_birr": 0.85
}
```

#### Response:
```json
{
  "status": "success",
  "message": "Ad reward verified and episode unlocked successfully",
  "episode_id": 105,
  "user_id": 42,
  "ad_network": "admob",
  "revenue_birr": 0.85,
  "revenue_credited_to_platform_birr": 0.85,
  "platform_share_birr": 0.85,
  "creator_share_birr": 0.0,
  "revenue_source": "dynamic_payout",
  "transaction_id": "admob_tx_9876543210"
}
```

#### 2. Static Fallback Example (`POST /api/v1/ads/postback`):
```json
{
  "user_id": 42,
  "episode_id": 105,
  "secret": "adwa_ssv_secret_key_change_in_production",
  "ad_network": "unity"
}
```

#### Response:
```json
{
  "status": "success",
  "message": "Ad reward verified and episode unlocked successfully",
  "episode_id": 105,
  "user_id": 42,
  "ad_network": "unity",
  "revenue_birr": 0.25,
  "revenue_credited_to_platform_birr": 0.25,
  "platform_share_birr": 0.25,
  "creator_share_birr": 0.0,
  "revenue_source": "static_fallback",
  "transaction_id": null
}
```

---

## 6. React Admin Dashboard — Ad Management Panel

Super Admins can manage all ad settings dynamically without restarting the FastAPI server:

1. Navigate to: **Super Admin Dashboard > Monetization > Ad Unlock Configuration** (`/monetization/ad-unlock`).
2. Four dedicated configuration tabs:
   - **Network & Keys**:
     - Toggle Ad System Active/Inactive.
     - Toggle Test Mode (Sandbox vs. Production).
     - Select Provider (AdMob, Unity, AppLovin, Custom).
     - Enter App ID, API Key, and SSV Callback Secret.
     - Click **"Load AdMob Test IDs"** to instantly autofill Google's official test credentials.
   - **Ad Unit IDs**:
     - Rewarded Video Unit ID, Interstitial Unit ID, and Banner Unit ID.
   - **Thresholds & Revenue**:
     - Ads required to unlock (e.g. 2 ads).
     - Episodes unlocked per watch (e.g. 1 episode).
     - Static Fallback Value per Rewarded Ad in Birr (0.25 ETB).
     - Static Fallback Network eCPM in Birr (250.00 ETB).
     - Policy banner: **"100% Platform Revenue (0% Creator Revenue)"**.
   - **SSV Webhook & Logs**:
     - Displays the primary webhook URL (`/api/v1/ads/callback`) with a copy button.
     - Real-time audit table displaying recent ad unlocks, timestamps, user IDs, episode titles, and verified platforms.

---

## 7. Testing & Verification

### A. Automated Backend Pytest Suite
Run the test suite:
```bash
cd adwa-short-backend
pytest tests/test_ad_configuration.py -v
```

### B. Manual Verification via cURL

#### 1. Dynamic Payout Postback:
```bash
curl -X POST "http://localhost:8000/api/v1/ads/callback" \
  -H "Content-Type: application/json" \
  -H "X-Ad-Secret: adwa_ssv_secret_key_change_in_production" \
  -d '{
    "user_id": 1,
    "episode_id": 1,
    "ad_network": "admob",
    "payout_birr": 0.85
  }'
```

#### 2. Static Fallback Postback (No Payout Specified):
```bash
curl -X POST "http://localhost:8000/api/v1/ads/postback" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "episode_id": 2,
    "secret": "adwa_ssv_secret_key_change_in_production",
    "ad_network": "unity"
  }'
```

#### 3. GET Query Parameter Postback:
```bash
curl -X GET "http://localhost:8000/api/v1/ads/callback?user_id=1&episode_id=3&secret=adwa_ssv_secret_key_change_in_production&payout_birr=0.45"
```
