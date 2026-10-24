import { useEffect, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Award, Save } from 'lucide-react'
import { useLoyaltyConfig } from '../../lib/hooks'
import { put, errMsg } from '../../lib/api'
import { Card, CardHeader, CardTitle } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'

export function LoyaltyConfig() {
  const qc = useQueryClient()
  const { data, isLoading } = useLoyaltyConfig()
  const [form, setForm] = useState({
    min_balance_birr: 50,
    max_balance_birr: 1000,
    daily_access_days: 30,
    free_coins: 10,
    free_full_series_count: 1,
  })

  useEffect(() => {
    if (data) setForm(data)
  }, [data])

  const mutation = useMutation({
    mutationFn: async (payload) => put('/loyalty/config', payload),
    onSuccess: () => {
      toast.success('Loyalty config updated')
      qc.invalidateQueries({ queryKey: ['loyalty-config'] })
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to update')),
  })

  const fields = [
    {
      key: 'min_balance_birr',
      label: 'Min Wallet Balance (Birr)',
      hint: 'Minimum balance a user must keep to qualify for loyalty perks',
    },
    {
      key: 'max_balance_birr',
      label: 'Max Wallet Balance (Birr)',
      hint: 'Above this threshold, additional perks cap out',
    },
    {
      key: 'daily_access_days',
      label: 'Daily Access (days)',
      hint: 'Number of days of free access granted per loyalty cycle',
    },
    {
      key: 'free_coins',
      label: 'Free Coins',
      hint: 'Coins credited to the wallet per loyalty cycle',
    },
    {
      key: 'free_full_series_count',
      label: 'Free Full Series',
      hint: 'Number of full series unlocked for loyal users',
    },
  ]

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-xl font-bold text-text-primary">Loyalty Configuration</h2>
        <p className="text-sm text-text-secondary">
          Reward users who maintain a healthy wallet balance with free perks.
        </p>
      </div>

      <Card padding="lg">
        <CardHeader>
          <div className="flex items-center gap-2">
            <div className="flex h-8 w-8 items-center justify-center rounded-md bg-warning-soft text-warning">
              <Award className="h-4 w-4" />
            </div>
            <CardTitle>Loyalty Tiers & Perks</CardTitle>
          </div>
        </CardHeader>

        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          {fields.map((f) => (
            <Input
              key={f.key}
              label={f.label}
              type="number"
              min={0}
              step={f.key.includes('birr') ? '0.01' : '1'}
              value={form[f.key]}
              onChange={(e) => setForm((s) => ({ ...s, [f.key]: Number(e.target.value) }))}
              hint={f.hint}
            />
          ))}
        </div>

        <div className="mt-4 rounded-md border border-border bg-surface-2/60 p-4 text-xs leading-relaxed text-text-secondary">
          <p className="font-semibold text-text-primary">How loyalty works</p>
          <p className="mt-1">
            Users with a wallet balance between{' '}
            <span className="text-accent">{form.min_balance_birr} Birr</span> and{' '}
            <span className="text-accent">{form.max_balance_birr} Birr</span> qualify for loyalty
            perks. Each cycle they receive{' '}
            <span className="text-accent">{form.daily_access_days} days</span> of daily access,{' '}
            <span className="text-accent">{form.free_coins} free coins</span>, and{' '}
            <span className="text-accent">{form.free_full_series_count} full series unlock(s)</span>.
          </p>
        </div>

        <div className="mt-6 flex justify-end">
          <Button
            onClick={() => mutation.mutate(form)}
            loading={mutation.isPending || isLoading}
            leftIcon={<Save className="h-4 w-4" />}
          >
            Save Configuration
          </Button>
        </div>
      </Card>
    </div>
  )
}
