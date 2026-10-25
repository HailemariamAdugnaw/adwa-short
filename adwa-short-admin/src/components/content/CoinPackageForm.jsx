import { useEffect, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Button } from '../ui/Button'
import { Input } from '../ui/Input'
import { post, put, errMsg } from '../../lib/api'

export function CoinPackageForm({ initial, onSaved, onCancel }) {
  const qc = useQueryClient()
  const isEdit = !!initial

  const [form, setForm] = useState({
    name: '',
    coins: 0,
    price_birr: 0,
    is_active: true,
    sort_order: 0,
  })

  useEffect(() => {
    if (!initial) return
    setForm({
      name: initial.name,
      coins: initial.coins,
      price_birr: initial.price_birr,
      is_active: initial.is_active,
      sort_order: initial.sort_order,
    })
  }, [initial])

  const mutation = useMutation({
    mutationFn: async (payload) => {
      if (isEdit && initial) return put(`/coins/packages/${initial.id}`, payload)
      return post('/coins/packages', payload)
    },
    onSuccess: () => {
      toast.success(isEdit ? 'Package updated' : 'Package created')
      qc.invalidateQueries({ queryKey: ['coin-packages'] })
      onSaved?.()
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to save package')),
  })

  const onSubmit = (e) => {
    e.preventDefault()
    if (!form.name.trim()) return toast.error('Name required')
    mutation.mutate(form)
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      <Input
        label="Package Name"
        value={form.name}
        onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
        placeholder="e.g. Starter Pack"
        required
      />
      <div className="grid grid-cols-2 gap-4">
        <Input
          label="Coins"
          type="number"
          min={0}
          value={form.coins}
          onChange={(e) => setForm((f) => ({ ...f, coins: Number(e.target.value) }))}
          required
        />
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
      <Input
        label="Sort Order"
        type="number"
        min={0}
        value={form.sort_order ?? 0}
        onChange={(e) => setForm((f) => ({ ...f, sort_order: Number(e.target.value) }))}
      />
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
          {isEdit ? 'Save Changes' : 'Create Package'}
        </Button>
      </div>
    </form>
  )
}
