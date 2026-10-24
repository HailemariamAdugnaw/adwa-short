import { useEffect, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import {
  Settings as SettingsIcon,
  Save,
  Smartphone,
  Coins,
  Wrench,
  Gift,
  TrendingUp,
  AlertCircle,
  RefreshCw,
  FileText,
} from 'lucide-react'
import { useSettings } from '../../lib/hooks'
import { put, errMsg } from '../../lib/api'
import { Card, CardHeader, CardTitle } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'

const SECTIONS = [
  {
    id: 'devices',
    title: 'Device & Access',
    icon: Smartphone,
    keys: ['max_devices_per_account'],
  },
  {
    id: 'pricing',
    title: 'Pricing',
    icon: Coins,
    keys: ['coin_price_birr'],
  },
  {
    id: 'content',
    title: 'Content & Reviews',
    icon: FileText,
    keys: ['free_trial_default_episodes'],
  },
  {
    id: 'revenue',
    title: 'Revenue',
    icon: TrendingUp,
    keys: ['default_creator_split_pct'],
  },
  {
    id: 'system',
    title: 'System',
    icon: Wrench,
    keys: ['maintenance_mode'],
  },
]

const RESERVED_KEYS = SECTIONS.flatMap((s) => s.keys)

const LABELS = {
  max_devices_per_account: 'Max Devices Per Account',
  free_trial_default_episodes: 'Free Trial Episodes',
  coin_price_birr: 'Coin Price (Birr)',
  maintenance_mode: 'Maintenance Mode',
  default_creator_split_pct: 'Default Creator Split (%)',
}

const HINTS = {
  max_devices_per_account: 'Standard = 2, Family = 4',
  free_trial_default_episodes: 'Episodes free for new users without subscription',
  coin_price_birr: 'Price of a single coin in Birr. Used by walk-in deposits to auto-credit coins.',
  maintenance_mode: 'Blocks mobile app access for non-admin users',
  default_creator_split_pct: 'Default percentage creators receive from revenue (0–100)',
}

export function Settings() {
  const qc = useQueryClient()
  const { data: settings, isLoading, isError, refetch } = useSettings()
  const [values, setValues] = useState({})
  const [dirtyKeys, setDirtyKeys] = useState(new Set())

  useEffect(() => {
    if (!Array.isArray(settings)) return
    const map = {}
    settings.forEach((s) => {
      map[s.key] = s.value
    })
    setValues(map)
    setDirtyKeys(new Set())
  }, [settings])

  const desc = (k) => (Array.isArray(settings) ? settings : []).find((s) => s.key === k)?.description

  const mutation = useMutation({
    mutationFn: async (payload) =>
      put(`/settings/${payload.key}`, { value: String(payload.value) }),
    onSuccess: () => {
      toast.success('Setting saved')
      qc.invalidateQueries({ queryKey: ['settings'] })
    },
    onError: (e) => toast.error(errMsg(e, 'Failed to save')),
  })

  const setValue = (key, value) => {
    setValues((v) => ({ ...v, [key]: value }))
    setDirtyKeys((s) => new Set(s).add(key))
  }

  const saveSection = (section) => {
    section.keys.forEach((k) => {
      if (dirtyKeys.has(k)) {
        mutation.mutate({ key: k, value: values[k] ?? '' })
      }
    })
    setDirtyKeys((s) => {
      const next = new Set(s)
      section.keys.forEach((k) => next.delete(k))
      return next
    })
  }

  if (isLoading) {
    return (
      <div className="space-y-4">
        <div className="skeleton h-6 w-40 rounded" />
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
          <div className="skeleton h-72 rounded-lg" />
          <div className="skeleton h-72 rounded-lg" />
          <div className="skeleton h-72 rounded-lg" />
        </div>
      </div>
    )
  }

  if (isError) {
    return (
      <div className="flex flex-col items-center justify-center gap-3 rounded-lg border border-danger/40 bg-danger-soft/20 p-10 text-center">
        <AlertCircle className="h-6 w-6 text-danger" />
        <p className="text-sm text-text-secondary">Could not load settings.</p>
        <Button
          size="sm"
          variant="ghost"
          leftIcon={<RefreshCw className="h-3.5 w-3.5" />}
          onClick={() => refetch()}
        >
          Retry
        </Button>
      </div>
    )
  }

  const getVal = (k) => values[k] ?? ''
  const isDirty = (section) => section.keys.some((k) => dirtyKeys.has(k))

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-xl font-bold text-text-primary">Settings</h2>
        <p className="text-sm text-text-secondary">
          Platform-wide configuration. Changes apply immediately to all users.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        {SECTIONS.map((section) => {
          const Icon = section.icon
          return (
            <Card padding="lg" key={section.id}>
              <CardHeader>
                <div className="flex items-center gap-2">
                  <Icon className="h-4 w-4 text-accent" />
                  <CardTitle>{section.title}</CardTitle>
                </div>
                <SaveBtn
                  dirty={isDirty(section)}
                  loading={mutation.isPending}
                  onClick={() => saveSection(section)}
                />
              </CardHeader>
              <div className="space-y-4">
                {section.id === 'system' ? (
                  <label className="flex items-center justify-between gap-3 rounded-md border border-border bg-surface-2 px-4 py-3 cursor-pointer hover:border-border-strong">
                    <div>
                      <p className="text-sm font-medium text-text-primary">Maintenance Mode</p>
                      <p className="text-[11px] text-text-muted">
                        {HINTS.maintenance_mode}
                      </p>
                    </div>
                    <input
                      type="checkbox"
                      checked={getVal('maintenance_mode') === 'true'}
                      onChange={(e) => setValue('maintenance_mode', String(e.target.checked))}
                      className="h-5 w-5 accent-accent"
                    />
                  </label>
                ) : (
                  section.keys.map((k) => (
                    <Input
                      key={k}
                      label={LABELS[k] ?? k}
                      type={k === 'coin_price_birr' || k === 'default_creator_split_pct' ? 'number' : 'text'}
                      step={k === 'coin_price_birr' ? '0.01' : undefined}
                      min={k === 'default_creator_split_pct' ? 0 : undefined}
                      max={k === 'default_creator_split_pct' ? 100 : undefined}
                      value={getVal(k)}
                      onChange={(e) => setValue(k, e.target.value)}
                      hint={desc(k) ?? HINTS[k]}
                    />
                  ))
                )}

                {section.id === 'pricing' && (
                  <div className="rounded-md border border-border bg-surface-2/40 p-3 text-[11px] leading-relaxed text-text-secondary">
                    <p className="flex items-center gap-1.5 font-semibold text-text-primary">
                      <Gift className="h-3.5 w-3.5 text-accent" /> Example
                    </p>
                    <p className="mt-1">
                      If coin price is <span className="text-accent">1.0 Birr</span> and a user
                      deposits <span className="text-accent">100 Birr</span>, they receive{' '}
                      <span className="text-accent">100 coins</span>.
                    </p>
                  </div>
                )}

                {section.id === 'revenue' && (
                  <div className="rounded-md border border-border bg-surface-2/40 p-3 text-[11px] leading-relaxed text-text-secondary">
                    <p className="font-semibold text-text-primary">How splits work</p>
                    <p className="mt-1">
                      New creators inherit this default. Per-series or per-episode overrides can be
                      set on each creator's <span className="text-accent">Split Rules</span> tab.
                    </p>
                  </div>
                )}

                {section.id === 'system' && (
                  <div className="rounded-md border border-warning/40 bg-warning-soft p-3 text-[11px] leading-relaxed text-warning">
                    <p className="font-semibold">Use with caution</p>
                    <p className="mt-1">
                      Maintenance mode immediately blocks all users from the mobile app. Admins can
                      still log in here.
                    </p>
                  </div>
                )}
              </div>
            </Card>
          )
        })}
      </div>

      {Array.isArray(settings) && settings.filter((s) => !RESERVED_KEYS.includes(s.key)).length > 0 && (
        <Card padding="lg">
          <CardHeader>
            <div className="flex items-center gap-2">
              <SettingsIcon className="h-4 w-4 text-accent" />
              <CardTitle>Other Settings</CardTitle>
            </div>
          </CardHeader>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            {settings
              .filter((s) => !RESERVED_KEYS.includes(s.key))
              .map((s) => (
                <Input
                  key={s.key}
                  label={s.key.replace(/_/g, ' ').replace(/\b\w/g, (m) => m.toUpperCase())}
                  value={getVal(s.key)}
                  onChange={(e) => setValue(s.key, e.target.value)}
                  hint={s.description ?? undefined}
                />
              ))}
          </div>
          <div className="mt-4 flex justify-end">
            <SaveBtn
              dirty={settings.some((s) => !RESERVED_KEYS.includes(s.key) && dirtyKeys.has(s.key))}
              loading={mutation.isPending}
              onClick={() => {
                settings
                  .filter((s) => !RESERVED_KEYS.includes(s.key) && dirtyKeys.has(s.key))
                  .forEach((s) => mutation.mutate({ key: s.key, value: values[s.key] ?? '' }))
                setDirtyKeys((s) => {
                  const next = new Set(s)
                  settings.forEach((sv) => {
                    if (!RESERVED_KEYS.includes(sv.key)) next.delete(sv.key)
                  })
                  return next
                })
              }}
            />
          </div>
        </Card>
      )}
    </div>
  )
}

function SaveBtn({ dirty, loading, onClick }) {
  return (
    <Button
      size="sm"
      variant={dirty ? 'primary' : 'ghost'}
      loading={loading}
      leftIcon={<Save className="h-3.5 w-3.5" />}
      onClick={onClick}
      disabled={!dirty}
    >
      Save
    </Button>
  )
}
