import { useEffect, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import {
  Megaphone,
  Save,
  ShieldCheck,
  Tv,
  Coins,
  CheckCircle2,
  Copy,
  ExternalLink,
  Layers,
  Sparkles,
  Info,
  Clock,
  Key,
  Flame,
  Check,
} from 'lucide-react'
import { useAdUnlockRule, useAdUnlockLogs } from '../../lib/hooks'
import { updateAdUnlockRule, errMsg, API_BASE } from '../../lib/api'
import { Card, CardHeader, CardTitle } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
import { Badge } from '../../components/ui/Badge'
import { formatBirr, formatNumber } from '../../lib/format'

export function AdUnlockRule() {
  const qc = useQueryClient()
  const { data, isLoading } = useAdUnlockRule()
  const { data: logs, isLoading: logsLoading } = useAdUnlockLogs({ limit: 20 })

  const [activeTab, setActiveTab] = useState('network') // 'network' | 'units' | 'rewards' | 'webhook'
  const [copied, setCopied] = useState(false)

  const [form, setForm] = useState({
    provider: 'admob',
    app_id: '',
    banner_unit_id: '',
    interstitial_unit_id: '',
    rewarded_unit_id: '',
    api_key: '',
    callback_secret: '',
    ads_required: 2,
    episodes_unlocked: 1,
    reward_ad_value_birr: 0.50,
    estimated_cpm_birr: 50.0,
    is_active: true,
    test_mode: true,
  })

  useEffect(() => {
    if (data) {
      setForm({
        provider: data.provider || 'admob',
        app_id: data.app_id || '',
        banner_unit_id: data.banner_unit_id || '',
        interstitial_unit_id: data.interstitial_unit_id || '',
        rewarded_unit_id: data.rewarded_unit_id || '',
        api_key: data.api_key || '',
        callback_secret: data.callback_secret || '',
        ads_required: data.ads_required ?? 2,
        episodes_unlocked: data.episodes_unlocked ?? 1,
        reward_ad_value_birr: data.reward_ad_value_birr ?? 0.50,
        estimated_cpm_birr: data.estimated_cpm_birr ?? 50.0,
        is_active: data.is_active ?? true,
        test_mode: data.test_mode ?? true,
      })
    }
  }, [data])

  const mutation = useMutation({
    mutationFn: (payload) => updateAdUnlockRule(payload),
    onSuccess: () => {
      toast.success('Ad configuration and monetization rules updated')
      qc.invalidateQueries({ queryKey: ['ad-unlock-rule'] })
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to update ad configuration')),
  })

  const onSave = (e) => {
    e?.preventDefault?.()
    mutation.mutate(form)
  }

  // Helper to fill Google AdMob test IDs
  const fillAdMobTestIds = () => {
    setForm((f) => ({
      ...f,
      provider: 'admob',
      app_id: 'ca-app-pub-3940256099942544~3347511713',
      rewarded_unit_id: 'ca-app-pub-3940256099942544/5224354917',
      interstitial_unit_id: 'ca-app-pub-3940256099942544/1033173712',
      banner_unit_id: 'ca-app-pub-3940256099942544/6300978111',
      test_mode: true,
    }))
    toast.success('Filled Google AdMob official test unit IDs')
  }

  const webhookUrl = `${window.location.origin}/api/v1/ads/callback`

  const handleCopyWebhook = () => {
    navigator.clipboard?.writeText(webhookUrl)
    setCopied(true)
    toast.success('Callback URL copied to clipboard')
    setTimeout(() => setCopied(false), 2500)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-xl font-bold text-text-primary">Ad Monetization & Configuration</h1>
            <Badge tone={form.is_active ? 'accent' : 'neutral'}>
              {form.is_active ? 'Ads Enabled' : 'Ads Disabled'}
            </Badge>
            {form.test_mode && <Badge tone="warning">Test Mode</Badge>}
          </div>
          <p className="mt-1 text-xs text-text-secondary">
            Manage external ad providers (AdMob, Unity, AppLovin), ad unit placements, reward unlock thresholds, and SSV webhooks.
          </p>
        </div>

        {/* Tab Switcher */}
        <div className="inline-flex rounded-lg border border-border bg-surface-1 p-1">
          <button
            onClick={() => setActiveTab('network')}
            className={`rounded-md px-3 py-1.5 text-xs font-semibold transition-colors ${
              activeTab === 'network'
                ? 'bg-accent text-white shadow-sm'
                : 'text-text-muted hover:text-text-primary'
            }`}
          >
            Network & Keys
          </button>
          <button
            onClick={() => setActiveTab('units')}
            className={`rounded-md px-3 py-1.5 text-xs font-semibold transition-colors ${
              activeTab === 'units'
                ? 'bg-accent text-white shadow-sm'
                : 'text-text-muted hover:text-text-primary'
            }`}
          >
            Ad Unit IDs
          </button>
          <button
            onClick={() => setActiveTab('rewards')}
            className={`rounded-md px-3 py-1.5 text-xs font-semibold transition-colors ${
              activeTab === 'rewards'
                ? 'bg-accent text-white shadow-sm'
                : 'text-text-muted hover:text-text-primary'
            }`}
          >
            Thresholds & Revenue
          </button>
          <button
            onClick={() => setActiveTab('webhook')}
            className={`rounded-md px-3 py-1.5 text-xs font-semibold transition-colors ${
              activeTab === 'webhook'
                ? 'bg-accent text-white shadow-sm'
                : 'text-text-muted hover:text-text-primary'
            }`}
          >
            SSV Webhook & Logs
          </button>
        </div>
      </div>

      {/* Main Card */}
      <Card padding="lg">
        {activeTab === 'network' && (
          /* Tab 1: Network & Credentials */
          <div className="space-y-5">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between border-b border-border pb-3">
              <div>
                <h3 className="text-sm font-bold text-text-primary">Ad Network Provider Settings</h3>
                <p className="text-xs text-text-muted">Select provider SDK and configure application credentials.</p>
              </div>

              <div className="flex items-center gap-3">
                <Button size="xs" variant="secondary" onClick={fillAdMobTestIds}>
                  Load AdMob Test Unit IDs
                </Button>
              </div>
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-1.5">
                <label className="text-xs font-medium text-text-secondary">Ad Network Provider</label>
                <select
                  value={form.provider}
                  onChange={(e) => setForm((f) => ({ ...f, provider: e.target.value }))}
                  className="w-full rounded-lg border border-border bg-surface-2 px-3 py-2 text-xs font-medium text-text-primary focus:border-accent focus:outline-none"
                >
                  <option value="admob">Google AdMob (Recommended)</option>
                  <option value="unity">Unity Ads</option>
                  <option value="applovin">AppLovin MAX</option>
                  <option value="custom">Custom / Direct S2S Network</option>
                </select>
              </div>

              <Input
                label="Application ID / Game ID"
                value={form.app_id}
                onChange={(e) => setForm((f) => ({ ...f, app_id: e.target.value }))}
                placeholder="e.g., ca-app-pub-3940256099942544~3347511713"
                hint="Your AdMob App ID or Unity Project Game ID"
              />
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <Input
                label="Publisher API Key / Token (Optional)"
                type="password"
                value={form.api_key}
                onChange={(e) => setForm((f) => ({ ...f, api_key: e.target.value }))}
                placeholder="••••••••••••••••"
                hint="Required only if automating inventory reports"
              />

              <Input
                label="Server-to-Server Callback Secret"
                type="password"
                value={form.callback_secret}
                onChange={(e) => setForm((f) => ({ ...f, callback_secret: e.target.value }))}
                placeholder="adwa_ssv_secret_..."
                hint="Secret shared with ad network to verify SSV reward callbacks"
              />
            </div>

            <div className="rounded-lg border border-border bg-surface-2/40 p-4 space-y-3">
              <h4 className="text-xs font-bold text-text-primary uppercase tracking-wider">Status & Environment</h4>
              <div className="flex flex-wrap gap-6 text-xs">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={form.is_active}
                    onChange={(e) => setForm((f) => ({ ...f, is_active: e.target.checked }))}
                    className="h-4 w-4 rounded border-border bg-surface-3 text-accent focus:ring-accent"
                  />
                  <span className="font-medium text-text-primary">Enable Ad Monetization Globally</span>
                </label>

                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={form.test_mode}
                    onChange={(e) => setForm((f) => ({ ...f, test_mode: e.target.checked }))}
                    className="h-4 w-4 rounded border-border bg-surface-3 text-accent focus:ring-accent"
                  />
                  <span className="font-medium text-text-primary">Test Mode (Render test ads without generating invalid traffic)</span>
                </label>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'units' && (
          /* Tab 2: Ad Unit Placements */
          <div className="space-y-5">
            <div className="border-b border-border pb-3">
              <h3 className="text-sm font-bold text-text-primary">Ad Unit Placements</h3>
              <p className="text-xs text-text-muted">Specify the ad unit IDs corresponding to each in-app placement.</p>
            </div>

            <div className="space-y-4">
              <div className="rounded-lg border border-border bg-surface-2/40 p-4">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2 font-bold text-xs text-text-primary">
                    <Tv className="h-4 w-4 text-accent" /> Rewarded Video Ad Unit (For Episode Unlocks)
                  </div>
                  <Badge tone="accent">Required for Unlocks</Badge>
                </div>
                <Input
                  value={form.rewarded_unit_id}
                  onChange={(e) => setForm((f) => ({ ...f, rewarded_unit_id: e.target.value }))}
                  placeholder="ca-app-pub-3940256099942544/5224354917"
                  hint="Users watch this rewarded ad in exchange for unlocking free episodes"
                />
              </div>

              <div className="rounded-lg border border-border bg-surface-2/40 p-4">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2 font-bold text-xs text-text-primary">
                    <Layers className="h-4 w-4 text-blue-400" /> Interstitial Ad Unit (Between Episode Transitions)
                  </div>
                  <Badge tone="neutral">Optional</Badge>
                </div>
                <Input
                  value={form.interstitial_unit_id}
                  onChange={(e) => setForm((f) => ({ ...f, interstitial_unit_id: e.target.value }))}
                  placeholder="ca-app-pub-3940256099942544/1033173712"
                  hint="Full-screen transitions shown between episodes for free-tier users"
                />
              </div>

              <div className="rounded-lg border border-border bg-surface-2/40 p-4">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2 font-bold text-xs text-text-primary">
                    <Megaphone className="h-4 w-4 text-amber-400" /> Banner Ad Unit (Feed & Shelf Placements)
                  </div>
                  <Badge tone="neutral">Optional</Badge>
                </div>
                <Input
                  value={form.banner_unit_id}
                  onChange={(e) => setForm((f) => ({ ...f, banner_unit_id: e.target.value }))}
                  placeholder="ca-app-pub-3940256099942544/6300978111"
                  hint="In-line banner displayed on home shelf feeds and browse sections"
                />
              </div>
            </div>
          </div>
        )}

        {activeTab === 'rewards' && (
          /* Tab 3: Reward Thresholds & Revenue Logic */
          <div className="space-y-5">
            <div className="border-b border-border pb-3">
              <h3 className="text-sm font-bold text-text-primary">Reward Thresholds & Revenue Attribution</h3>
              <p className="text-xs text-text-muted">Configure how many ads users must watch and the monetization attribution rules.</p>
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <Input
                label="Ads Required per Unlock"
                type="number"
                min={1}
                value={form.ads_required}
                onChange={(e) => setForm((f) => ({ ...f, ads_required: Number(e.target.value) }))}
                hint="Number of rewarded ads a viewer must finish to unlock an episode (default: 2)"
              />

              <Input
                label="Episodes Unlocked"
                type="number"
                min={1}
                value={form.episodes_unlocked}
                onChange={(e) => setForm((f) => ({ ...f, episodes_unlocked: Number(e.target.value) }))}
                hint="Number of episodes unlocked upon watching required ads (default: 1)"
              />
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <Input
                label="Static Fallback Value per Rewarded Ad (in Birr)"
                type="number"
                step="0.05"
                min={0}
                value={form.reward_ad_value_birr}
                onChange={(e) => setForm((f) => ({ ...f, reward_ad_value_birr: Number(e.target.value) }))}
                hint="Default fallback credited to ADWA SHORT platform when live impression payout is unavailable (default: 0.25 ETB)"
              />

              <Input
                label="Static Fallback Network eCPM (in Birr)"
                type="number"
                step="1"
                min={0}
                value={form.estimated_cpm_birr}
                onChange={(e) => setForm((f) => ({ ...f, estimated_cpm_birr: Number(e.target.value) }))}
                hint="Default fallback effective CPM per 1,000 ad impressions (default: 250.00 ETB)"
              />
            </div>

            {/* Strict Platform Revenue Rule Callout */}
            <div className="rounded-xl border border-accent/40 bg-accent/10 p-4 space-y-2">
              <div className="flex items-center gap-2">
                <Sparkles className="h-4 w-4 text-accent" />
                <span className="font-bold text-xs text-text-primary uppercase tracking-wider">
                  Platform Ad Revenue Retention Rule (100% Platform / 0% Creator)
                </span>
              </div>
              <p className="text-xs text-text-secondary leading-relaxed">
                Under ADWA SHORT monetization rules, <strong className="text-accent">100% of all ad-supported viewing revenue is retained by ADWA SHORT</strong>. Content creators earn 0% from ad-unlocked views (creators are compensated exclusively via Coin pay-per-view unlocks and prorated Time Pass / Subscription watch-time attribution).
              </p>
            </div>
          </div>
        )}

        {activeTab === 'webhook' && (
          /* Tab 4: S2S Webhook & Live Logs */
          <div className="space-y-6">
            <div className="border-b border-border pb-3">
              <h3 className="text-sm font-bold text-text-primary">Server-to-Server (SSV) Callback Webhook</h3>
              <p className="text-xs text-text-muted">Register this URL in Google AdMob or Unity Ads to verify ad completion server-side.</p>
            </div>

            <div className="rounded-lg border border-border bg-surface-2 p-4 space-y-2">
              <label className="text-xs font-semibold text-text-primary">SSV Reward Verification URL</label>
              <div className="flex items-center gap-2">
                <input
                  type="text"
                  readOnly
                  value={webhookUrl}
                  className="flex-1 rounded-md border border-border bg-surface-3 px-3 py-2 text-xs font-mono text-accent select-all"
                />
                <Button size="sm" variant="secondary" onClick={handleCopyWebhook} leftIcon={copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}>
                  {copied ? 'Copied' : 'Copy URL'}
                </Button>
              </div>
              <p className="text-[11px] text-text-muted">
                Accepts both GET and POST requests (aliases: <code>/api/v1/ads/callback</code>, <code>/api/v1/ads/postback</code>, <code>/ad-unlocks/reward-callback</code>). Delivers real-time impression payouts dynamically, or falls back to static 0.25 ETB.
              </p>
            </div>

            {/* Live Unlock Logs Table */}
            <div>
              <div className="mb-3 flex items-center justify-between">
                <h4 className="text-xs font-bold text-text-primary uppercase tracking-wider">
                  Recent Ad-Unlocked Viewing Logs
                </h4>
                <span className="text-[11px] text-text-muted">{logs?.length || 0} recent unlocks</span>
              </div>

              {logsLoading ? (
                <div className="flex h-32 items-center justify-center">
                  <div className="h-6 w-6 animate-spin rounded-full border-2 border-accent border-t-transparent" />
                </div>
              ) : !logs || logs.length === 0 ? (
                <div className="p-8 text-center text-xs text-text-muted rounded-lg border border-dashed border-border">
                  No ad unlocks logged yet. Once users complete ad watches, verified unlocks will appear here.
                </div>
              ) : (
                <div className="overflow-x-auto rounded-lg border border-border">
                  <table className="w-full text-left text-xs">
                    <thead className="border-b border-border bg-surface-2 text-[10px] font-semibold uppercase tracking-wider text-text-muted">
                      <tr>
                        <th className="px-3 py-2.5">Date & Time</th>
                        <th className="px-3 py-2.5">User</th>
                        <th className="px-3 py-2.5">Content Item</th>
                        <th className="px-3 py-2.5 text-center">Ads Watched</th>
                        <th className="px-3 py-2.5">Network / Verification</th>
                        <th className="px-3 py-2.5 text-right font-bold text-accent">Platform Revenue</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-border/60">
                      {logs.map((log) => (
                        <tr key={log.id} className="hover:bg-surface-2/40">
                          <td className="px-3 py-2.5 font-mono text-[11px] text-text-muted">
                            {log.unlocked_at ? new Date(log.unlocked_at).toLocaleString() : 'N/A'}
                          </td>
                          <td className="px-3 py-2.5 font-semibold text-text-primary">
                            {log.user_display_name || `User #${log.user_id}`}
                          </td>
                          <td className="px-3 py-2.5">
                            <span className="text-text-primary font-medium">{log.episode_title || `Ep #${log.episode_id}`}</span>
                            {log.series_title && <span className="text-[10px] text-text-muted ml-1.5">({log.series_title})</span>}
                          </td>
                          <td className="px-3 py-2.5 text-center font-bold">
                            {log.ads_watched}
                          </td>
                          <td className="px-3 py-2.5">
                            <Badge tone={log.verified_via === 'ssv_webhook' ? 'success' : 'neutral'}>
                              {log.ad_network || 'admob'} · {log.verified_via}
                            </Badge>
                          </td>
                          <td className="px-3 py-2.5 text-right font-bold text-accent font-mono">
                            +{formatBirr(log.revenue_birr || 0.50)}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Footer Save Button */}
        <div className="mt-6 flex items-center justify-between border-t border-border pt-4">
          <p className="text-[11px] text-text-muted">
            All updates take effect immediately in streaming clients and backend attribution.
          </p>
          <Button
            onClick={onSave}
            loading={mutation.isPending || isLoading}
            leftIcon={<Save className="h-4 w-4" />}
          >
            Save Ad Configuration
          </Button>
        </div>
      </Card>
    </div>
  )
}
