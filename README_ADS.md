# ADWA SHORT — Google AdMob Integration & SSV Webhook Guide

This guide details the ad configuration, Google AdMob SDK integration, Server-Side Verification (SSV) callback webhooks, and strict live payout monitoring for the **ADWA SHORT** platform.

> [!IMPORTANT]
> **Exclusive Ad Network**: Google AdMob is the sole, exclusive ad provider across the entire ADWA SHORT platform (FastAPI backend, React Admin Dashboard, and Flutter mobile client). All third-party networks (Unity Ads, AppLovin MAX, Custom S2S networks) have been permanently removed.

---

## 1. Monetization & Platform Revenue Rule

Ad monetization in ADWA SHORT operates under a strict platform-retention rule:

- **100% Platform Revenue**: All revenue generated from rewarded video views, ad impressions, and episode unlocks belongs entirely to **ADWA SHORT**.
- **0% Creator Revenue**: Content creators earn **0% (0.00 ETB)** from ad-supported episode unlocks. (Creators are monetized exclusively through coin pay-per-view unlocks and prorated subscription / time pass watch-time pools).
- **Ledger Recording**:
  - Every completed ad unlock with verified live payout creates a verified `RevenueTransaction` entry:
    - `source_type = "ad_revenue"`
    - `creator_id = None`
    - `creator_share_birr = 0.0`
    - `platform_share_birr = gross_ad_revenue_birr`
  - In creator analytics and statements, ad views are tallied in the **View by Ad** metric for transparency, but their revenue share strictly remains `0.00 Birr`.

---

## 2. Strict Google AdMob Live Revenue Monitoring

Revenue attribution is governed strictly by live, verified financial data delivered directly from Google AdMob:

1. **Strict Live Impression Monitoring**:
   - Payout and revenue tracking for ad-supported views is monitored and recorded **strictly** through verified live data provided by Google AdMob (via server-to-server callbacks/postbacks or SDK impression verification).
   - When Google AdMob SSV postbacks or verified client callbacks deliver an exact impression payout amount (via `payout_birr`, `revenue_birr`, `payout`, `revenue`, `exact_payout`, or `payout_amount`), the backend records that exact Birr value into `AdUnlockLog.revenue_birr` and credits 100% of it to the platform in `RevenueTransaction`.
   - The response metadata tag indicates `"revenue_source": "live_admob_payout"`.

2. **Zero Fallback Policy (No Arbitrary Monetary Crediting)**:
   - If a live payout value or verified ad impression callback is absent, **no arbitrary static monetary value is credited or logged as revenue**.
   - The episode unlock completes successfully for the user, but `AdUnlockLog.revenue_birr` is set strictly to `0.00 ETB`, and no artificial `RevenueTransaction` ledger entry is created.
   - All static fallback configuration variables (`AD_REWARD_VALUE_BIRR`, `AD_ESTIMATED_CPM_BIRR`) and `"revenue_source": "static_fallback"` calculation models have been completely removed.

---

## 3. Step-by-Step Google AdMob Setup Guide

### Step 1: Create or Sign In to Google AdMob
1. Navigate to the [Google AdMob Console](https://admob.google.com/).
2. Sign in with your Google account.

### Step 2: Register Applications
1. In the AdMob navigation menu, click **Apps** > **Add App**.
2. Select your platform:
   - **Android** (configure Google Play details or select "No" during initial development).
   - **iOS** (configure App Store details or select "No" during initial development).
3. Copy your unique **AdMob App ID** (format: `ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX`).

### Step 3: Create Rewarded Video Ad Units
1. Under your registered app, select **Ad units** > **Add ad unit**.
2. Choose **Rewarded** ad format.
3. Name your ad unit (e.g., `ADWA_Rewarded_Unlock`).
4. Set reward details:
   - **Reward amount**: `1`
   - **Reward item**: `Episode Unlock`

### Step 4: Configure Server-Side Verification (SSV)
1. In the Rewarded Ad unit settings, expand **Advanced settings**.
2. Check the box for **Server-side verification (SSV)**.
3. Enter your **Callback URL**:
   ```
   https://api.yourdomain.com/api/v1/ads/callback
   ```
4. Enter your custom **Secret / Token** (this matches `AD_REWARD_CALLBACK_SECRET` in `.env`):
   ```
   adwa_ssv_secret_key_change_in_production
   ```
5. Save the ad unit and copy the generated **Ad Unit ID** (format: `ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX`).

### Step 5 (Optional): Banner & Interstitial Placements
If enabling optional banner or interstitial placements, create corresponding ad units in the console and record their Ad Unit IDs.

---

## 4. Google AdMob Official Test Mode IDs

During development and automated testing, enable **Test Mode** (`AD_TEST_MODE=true` in `.env` and in the React Admin panel) to use Google's official test ad units without violating AdMob policies:

| Placement | Platform | Official Google Test Unit ID |
| :--- | :--- | :--- |
| **App ID (Sample)** | Android / iOS | `ca-app-pub-3940256099942544~3347511713` |
| **Rewarded Video** | Android | `ca-app-pub-3940256099942544/5224354917` |
| **Rewarded Video** | iOS | `ca-app-pub-3940256099942544/1712485313` |
| **Interstitial** | Android | `ca-app-pub-3940256099942544/1033173712` |
| **Interstitial** | iOS | `ca-app-pub-3940256099942544/4411468910` |
| **Banner** | Android | `ca-app-pub-3940256099942544/6300978111` |
| **Banner** | iOS | `ca-app-pub-3940256099942544/2934735716` |

---

## 5. Environment Variables (.env)

### Backend Configuration (`adwa-short-backend/.env`)

```env
# ==============================================================================
# GOOGLE ADMOB & SSV WEBHOOK CONFIGURATION
# ==============================================================================
AD_ENABLED=true
AD_TEST_MODE=true
AD_NETWORK_PROVIDER=admob
AD_NETWORK_APP_ID=ca-app-pub-3940256099942544~3347511713
AD_REWARDED_UNIT_ID=ca-app-pub-3940256099942544/5224354917
AD_INTERSTITIAL_UNIT_ID=ca-app-pub-3940256099942544/1033173712
AD_BANNER_UNIT_ID=ca-app-pub-3940256099942544/6300978111
AD_NETWORK_API_KEY=adm_live_secret_key_placeholder
AD_REWARD_CALLBACK_SECRET=adwa_ssv_secret_key_change_in_production

# Ad Reward Thresholds
AD_ADS_REQUIRED=2                         # Number of ads required to unlock an episode
AD_EPISODES_UNLOCKED=1                    # Episodes unlocked per completed ad batch
```

---

## 6. Server-Side Verification (SSV) Webhook Specification

Google AdMob delivers SSV callbacks to confirm rewarded video completion server-side.

### Webhook Endpoints
- **Primary Route**: `POST` or `GET /api/v1/ads/callback`
- **Aliases**: `POST` or `GET /api/v1/ads/postback`, `POST` or `GET /ad-unlocks/reward-callback`

### Security Authentication
The callback verifier verifies the secret token via:
- HTTP Header: `X-Ad-Secret: <SECRET>`, `X-Webhook-Secret: <SECRET>`, or `Authorization: Bearer <SECRET>`
- Query or JSON body parameter: `secret`, `token`, `key`, `verifier`, or `signature`

### Payload Examples

#### 1. Live AdMob Impression Payout (`POST /api/v1/ads/callback`):
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

**Response (`200 OK`):**
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
  "revenue_source": "live_admob_payout",
  "transaction_id": "admob_tx_9876543210"
}
```

#### 2. Live Verification Without Payout Data (`POST /api/v1/ads/postback`):
When Google AdMob delivers a completion postback without dynamic payout metadata:
```json
{
  "user_id": 42,
  "episode_id": 105,
  "secret": "adwa_ssv_secret_key_change_in_production",
  "ad_network": "admob"
}
```

**Response (`200 OK`):**
```json
{
  "status": "success",
  "message": "Ad reward verified and episode unlocked successfully",
  "episode_id": 105,
  "user_id": 42,
  "ad_network": "admob",
  "revenue_birr": 0.0,
  "revenue_credited_to_platform_birr": 0.0,
  "platform_share_birr": 0.0,
  "creator_share_birr": 0.0,
  "transaction_id": null
}
```
> [!NOTE]
> In accordance with strict monitoring policies, when no live payout amount is provided, `revenue_birr` is strictly recorded as `0.00 ETB` and zero artificial financial ledger entries (`RevenueTransaction`) are created. The user's episode unlock remains completely valid.

---

## 7. React Admin Dashboard — Ad Management Panel

Super Admins can manage all Google AdMob settings dynamically from the React Admin Dashboard without restarting the FastAPI server:

1. Navigate to: **Super Admin Dashboard > Monetization > Ad Unlock Configuration** (`/monetization/ad-unlock`).
2. Configuration sections:
   - **Network & Keys**:
     - Exclusive Provider Badge: **Google AdMob (Exclusive Network)**.
     - Google AdMob Application ID (`ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX`).
     - Server-to-Server Callback Secret.
     - One-Click Action: **"Load AdMob Test Unit IDs"** to instantly fill official Google sample IDs.
     - Global Toggles: Enable/Disable Ads, Test Mode toggle.
   - **Ad Unit Placements**:
     - Rewarded Video Unit ID (`ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX`).
     - Interstitial & Banner Unit IDs.
   - **Thresholds & Live Economics**:
     - Ads Required to Unlock Episode (e.g., 2 ads).
     - Strict Live Monitoring Info Card: Clarifies that ad revenue tracking is powered strictly by verified live data from AdMob callbacks, with zero arbitrary static values credited.
     - Monetization Rule: **100% Platform Revenue (0% Creator Revenue)**.
   - **SSV Webhook & Audit Logs**:
     - Copyable SSV Webhook URL (`/api/v1/ads/callback`).
     - Live audit log table of verified unlocks with timestamps, user IDs, episode titles, and revenue amounts.

---

## 8. Flutter Mobile Client Implementation

The Flutter mobile client integrates the official `google_mobile_ads` SDK:

- **Silent Multi-Ad Batch Queue**: When unlocking an episode requiring $N$ ads, all $N$ ads are preloaded in the background. The moment an ad finishes playing, the next ad in the queue launches programmatically without manual close (X) or next interruptions.
- **Strict Ad-Load Verification**: If an ad fails to load from AdMob or network is unavailable, the app **never** grants free unlocks. It displays a clean, brand-compliant error card (`"Ad unavailable. Please check your connection or try again later"`) styled in Black, Blood Red, and White, keeping the episode securely locked.
- **Deferred Verification**: Backend verification (`POST /ad-unlocks/watched`) and reward callbacks are triggered only when the entire batch is completed.

---

## 9. Testing & Verification

### A. Backend Pytest Suite
Run the ad monetization test suite:
```bash
cd adwa-short-backend
.\venv\Scripts\pytest tests/test_ad_configuration.py -v
```

### B. Mobile Client Flutter Tests
Run the continuous multi-ad batch and unlock tests:
```bash
cd adwa-short-mobile/adwa_short
flutter test test/continuous_ad_batch_test.dart test/ad_and_loyalty_test.dart
```

### C. Manual Verification via cURL

#### 1. Test Live Impression Payout SSV Callback:
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

#### 2. Test Live Verification Without Payout (Zero Birr Credited):
```bash
curl -X POST "http://localhost:8000/api/v1/ads/postback" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "episode_id": 2,
    "secret": "adwa_ssv_secret_key_change_in_production",
    "ad_network": "admob"
  }'
```
