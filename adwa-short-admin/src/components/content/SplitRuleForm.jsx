import { useEffect, useState } from 'react'
import { Save, X } from 'lucide-react'
import { Button } from '../ui/Button'
import { Input } from '../ui/Input'
import { Select } from '../ui/Select'
import { useSetCreatorSplit } from '../../lib/hooks'

const SCOPES = [
  { value: 'creator', label: 'Creator-wide (default)' },
  { value: 'series', label: 'Specific Series' },
  { value: 'episode', label: 'Specific Episode' },
]

export function SplitRuleForm({ creatorId, series = [], episodes = [], initial, onSaved, onCancel }) {
  const mutation = useSetCreatorSplit()
  const isEdit = !!initial

  const [form, setForm] = useState({
    scope: 'creator',
    series_id: '',
    episode_id: '',
    creator_share_pct: 50,
    label: '',
  })

  useEffect(() => {
    if (!initial) return
    let scope = 'creator'
    if (initial.episode_id) scope = 'episode'
    else if (initial.series_id) scope = 'series'
    setForm({
      scope,
      series_id: initial.series_id ?? '',
      episode_id: initial.episode_id ?? '',
      creator_share_pct: initial.creator_share_pct ?? 50,
      label: initial.label ?? '',
    })
  }, [initial])

  const onSubmit = (e) => {
    e.preventDefault()
    const pct = Number(form.creator_share_pct)
    if (Number.isNaN(pct) || pct < 0 || pct > 100) {
      return
    }
    if (form.scope === 'series' && !form.series_id) return
    if (form.scope === 'episode' && !form.episode_id) return
    const payload = {
      scope: form.scope,
      creator_share_pct: pct,
      label: form.label || undefined,
    }
    if (form.scope === 'series') payload.series_id = Number(form.series_id)
    if (form.scope === 'episode') payload.episode_id = Number(form.episode_id)
    if (isEdit && initial?.id) {
      payload.id = initial.id
      payload.rule_id = initial.id
    }
    mutation.mutate(
      { id: creatorId, data: payload },
      { onSuccess: () => onSaved?.() },
    )
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      <Select
        label="Scope"
        value={form.scope}
        onChange={(e) => setForm((f) => ({ ...f, scope: e.target.value, series_id: '', episode_id: '' }))}
        disabled={isEdit}
      >
        {SCOPES.map((s) => (
          <option key={s.value} value={s.value} className="bg-surface">
            {s.label}
          </option>
        ))}
      </Select>

      {form.scope === 'series' && (
        <Select
          label="Target Series"
          value={form.series_id}
          onChange={(e) => setForm((f) => ({ ...f, series_id: e.target.value }))}
          required
        >
          <option value="">Select series…</option>
          {series.map((s) => (
            <option key={s.id} value={s.id} className="bg-surface">
              {s.title}
            </option>
          ))}
        </Select>
      )}

      {form.scope === 'episode' && (
        <Select
          label="Target Episode"
          value={form.episode_id}
          onChange={(e) => setForm((f) => ({ ...f, episode_id: e.target.value }))}
          required
        >
          <option value="">Select episode…</option>
          {episodes.map((ep) => (
            <option key={ep.id} value={ep.id} className="bg-surface">
              Ep {ep.episode_number} · {ep.title}
            </option>
          ))}
        </Select>
      )}

      <div>
        <Input
          label="Creator Share (%)"
          type="number"
          min={0}
          max={100}
          value={form.creator_share_pct}
          onChange={(e) => setForm((f) => ({ ...f, creator_share_pct: Number(e.target.value) }))}
          hint={`Creator: ${form.creator_share_pct}% · Platform: ${100 - (Number(form.creator_share_pct) || 0)}%`}
          required
        />
        <div className="mt-2 flex items-center gap-1.5">
          <span className="text-[11px] text-text-muted">Presets:</span>
          {[
            { label: '50/50', pct: 50 },
            { label: '60/40', pct: 60 },
            { label: '70/30', pct: 70 },
            { label: '80/20', pct: 80 },
          ].map((preset) => (
            <button
              key={preset.label}
              type="button"
              onClick={() => setForm((f) => ({ ...f, creator_share_pct: preset.pct }))}
              className={`rounded border px-2 py-0.5 text-xs font-medium transition-colors ${
                Number(form.creator_share_pct) === preset.pct
                  ? 'border-accent bg-accent/10 text-accent font-semibold'
                  : 'border-border bg-surface-2 text-text-secondary hover:border-border-strong'
              }`}
            >
              {preset.label}
            </button>
          ))}
        </div>
      </div>

      <Input
        label="Label (optional)"
        value={form.label}
        onChange={(e) => setForm((f) => ({ ...f, label: e.target.value }))}
        placeholder="e.g. Promo period, Special deal"
      />

      <div className="flex items-center justify-end gap-2 pt-2">
        <Button type="button" variant="ghost" onClick={onCancel} leftIcon={<X className="h-4 w-4" />}>
          Cancel
        </Button>
        <Button type="submit" loading={mutation.isPending} leftIcon={<Save className="h-4 w-4" />}>
          {isEdit ? 'Save Rule' : 'Add Rule'}
        </Button>
      </div>
    </form>
  )
}
