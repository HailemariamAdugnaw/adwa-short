import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Plus, Pencil, Trash2, CreditCard, HelpCircle } from 'lucide-react'
import { useSubscriptionPlans } from '../../lib/hooks'
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
import { SubscriptionPlanForm } from '../../components/content/SubscriptionPlanForm'
import { formatBirr } from '../../lib/format'

const SUBSCRIPTION_INFO_ITEMS = [
  'Subscriptions provide users with ongoing VIP recurring access to all current and upcoming short drama series on ADWA SHORT without coin paywalls.',
  'Available billing cycles: Weekly, Monthly, or Yearly, processed in Ethiopian Birr (ETB) via Commercial Bank of Ethiopia (CBE / CBE Birr) or platform wallet.',
  'Automatic renewal recurs at the end of each billing cycle unless cancelled by the user in their account settings at least 24 hours prior.',
  'Subscribers enjoy 100% ad-free viewing, ultra-fast streaming bandwidth, and instant access to all new releases.',
  'Revenue from subscription plans is pooled and shared with creators based on verified aggregate watch-time per billing cycle.',
  'Admins can create and activate multiple subscription tiers with custom pricing and duration to incentivize user retention.',
]

export function Subscriptions() {
  const qc = useQueryClient()
  const { data: plans, isLoading } = useSubscriptionPlans()
  const [open, setOpen] = useState(false)
  const [editItem, setEditItem] = useState(undefined)
  const [deleteItem, setDeleteItem] = useState(null)

  const deleteMutation = useMutation({
    mutationFn: async (p) => del(`/subscriptions/plans/${p.id}`),
    onSuccess: () => {
      toast.success('Plan deleted')
      qc.invalidateQueries({ queryKey: ['subscription-plans'] })
      setDeleteItem(null)
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to delete')),
  })

  return (
    <div className="space-y-4">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Subscription Plans</h2>
          <p className="text-sm text-text-secondary">
            Recurring subscription tiers users can subscribe to.
          </p>
        </div>
        <Button
          leftIcon={<Plus className="h-4 w-4" />}
          onClick={() => {
            setEditItem(undefined)
            setOpen(true)
          }}
        >
          Add Plan
        </Button>
      </div>

      <Card padding="none" className="overflow-hidden">
        <Table>
          <THead>
            <TR>
              <TH>Plan</TH>
              <TH>Billing Cycle</TH>
              <TH className="text-right">Price</TH>
              <TH>Status</TH>
              <TH className="text-right">Actions</TH>
            </TR>
          </THead>
          <TBody>
            {isLoading ? (
              <SkeletonRow colSpan={5} rows={3} />
            ) : (plans?.length ?? 0) === 0 ? (
              <EmptyRow colSpan={5}>
                <EmptyState
                  icon={CreditCard}
                  title="No subscription plans yet"
                  description="Add at least one plan (e.g. Monthly Premium)."
                />
              </EmptyRow>
            ) : (
              (plans ?? []).map((p) => (
                <TR key={p.id}>
                  <TD>
                    <div className="flex items-center gap-2">
                      <div className="flex h-8 w-8 items-center justify-center rounded-md bg-accent-soft text-accent">
                        <CreditCard className="h-4 w-4" />
                      </div>
                      <span className="font-medium">{p.name}</span>
                    </div>
                  </TD>
                  <TD className="capitalize text-text-secondary">{p.billing_cycle}</TD>
                  <TD className="text-right tabular-nums font-medium">{formatBirr(p.price_birr)}</TD>
                  <TD>
                    {p.is_active ? <Badge tone="success">Active</Badge> : <Badge tone="neutral">Inactive</Badge>}
                  </TD>
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

      <InfoCard title="How Subscriptions Work" icon={HelpCircle} items={SUBSCRIPTION_INFO_ITEMS} />

      <Modal
        open={open}
        onClose={() => setOpen(false)}
        title={editItem ? 'Edit Plan' : 'Add Plan'}
        size="md"
      >
        <SubscriptionPlanForm
          initial={editItem}
          onCancel={() => setOpen(false)}
          onSaved={() => setOpen(false)}
        />
      </Modal>

      <ConfirmDialog
        open={!!deleteItem}
        title="Delete Plan?"
        description={`"${deleteItem?.name}" will be removed.`}
        confirmLabel="Delete"
        onConfirm={() => deleteItem && deleteMutation.mutate(deleteItem)}
        onCancel={() => setDeleteItem(null)}
        loading={deleteMutation.isPending}
      />
    </div>
  )
}
