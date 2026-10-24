import { useEffect, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Megaphone, Save } from 'lucide-react'
import { useAdUnlockRule } from '../../lib/hooks'
import { put, errMsg } from '../../lib/api'
import { Card, CardHeader, CardTitle } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'

export function AdUnlockRule() {
  const qc = useQueryClient()
  const { data, isLoading } = useAdUnlockRule()
  const [form, setForm] = useState({ ads_required: 2, episodes_unlocked: 1 })

  useEffect(() => {
    if (data) setForm(data)
  }, [data])

  const mutation = useMutation({
    mutationFn: async (payload) => put('/ad-unlocks/rule', payload),
    onSuccess: () => {
      toast.success('Ad-unlock rule updated')
      qc.invalidateQueries({ queryKey: ['ad-unlock-rule'] })
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to update')),
  })

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-xl font-bold text-text-primary">Ad-Unlock Rule</h2>
        <p className="text-sm text-text-secondary">
          Configure how watching ads unlocks free episodes for non-paying users.
        </p>
      </div>

      <Card padding="lg">
        <CardHeader>
          <div className="flex items-center gap-2">
            <div className="flex h-8 w-8 items-center justify-center rounded-md bg-accent-soft text-accent">
              <Megaphone className="h-4 w-4" />
            </div>
            <CardTitle>Rule Configuration</CardTitle>
          </div>
        </CardHeader>

        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <Input
            label="Ads Required"
            type="number"
            min={1}
            value={form.ads_required}
            onChange={(e) => setForm((f) => ({ ...f, ads_required: Number(e.target.value) }))}
            hint="Number of ads a user must watch in one session"
          />
          <Input
            label="Episodes Unlocked"
            type="number"
            min={1}
            value={form.episodes_unlocked}
            onChange={(e) => setForm((f) => ({ ...f, episodes_unlocked: Number(e.target.value) }))}
            hint="Number of episodes granted after watching the ads"
          />
        </div>

        <div className="mt-4 rounded-md border border-border bg-surface-2/60 p-4 text-xs leading-relaxed text-text-secondary">
          <p className="font-semibold text-text-primary">How it works</p>
          <p className="mt-1">
            Setting <span className="text-accent">{form.ads_required} ads</span> ={' '}
            <span className="text-accent">{form.episodes_unlocked} episode(s)</span> means a user must
            watch {form.ads_required} ads in a row to unlock {form.episodes_unlocked} free episode
            {form.episodes_unlocked === 1 ? '' : 's'}. Once watched, the unlocked episode(s) remain
            accessible on the user's account indefinitely.
          </p>
        </div>

        <div className="mt-6 flex justify-end">
          <Button
            onClick={() => mutation.mutate(form)}
            loading={mutation.isPending || isLoading}
            leftIcon={<Save className="h-4 w-4" />}
          >
            Save Rule
          </Button>
        </div>
      </Card>
    </div>
  )
}
