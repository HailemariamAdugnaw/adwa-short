import { useState } from 'react'
import { Save, X } from 'lucide-react'
import { Button } from '../ui/Button'
import { Input } from '../ui/Input'
import { Textarea } from '../ui/Textarea'
import { useProcessPayout } from '../../lib/hooks'
import { formatBirr } from '../../lib/format'

export function PayoutForm({ creator, pendingBalance, onSaved, onCancel }) {
  const mutation = useProcessPayout()
  const [form, setForm] = useState({
    amount: pendingBalance ? String(pendingBalance) : '',
    notes: '',
  })

  const onSubmit = (e) => {
    e.preventDefault()
    const amount = Number(form.amount)
    if (!amount || amount <= 0) return
    mutation.mutate(
      {
        id: creator.id,
        data: {
          amount_birr: amount,
          notes: form.notes || undefined,
        },
      },
      { onSuccess: () => onSaved?.() },
    )
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      <div className="rounded-md border border-border bg-surface-2/50 p-3 text-xs text-text-secondary">
        <p className="font-semibold text-text-primary">Payout to {creator?.name ?? 'creator'}</p>
        {pendingBalance != null && (
          <p className="mt-1">
            Pending balance:{' '}
            <span className="text-accent">{formatBirr(pendingBalance)}</span>
          </p>
        )}
        {creator?.bank_name && (
          <p className="mt-1">
            {creator.bank_name} · {creator.bank_account_name ?? '—'} ·{' '}
            {creator.bank_account_number ?? '—'}
          </p>
        )}
      </div>

      <Input
        label="Amount (Birr)"
        type="number"
        step="0.01"
        min={0}
        value={form.amount}
        onChange={(e) => setForm((f) => ({ ...f, amount: e.target.value }))}
        placeholder="e.g. 1000"
        required
      />

      <Textarea
        label="Notes (optional)"
        value={form.notes}
        onChange={(e) => setForm((f) => ({ ...f, notes: e.target.value }))}
        placeholder="Internal note about this payout"
      />

      <div className="flex items-center justify-end gap-2 pt-2">
        <Button type="button" variant="ghost" onClick={onCancel} leftIcon={<X className="h-4 w-4" />}>
          Cancel
        </Button>
        <Button type="submit" loading={mutation.isPending} leftIcon={<Save className="h-4 w-4" />}>
          Process Payout
        </Button>
      </div>
    </form>
  )
}
