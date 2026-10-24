import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Plus, Pencil, Trash2, Clock, HelpCircle } from 'lucide-react'
import { useTimePasses } from '../../lib/hooks'
import { del, errMsg } from '../../lib/api'
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
import { PassForm } from '../../components/content/PassForm'
import { formatBirr } from '../../lib/format'

const INFO_ITEMS = [
  'Time passes give users unlimited access to ALL content on the platform for a fixed duration.',
  'Available durations: Hourly, Daily, Weekly, Monthly, Yearly.',
  'When a pass expires, access stops automatically — no auto-renewal (unlike subscriptions).',
  'Users must manually purchase a new pass when the current one expires.',
  'Revenue from time passes is prorated based on actual consumption: if a user watches zero episodes during the pass period, creators receive 0% — the platform keeps 100%.',
  'If a user watches some episodes, revenue is split proportionally based on watch-time per creator.',
  'Unconsumed value from expired passes stays entirely with the platform.',
  'Admins can adjust pass pricing and durations based on market conditions.',
  'Passes are one-time purchases — no recurring billing.',
  'Example: A 100 Birr weekly pass gives 7 days of unlimited viewing.',
]

export function TimePasses() {
  const qc = useQueryClient()
  const { data: passes, isLoading } = useTimePasses()
  const [open, setOpen] = useState(false)
  const [editItem, setEditItem] = useState(undefined)
  const [deleteItem, setDeleteItem] = useState(null)

  const deleteMutation = useMutation({
    mutationFn: async (p) => del(`/passes/${p.id}`),
    onSuccess: () => {
      toast.success('Time pass deleted')
      qc.invalidateQueries({ queryKey: ['passes'] })
      setDeleteItem(null)
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to delete')),
  })

  const fmtHours = (h) => {
    if (h % 168 === 0) return `${h / 168} week(s)`
    if (h % 24 === 0) return `${h / 24} day(s)`
    return `${h}h`
  }

  return (
    <div className="space-y-4">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Time Passes</h2>
          <p className="text-sm text-text-secondary">
            Pay-once time-limited all-access passes (no subscription).
          </p>
        </div>
        <Button
          leftIcon={<Plus className="h-4 w-4" />}
          onClick={() => {
            setEditItem(undefined)
            setOpen(true)
          }}
        >
          Add Pass
        </Button>
      </div>

      <InfoCard title="How Time Passes Work" icon={HelpCircle} items={INFO_ITEMS} />

      <Card padding="none" className="overflow-hidden">
        <Table>
          <THead>
            <TR>
              <TH>Name</TH>
              <TH>Duration</TH>
              <TH className="text-right">Price</TH>
              <TH>Status</TH>
              <TH className="text-right">Sort</TH>
              <TH className="text-right">Actions</TH>
            </TR>
          </THead>
          <TBody>
            {isLoading ? (
              <SkeletonRow colSpan={6} rows={4} />
            ) : (passes?.length ?? 0) === 0 ? (
              <EmptyRow colSpan={6}>
                <EmptyState
                  icon={Clock}
                  title="No time passes yet"
                  description="Add a time pass like a 24-hour or weekend all-access pass."
                />
              </EmptyRow>
            ) : (
              (passes ?? []).map((p) => (
                <TR key={p.id}>
                  <TD>
                    <div className="flex items-center gap-2">
                      <div className="flex h-8 w-8 items-center justify-center rounded-md bg-warning-soft text-warning">
                        <Clock className="h-4 w-4" />
                      </div>
                      <span className="font-medium">{p.name}</span>
                    </div>
                  </TD>
                  <TD className="text-text-secondary">{fmtHours(p.duration_hours)}</TD>
                  <TD className="text-right tabular-nums font-medium">{formatBirr(p.price_birr)}</TD>
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
        title={editItem ? 'Edit Time Pass' : 'Add Time Pass'}
        size="md"
      >
        <PassForm
          initial={editItem}
          onCancel={() => setOpen(false)}
          onSaved={() => setOpen(false)}
        />
      </Modal>

      <ConfirmDialog
        open={!!deleteItem}
        title="Delete Time Pass?"
        description={`"${deleteItem?.name}" will be removed.`}
        confirmLabel="Delete"
        onConfirm={() => deleteItem && deleteMutation.mutate(deleteItem)}
        onCancel={() => setDeleteItem(null)}
        loading={deleteMutation.isPending}
      />
    </div>
  )
}
