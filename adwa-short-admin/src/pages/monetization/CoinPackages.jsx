import { useState } from 'react'
import { Plus, Pencil, Trash2, Coins, HelpCircle } from 'lucide-react'
import { useCoinPackages } from '../../lib/hooks'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { InfoCard } from '../../components/ui/InfoCard'
import {
  Table,
  TBody,
  TD,
  TH,
  THead,
  TR,
  SkeletonRow,
  EmptyRow,
} from '../../components/ui/Table'
import { Modal } from '../../components/ui/Modal'
import { ConfirmDialog } from '../../components/ui/ConfirmDialog'
import { EmptyState } from '../../components/ui/EmptyState'
import { Badge } from '../../components/ui/Badge'
import { CoinPackageForm } from '../../components/content/CoinPackageForm'
import { del, errMsg } from '../../lib/api'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { formatBirr, formatNumber } from '../../lib/format'

const INFO_ITEMS = [
  'Users purchase coin packages using Birr (local currency) via Telebirr or wallet deposit.',
  'Each package has a fixed coin amount and price in Birr.',
  '"Episodes Unlocked" indicates how many episodes the user can unlock with this package\'s coins.',
  'The coin-to-Birr conversion rate is set in Settings (e.g., 1 coin = 1 Birr).',
  'When a user spends coins to unlock an episode, the revenue is split between the platform and the content creator based on the creator\'s revenue split percentage.',
  'Coins do not expire — once purchased, they remain in the user\'s wallet until spent.',
  'Admins can create multiple packages at different price points to give users options.',
  'Example: 50 coins for 50 Birr unlocks 5 episodes; 300 coins for 100 Birr unlocks 15 episodes (bulk discount).',
]

export function CoinPackages() {
  const qc = useQueryClient()
  const { data: packages, isLoading } = useCoinPackages()
  const [open, setOpen] = useState(false)
  const [editItem, setEditItem] = useState(undefined)
  const [deleteItem, setDeleteItem] = useState(null)

  const deleteMutation = useMutation({
    mutationFn: async (p) => del(`/coins/packages/${p.id}`),
    onSuccess: () => {
      toast.success('Package deleted')
      qc.invalidateQueries({ queryKey: ['coin-packages'] })
      setDeleteItem(null)
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to delete')),
  })

  return (
    <div className="space-y-4">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Coin Packages</h2>
          <p className="text-sm text-text-secondary">
            Coin packs users can buy with Birr to unlock episodes.
          </p>
        </div>
        <Button
          leftIcon={<Plus className="h-4 w-4" />}
          onClick={() => {
            setEditItem(undefined)
            setOpen(true)
          }}
        >
          Add Package
        </Button>
      </div>

      <InfoCard title="How Coin Packages Work" icon={HelpCircle} items={INFO_ITEMS} />

      <Card padding="none" className="overflow-hidden">
        <Table>
          <THead>
            <TR>
              <TH>Name</TH>
              <TH className="text-right">Coins</TH>
              <TH className="text-right">Price (Birr)</TH>
              <TH className="text-right">Eps unlocked</TH>
              <TH>Status</TH>
              <TH className="text-right">Sort</TH>
              <TH className="text-right">Actions</TH>
            </TR>
          </THead>
          <TBody>
            {isLoading ? (
              <SkeletonRow colSpan={7} rows={4} />
            ) : (packages?.length ?? 0) === 0 ? (
              <EmptyRow colSpan={7}>
                <EmptyState
                  icon={Coins}
                  title="No coin packages yet"
                  description="Create coin packages so users can unlock premium episodes."
                />
              </EmptyRow>
            ) : (
              (packages ?? []).map((p) => (
                <TR key={p.id}>
                  <TD>
                    <div className="flex items-center gap-2">
                      <div className="flex h-8 w-8 items-center justify-center rounded-md bg-accent-soft text-accent">
                        <Coins className="h-4 w-4" />
                      </div>
                      <span className="font-medium">{p.name}</span>
                    </div>
                  </TD>
                  <TD className="text-right tabular-nums">{formatNumber(p.coins)}</TD>
                  <TD className="text-right tabular-nums font-medium">{formatBirr(p.price_birr)}</TD>
                  <TD className="text-right tabular-nums">{p.episodes_unlocked}</TD>
                  <TD>
                    {p.is_active ? <Badge tone="success">Active</Badge> : <Badge tone="neutral">Inactive</Badge>}
                  </TD>
                  <TD className="text-right tabular-nums text-text-secondary">{p.sort_order}</TD>
                  <TD>
                    <div className="flex items-center justify-end gap-1">
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => {
                          setEditItem(p)
                          setOpen(true)
                        }}
                      >
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button variant="ghost" size="icon" onClick={() => setDeleteItem(p)}>
                        <Trash2 className="h-4 w-4 text-danger" />
                      </Button>
                    </div>
                  </TD>
                </TR>
              ))
            )}
          </TBody>
        </Table>
      </Card>

      <Modal
        open={open}
        onClose={() => setOpen(false)}
        title={editItem ? 'Edit Package' : 'Add Package'}
        size="md"
      >
        <CoinPackageForm
          initial={editItem}
          onCancel={() => setOpen(false)}
          onSaved={() => setOpen(false)}
        />
      </Modal>

      <ConfirmDialog
        open={!!deleteItem}
        title="Delete Package?"
        description={`"${deleteItem?.name}" will be removed from the catalog.`}
        confirmLabel="Delete"
        onConfirm={() => deleteItem && deleteMutation.mutate(deleteItem)}
        onCancel={() => setDeleteItem(null)}
        loading={deleteMutation.isPending}
      />
    </div>
  )
}
