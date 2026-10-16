import { useEffect, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Button } from '../ui/Button'
import { Input } from '../ui/Input'
import { Select } from '../ui/Select'
import { post, put, errMsg } from '../../lib/api'

export function SubscriptionPlanForm({ initial, onSaved, onCancel }) {
  const qc = useQueryClient()
  const isEdit = !!initial

  const [form, setForm] = useState({
    name: '',
    billing_cycle: 'monthly',
    price_birr: 0,
    is_active: true,
  })

  useEffect(() => {
    if (!initial) return
    setForm({
      name: initial.name,
      billing_cycle: initial.billing_cycle,
      price_birr: initial.price_birr,
      is_active: initial.is_active,
    })
  }, [initial])

  const mutation = useMutation({
    mutationFn: async (payload) => {
      if (isEdit && initial)
        return put(`/subscriptions/plans/${initial.id}`, payload)
      return post('/subscriptions/plans', payload)
    },
    onSuccess: () => {
      toast.success(isEdit ? 'Plan updated' : 'Plan created')
      qc.invalidateQueries({ queryKey: ['subscription-plans'] })
      onSaved?.()
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to save plan')),
  })

  const onSubmit = (e) => {
    e.preventDefault()
    if (!form.name.trim()) return toast.error('Name required')
    mutation.mutate(form)
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      <Input
        label="Plan Name"
        value={form.name}
        onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
        placeholder="e.g. Premium Monthly"
        required
      />
      <div className="grid grid-cols-2 gap-4">
        <Select
          label="Billing Cycle"
          value={form.billing_cycle}
          onChange={(e) => setForm((f) => ({ ...f, billing_cycle: e.target.value }))}
        >
          <option value="monthly" className="bg-surface">Monthly</option>
          <option value="quarterly" className="bg-surface">Quarterly</option>
          <option value="yearly" className="bg-surface">Yearly</option>
        </Select>
        <Input
          label="Price (Birr)"
          type="number"
          step="0.01"
          min={0}
          value={form.price_birr}
          onChange={(e) => setForm((f) => ({ ...f, price_birr: Number(e.target.value) }))}
          required
        />
      </div>
      <label className="flex h-12 cursor-pointer items-center justify-between gap-3 rounded-md border border-border bg-surface-2 px-4 py-2 hover:border-border-strong">
        <span className="text-sm font-medium text-text-primary">Active</span>
        <input
          type="checkbox"
          checked={form.is_active}
          onChange={(e) => setForm((f) => ({ ...f, is_active: e.target.checked }))}
          className="h-4 w-4 accent-accent"
        />
      </label>
      <div className="flex items-center justify-end gap-2 pt-2">
        <Button type="button" variant="ghost" onClick={onCancel}>
          Cancel
        </Button>
        <Button type="submit" loading={mutation.isPending}>
          {isEdit ? 'Save Changes' : 'Create Plan'}
        </Button>
      </div>
    </form>
  )
}
