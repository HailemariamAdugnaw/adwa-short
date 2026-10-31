import { useEffect, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import {
  Megaphone,
  Save,
  ShieldCheck,
  Tv,
  Copy,
  Layers,
  Sparkles,
  Check,
} from 'lucide-react'
import { useAdUnlockRule, useAdUnlockLogs } from '../../lib/hooks'
import { updateAdUnlockRule, errMsg } from '../../lib/api'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
import { Badge } from '../../components/ui/Badge'
import { formatBirr } from '../../lib/format'

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
      {/* Header Banner */}
      <div className="relative overflow-hidden rounded-2xl border border-[#C8102E]/30 bg-gradient-to-r from-[#160608] via-[#0B0406] to-[#000000] p-5 shadow-[0_0_30px_-12px_rgba(200,16,46,0.35)]">
        <div className="absolute -top-12 -left-12 h-40 w-40 rounded-full bg-[#C8102E]/15 blur-3xl pointer-events-none" />
        <div className="relative flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div className="flex flex-wrap items-center gap-2.5">
              <h1 className="text-xl font-extrabold tracking-tight text-white">
                Ad Monetization & Configuration
              </h1>
              <div className="flex items-center gap-1.5 rounded-full border border-[#C8102E]/40 bg-[#C8102E]/15 px-3 py-1 text-xs font-semibold text-white">
                <span className={`h-2 w-2 rounded-full ${form.is_active ? 'bg-[#E50914] animate-pulse' : 'bg-zinc-500'}`} />
                <span>{form.is_active ? 'Ads Live' : 'Ads Disabled'}</span>
              </div>
              {form.test_mode && (
                <Badge tone="warning">Test Mode</Badge>
              )}
            </div>
            <p className="mt-1 text-xs text-zinc-400">
              Manage Google AdMob integration, ad unit placements, reward unlock thresholds, and SSV webhooks.
            </p>
          </div>

          {/* Tab Switcher */}
          <div className="inline-flex rounded-xl border border-[#2E1015] bg-[#0A0507] p-1 shadow-inner">
            {[
              { id: 'network', label: 'Network & Keys' },
              { id: 'units', label: 'Ad Unit IDs' },
              { id: 'rewards', label: 'Thresholds & Revenue' },
              { id: 'webhook', label: 'SSV Webhook & Logs' },
            ].map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-all cursor-pointer ${
                  activeTab === tab.id
                    ? 'bg-gradient-to-r from-[#E50914] to-[#B00710] text-white shadow-[0_0_12px_rgba(229,9,20,0.5)]'
                    : 'text-zinc-400 hover:text-white hover:bg-white/5'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Main Card */}
      <Card padding="lg" className="border border-[#C8102E]/25 bg-[#08080C] shadow-[0_0_35px_-15px_rgba(200,16,46,0.25)]">
        {activeTab === 'network' && (
          /* Tab 1: Network & Credentials */
          <div className="space-y-5">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between border-b border-[#2A1014] pb-4">
              <div>
                <h3 className="text-sm font-bold text-white flex items-center gap-2">
                  <span className="h-2 w-2 rounded-full bg-[#E50914]" />
                  Ad Network Provider Settings
                </h3>
                <p className="text-xs text-zinc-400 mt-0.5">Select provider SDK and configure application credentials.</p>
              </div>

              <div className="flex items-center gap-3">
                <Button
                  size="xs"
                  variant="secondary"
                  onClick={fillAdMobTestIds}
                  className="border-[#C8102E]/40 text-white hover:bg-[#C8102E]/15 hover:border-[#C8102E]"
                >
                  Load AdMob Test Unit IDs
                </Button>
              </div>
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-1.5">
                <label className="text-xs font-medium text-zinc-300">Exclusive Ad Network Provider</label>
                <div className="flex items-center justify-between rounded-xl border border-[#381016] bg-[#0E0709] px-3.5 py-2.5 text-xs font-medium text-white shadow-inner">
                  <div className="flex items-center gap-2.5">
                    <span className="inline-block h-2.5 w-2.5 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.7)]" />
                    <span className="font-bold text-white tracking-wide">Google AdMob</span>
                  </div>
                  <Badge tone="accent">Exclusive Network</Badge>
                </div>
              </div>

              <Input
                label="Google AdMob Application ID"
                value={form.app_id}
                onChange={(e) => setForm((f) => ({ ...f, app_id: e.target.value }))}
                placeholder="ca-app-pub-3940256099942544~3347511713"
                hint="Your Google AdMob App ID (format: ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX)"
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
                hint="Secret shared with Google AdMob SSV setup to verify reward callbacks"
              />
            </div>

            <div className="rounded-xl border border-[#381016] bg-[#0D0A0C] p-4 space-y-3">
              <h4 className="text-xs font-bold text-white uppercase tracking-wider flex items-center gap-2">
                <ShieldCheck className="h-4 w-4 text-[#E50914]" />
                Status & Global Environment
              </h4>
              <div className="flex flex-wrap gap-6 text-xs">
                <label className="flex items-center gap-2.5 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={form.is_active}
                    onChange={(e) => setForm((f) => ({ ...f, is_active: e.target.checked }))}
                    className="h-4 w-4 rounded border-[#381016] bg-black text-[#E50914] focus:ring-[#E50914]"
                  />
                  <span className="font-medium text-white">Enable Ad Monetization Globally</span>
                </label>

                <label className="flex items-center gap-2.5 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={form.test_mode}
                    onChange={(e) => setForm((f) => ({ ...f, test_mode: e.target.checked }))}
                    className="h-4 w-4 rounded border-[#381016] bg-black text-[#E50914] focus:ring-[#E50914]"
                  />
                  <span className="font-medium text-white">Test Mode (Render test ads without generating invalid traffic)</span>
                </label>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'units' && (
          /* Tab 2: Ad Unit Placements */
          <div className="space-y-5">
            <div className="border-b border-[#2A1014] pb-4">
              <h3 className="text-sm font-bold text-white flex items-center gap-2">
                <span className="h-2 w-2 rounded-full bg-[#E50914]" />
                Ad Unit Placements
              </h3>
              <p className="text-xs text-zinc-400 mt-0.5">Specify the ad unit IDs corresponding to each in-app placement.</p>
            </div>

            <div className="space-y-4">
              {/* Rewarded Video */}
              <div className="rounded-xl border border-[#C8102E]/40 bg-gradient-to-r from-[#18070A] to-[#0E0608] p-4 shadow-[0_0_20px_-10px_rgba(200,16,46,0.3)]">
                <div className="flex items-center justify-between mb-2.5">
                  <div className="flex items-center gap-2 font-bold text-xs text-white">
                    <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-[#C8102E]/20 text-[#E50914]">
                      <Tv className="h-4 w-4" />
                    </div>
                    <span>Rewarded Video Ad Unit (For Episode Unlocks)</span>
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

              {/* Interstitial */}
              <div className="rounded-xl border border-[#381016] bg-[#0D0A0C] p-4">
                <div className="flex items-center justify-between mb-2.5">
                  <div className="flex items-center gap-2 font-bold text-xs text-white">
                    <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-blue-500/15 text-blue-400">
                      <Layers className="h-4 w-4" />
                    </div>
                    <span>Interstitial Ad Unit (Between Episode Transitions)</span>
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

              {/* Banner */}
              <div className="rounded-xl border border-[#381016] bg-[#0D0A0C] p-4">
                <div className="flex items-center justify-between mb-2.5">
                  <div className="flex items-center gap-2 font-bold text-xs text-white">
                    <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-amber-500/15 text-amber-400">
                      <Megaphone className="h-4 w-4" />
                    </div>
                    <span>Banner Ad Unit (Feed & Shelf Placements)</span>
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
            <div className="border-b border-[#2A1014] pb-4">
              <h3 className="text-sm font-bold text-white flex items-center gap-2">
                <span className="h-2 w-2 rounded-full bg-[#E50914]" />
                Reward Thresholds & Revenue Attribution
              </h3>
              <p className="text-xs text-zinc-400 mt-0.5">Configure how many ads users must watch and the monetization attribution rules.</p>
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

            {/* Strict Live Google AdMob Monitoring Info */}
            <div className="rounded-xl border border-emerald-500/30 bg-[#06120D] p-4 space-y-2">
              <div className="flex items-center gap-2">
                <ShieldCheck className="h-4 w-4 text-emerald-400" />
                <span className="font-bold text-xs text-emerald-300 uppercase tracking-wider">
                  Strict Live Google AdMob Monitoring (Zero Static Fallback)
                </span>
              </div>
              <p className="text-xs text-zinc-300 leading-relaxed">
                Ad revenue is monitored and tracked strictly through verified live payout data provided by Google AdMob (via server-to-server SSV callbacks or SDK impression verification). Static fallback values (<code className="text-[#E50914] font-mono text-[11px]">AD_REWARD_VALUE_BIRR</code> / <code className="text-[#E50914] font-mono text-[11px]">AD_ESTIMATED_CPM_BIRR</code>) have been removed—if live payout data is absent, ad views are logged with 0.00 ETB revenue to prevent arbitrary ledger balances.
              </p>
            </div>

            {/* Strict Platform Revenue Rule Callout */}
            <div className="rounded-xl border border-[#C8102E]/60 bg-gradient-to-r from-[#220609] to-[#120406] p-4 space-y-2 shadow-[0_0_24px_-10px_rgba(200,16,46,0.4)]">
              <div className="flex items-center gap-2">
                <Sparkles className="h-4 w-4 text-[#E50914]" />
                <span className="font-bold text-xs text-white uppercase tracking-wider">
                  Platform Ad Revenue Retention Rule (100% Platform / 0% Creator)
                </span>
              </div>
              <p className="text-xs text-zinc-300 leading-relaxed">
                Under ADWA SHORT monetization rules, <strong className="text-[#E50914] font-semibold">100% of all ad-supported viewing revenue is retained by ADWA SHORT</strong>. Content creators earn 0% from ad-unlocked views (creators are compensated exclusively via Coin pay-per-view unlocks and prorated Time Pass / Subscription watch-time attribution).
              </p>
            </div>
          </div>
        )}

        {activeTab === 'webhook' && (
          /* Tab 4: S2S Webhook & Live Logs */
          <div className="space-y-6">
            <div className="border-b border-[#2A1014] pb-4">
              <h3 className="text-sm font-bold text-white flex items-center gap-2">
                <span className="h-2 w-2 rounded-full bg-[#E50914]" />
                Google AdMob Server-Side Verification (SSV) Callback Webhook
              </h3>
              <p className="text-xs text-zinc-400 mt-0.5">Register this URL in Google AdMob Ad Unit settings (Server-Side Verification / SSV) to verify ad completion server-side.</p>
            </div>

            <div className="rounded-xl border border-[#381016] bg-[#0D0A0C] p-4 space-y-2.5">
              <label className="text-xs font-semibold text-white">SSV Reward Verification URL</label>
              <div className="flex items-center gap-2">
                <input
                  type="text"
                  readOnly
                  value={webhookUrl}
                  className="flex-1 rounded-lg border border-[#C8102E]/40 bg-black px-3.5 py-2.5 text-xs font-mono text-[#FF4D5E] select-all shadow-inner focus:outline-none"
                />
                <Button
                  size="sm"
                  variant="secondary"
                  onClick={handleCopyWebhook}
                  leftIcon={copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
                  className="border-[#C8102E]/40 text-white hover:bg-[#C8102E]/20"
                >
                  {copied ? 'Copied' : 'Copy URL'}
                </Button>
              </div>
              <p className="text-[11px] text-zinc-400">
                Accepts both GET and POST requests (aliases: <code className="text-zinc-300 font-mono">/api/v1/ads/callback</code>, <code className="text-zinc-300 font-mono">/api/v1/ads/postback</code>, <code className="text-zinc-300 font-mono">/ad-unlocks/reward-callback</code>). Delivers real-time verified Google AdMob impression payouts dynamically.
              </p>
            </div>

            {/* Live Unlock Logs Table */}
            <div>
              <div className="mb-3 flex items-center justify-between">
                <h4 className="text-xs font-bold text-white uppercase tracking-wider">
                  Recent Ad-Unlocked Viewing Logs
                </h4>
                <span className="text-[11px] text-zinc-400">{logs?.length || 0} recent unlocks</span>
              </div>

              {logsLoading ? (
                <div className="flex h-32 items-center justify-center">
                  <div className="h-6 w-6 animate-spin rounded-full border-2 border-[#E50914] border-t-transparent" />
                </div>
              ) : !logs || logs.length === 0 ? (
                <div className="p-8 text-center text-xs text-zinc-500 rounded-xl border border-dashed border-[#381016] bg-black">
                  No ad unlocks logged yet. Once users complete ad watches, verified unlocks will appear here.
                </div>
              ) : (
                <div className="overflow-x-auto rounded-xl border border-[#381016]">
                  <table className="w-full text-left text-xs">
                    <thead className="border-b border-[#381016] bg-[#12080A] text-[10px] font-semibold uppercase tracking-wider text-zinc-400">
                      <tr>
                        <th className="px-3.5 py-3">Date & Time</th>
                        <th className="px-3.5 py-3">User</th>
                        <th className="px-3.5 py-3">Content Item</th>
                        <th className="px-3.5 py-3 text-center">Ads Watched</th>
                        <th className="px-3.5 py-3">Network / Verification</th>
                        <th className="px-3.5 py-3 text-right font-bold text-[#E50914]">Platform Revenue</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-[#2A1014] bg-black">
                      {logs.map((log) => (
                        <tr key={log.id} className="hover:bg-[#180A0E]/50 transition-colors">
                          <td className="px-3.5 py-3 font-mono text-[11px] text-zinc-400">
                            {log.unlocked_at ? new Date(log.unlocked_at).toLocaleString() : 'N/A'}
                          </td>
                          <td className="px-3.5 py-3 font-semibold text-white">
                            {log.user_display_name || `User #${log.user_id}`}
                          </td>
                          <td className="px-3.5 py-3">
                            <span className="text-white font-medium">{log.episode_title || `Ep #${log.episode_id}`}</span>
                            {log.series_title && <span className="text-[10px] text-zinc-400 ml-1.5">({log.series_title})</span>}
                          </td>
                          <td className="px-3.5 py-3 text-center font-bold text-white">
                            {log.ads_watched}
                          </td>
                          <td className="px-3.5 py-3">
                            <Badge tone={log.verified_via === 'ssv_webhook' ? 'success' : 'neutral'}>
                              {log.ad_network || 'admob'} · {log.verified_via}
                            </Badge>
                          </td>
                          <td className="px-3.5 py-3 text-right font-bold text-[#E50914] font-mono">
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
        <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between border-t border-[#2A1014] pt-5">
          <p className="text-[11px] text-zinc-400">
            All updates take effect immediately in streaming clients and backend attribution.
          </p>
          <Button
            onClick={onSave}
            loading={mutation.isPending || isLoading}
            leftIcon={<Save className="h-4 w-4" />}
            className="bg-gradient-to-r from-[#E50914] to-[#B00710] text-white font-bold shadow-[0_0_16px_rgba(229,9,20,0.5)] hover:shadow-[0_0_24px_rgba(229,9,20,0.7)] cursor-pointer"
          >
            Save Ad Configuration
          </Button>
        </div>
      </Card>
    </div>
  )
}
