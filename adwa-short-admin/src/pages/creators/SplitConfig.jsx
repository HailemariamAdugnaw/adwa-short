import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { ChevronLeft, Plus, Pencil, Trash2, Scissors } from 'lucide-react'
import { useCreator, useCreatorContent } from '../../lib/hooks'
import { del, errMsg } from '../../lib/api'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Card, CardHeader, CardTitle } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Modal } from '../../components/ui/Modal'
import { ConfirmDialog } from '../../components/ui/ConfirmDialog'
import {
  Table,
  TBody,
  TD,
  TH,
  THead,
  TR,
  EmptyRow,
} from '../../components/ui/Table'
import { Badge } from '../../components/ui/Badge'
import { EmptyState } from '../../components/ui/EmptyState'
import { SplitRuleForm } from '../../components/content/SplitRuleForm'
import { formatPercent } from '../../lib/format'

export function SplitConfig() {
  const { id } = useParams()
  const qc = useQueryClient()
  const { data: creator, isLoading } = useCreator(id)
  const { data: content } = useCreatorContent(id)
  const [open, setOpen] = useState(false)
  const [editRule, setEditRule] = useState(undefined)
  const [deleteRule, setDeleteRule] = useState(null)

  const seriesList = Array.isArray(content) ? content : []
  const episodeOptions = seriesList.flatMap((s) => s.episodes ?? [])
  const rules = Array.isArray(creator?.split_rules) ? creator.split_rules : []

  const deleteMutation = useMutation({
    mutationFn: async (ruleId) => del(`/creators/${id}/split/${ruleId}`),
    onSuccess: () => {
      toast.success('Split rule deleted')
      qc.invalidateQueries({ queryKey: ['creators', id] })
      setDeleteRule(null)
    },
    onError: (e) => toast.error(errMsg(e, 'Failed to delete rule')),
  })

  if (isLoading || !creator) {
    return (
      <div className="space-y-4">
        <div className="skeleton h-6 w-40 rounded" />
        <div className="skeleton h-72 rounded-lg" />
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <div>
        <Link
          to={`/creators/${id}`}
          className="inline-flex items-center gap-1 text-xs text-text-secondary hover:text-text-primary"
        >
          <ChevronLeft className="h-3.5 w-3.5" />
          Back to {creator.name}
        </Link>
      </div>

      <div>
        <h2 className="text-xl font-bold text-text-primary">Split Configuration</h2>
        <p className="text-sm text-text-secondary">
          {creator.name} · Default split{' '}
          <span className="text-accent">
            {formatPercent(creator.default_revenue_split_pct ?? 0, 0)}
          </span>{' '}
          creator share
        </p>
      </div>

      <Card padding="md">
        <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
          <div className="rounded-md border border-border bg-surface-2/50 p-4">
            <p className="text-[10px] uppercase tracking-wider text-text-muted">
              Default Creator Share
            </p>
            <p className="mt-1 text-2xl font-bold text-text-primary">
              {formatPercent(creator.default_revenue_split_pct ?? 0, 0)}
            </p>
            <p className="mt-1 text-[11px] text-text-secondary">
              Applies to all content without a specific override
            </p>
          </div>
          <div className="rounded-md border border-border bg-surface-2/50 p-4">
            <p className="text-[10px] uppercase tracking-wider text-text-muted">
              Platform Share
            </p>
            <p className="mt-1 text-2xl font-bold text-accent">
              {formatPercent(100 - (creator.default_revenue_split_pct ?? 0), 0)}
            </p>
            <p className="mt-1 text-[11px] text-text-secondary">
              Platform's default cut of gross revenue
            </p>
          </div>
          <div className="rounded-md border border-border bg-surface-2/50 p-4">
            <p className="text-[10px] uppercase tracking-wider text-text-muted">
              Active Overrides
            </p>
            <p className="mt-1 text-2xl font-bold text-text-primary">{rules.length}</p>
            <p className="mt-1 text-[11px] text-text-secondary">
              Per-series or per-episode rules
            </p>
          </div>
        </div>
      </Card>

      <Card padding="none" className="overflow-hidden">
        <CardHeader className="border-b border-border px-5 py-3">
          <CardTitle>Split Rules ({rules.length})</CardTitle>
          <Button
            size="sm"
            leftIcon={<Plus className="h-3.5 w-3.5" />}
            onClick={() => {
              setEditRule(undefined)
              setOpen(true)
            }}
          >
            Add Rule
          </Button>
        </CardHeader>
        <Table>
          <THead>
            <TR>
              <TH>Scope</TH>
              <TH>Target</TH>
              <TH>Label</TH>
              <TH className="text-right">Creator Share</TH>
              <TH className="text-right">Platform Share</TH>
              <TH className="text-right">Actions</TH>
            </TR>
          </THead>
          <TBody>
            {rules.length === 0 ? (
              <EmptyRow colSpan={6}>
                <EmptyState
                  icon={Scissors}
                  title="No overrides"
                  description="Only the creator default is in effect. Add per-series or per-episode overrides as needed."
                  action={
                    <Button
                      size="sm"
                      leftIcon={<Plus className="h-4 w-4" />}
                      onClick={() => {
                        setEditRule(undefined)
                        setOpen(true)
                      }}
                    >
                      Add Rule
                    </Button>
                  }
                />
              </EmptyRow>
            ) : (
              rules.map((r) => {
                const scope = r.episode_id
                  ? 'Episode'
                  : r.series_id
                    ? 'Series'
                    : 'Creator'
                const target = r.episode_id
                  ? `Episode #${r.episode_id}`
                  : r.series_id
                    ? `Series #${r.series_id}`
                    : 'All content'
                return (
                  <TR key={r.id}>
                    <TD>
                      <Badge
                        tone={scope === 'Creator' ? 'neutral' : scope === 'Series' ? 'accent' : 'warning'}
                      >
                        {scope}
                      </Badge>
                    </TD>
                    <TD className="text-text-secondary">{target}</TD>
                    <TD className="text-text-secondary">{r.label ?? '—'}</TD>
                    <TD className="text-right tabular-nums font-medium text-success">
                      {formatPercent(r.creator_share_pct ?? 0, 0)}
                    </TD>
                    <TD className="text-right tabular-nums text-text-secondary">
                      {formatPercent(100 - (r.creator_share_pct ?? 0), 0)}
                    </TD>
                    <TD>
                      <div className="flex items-center justify-end gap-1">
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => {
                            setEditRule(r)
                            setOpen(true)
                          }}
                        >
                          <Pencil className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => setDeleteRule(r)}
                        >
                          <Trash2 className="h-4 w-4 text-danger" />
                        </Button>
                      </div>
                    </TD>
                  </TR>
                )
              })
            )}
          </TBody>
        </Table>
      </Card>

      <Modal
        open={open}
        onClose={() => setOpen(false)}
        title={editRule ? 'Edit Split Rule' : 'Add Split Rule'}
        size="md"
      >
        <SplitRuleForm
          creatorId={id}
          series={seriesList}
          episodes={episodeOptions}
          initial={editRule}
          onSaved={() => setOpen(false)}
          onCancel={() => setOpen(false)}
        />
      </Modal>

      <ConfirmDialog
        open={!!deleteRule}
        title="Delete Split Rule?"
        description="This split override will be removed. The creator default will apply."
        confirmLabel="Delete"
        onConfirm={() => deleteRule && deleteMutation.mutate(deleteRule.id)}
        onCancel={() => setDeleteRule(null)}
        loading={deleteMutation.isPending}
      />
    </div>
  )
}
