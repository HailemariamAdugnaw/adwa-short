import { useNavigate } from 'react-router-dom'
import { Download, TrendingUp, Users, AlertCircle, RefreshCw } from 'lucide-react'
import { useRevenueByCreator } from '../../lib/hooks'
import { useQueryClient } from '@tanstack/react-query'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { EmptyState } from '../../components/ui/EmptyState'
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
import { Badge } from '../../components/ui/Badge'
import { formatBirr, initials } from '../../lib/format'

function downloadCsv(rows) {
  if (!rows.length) return
  const headers = [
    'Creator',
    'Gross Revenue',
    'Platform Share',
    'Creator Net',
    'Pending Balance',
  ]
  const lines = [headers.join(',')]
  rows.forEach((r) => {
    lines.push(
      [
        `"${(r.creator_name ?? '').replace(/"/g, '""')}"`,
        r.gross_birr ?? 0,
        r.platform_share_birr ?? 0,
        r.creator_share_birr ?? 0,
        r.pending_balance_birr ?? 0,
      ].join(','),
    )
  })
  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `revenue-by-creator-${new Date().toISOString().slice(0, 10)}.csv`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

export function RevenueByCreator() {
  const navigate = useNavigate()
  const qc = useQueryClient()
  const { data, isLoading, isError } = useRevenueByCreator()
  const items = Array.isArray(data) ? data : []

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Revenue by Creator</h2>
          <p className="text-sm text-text-secondary">
            Per-creator revenue breakdown · {items.length} creators
          </p>
        </div>
        <Button
          variant="secondary"
          leftIcon={<Download className="h-4 w-4" />}
          onClick={() => downloadCsv(items)}
          disabled={!items.length}
        >
          Export CSV
        </Button>
      </div>

      <Card padding="none" className="overflow-hidden">
        <Table>
          <THead>
            <TR>
              <TH>Creator</TH>
              <TH className="text-right">Gross</TH>
              <TH className="text-right">Platform</TH>
              <TH className="text-right">Creator Net</TH>
              <TH className="text-right">Pending</TH>
            </TR>
          </THead>
          <TBody>
            {isLoading ? (
              <SkeletonRow colSpan={5} rows={6} />
            ) : isError ? (
              <EmptyRow colSpan={5}>
                <div className="flex flex-col items-center justify-center gap-3 p-6 text-center">
                  <AlertCircle className="h-6 w-6 text-danger" />
                  <p className="text-sm text-text-secondary">Could not load creator revenue.</p>
                  <Button
                    size="sm"
                    variant="ghost"
                    leftIcon={<RefreshCw className="h-3.5 w-3.5" />}
                    onClick={() => qc.invalidateQueries({ queryKey: ['revenue-by-creator'] })}
                  >
                    Retry
                  </Button>
                </div>
              </EmptyRow>
            ) : items.length === 0 ? (
              <EmptyRow colSpan={5}>
                <EmptyState
                  icon={Users}
                  title="No creator revenue yet"
                  description="Once creators start earning, you'll see per-creator revenue breakdowns here."
                />
              </EmptyRow>
            ) : (
              items.map((c) => (
                <TR
                  key={c.creator_id ?? 'unknown'}
                  className="cursor-pointer"
                  onClick={() => navigate(`/creators/${c.creator_id}`)}
                >
                  <TD>
                    <div className="flex items-center gap-3">
                      <div className="flex h-8 w-8 items-center justify-center rounded-full bg-accent-soft text-accent">
                        <span className="text-[10px] font-bold">
                          {initials(c.creator_name, null)}
                        </span>
                      </div>
                      <div>
                        <p className="font-medium">{c.creator_name ?? '—'}</p>
                        <p className="text-[10px] text-text-muted">
                          Creator #{c.creator_id ?? '—'}
                        </p>
                      </div>
                    </div>
                  </TD>
                  <TD className="text-right tabular-nums font-medium">
                    {formatBirr(c.gross_birr ?? 0)}
                  </TD>
                  <TD className="text-right tabular-nums text-text-secondary">
                    {formatBirr(c.platform_share_birr ?? 0)}
                  </TD>
                  <TD className="text-right tabular-nums text-success">
                    {formatBirr(c.creator_share_birr ?? 0)}
                  </TD>
                  <TD className="text-right tabular-nums">
                    <span className="inline-flex items-center gap-1">
                      {Number(c.pending_balance_birr ?? 0) > 0 ? (
                        <Badge tone="warning">pending</Badge>
                      ) : null}
                      {formatBirr(c.pending_balance_birr ?? 0)}
                    </span>
                  </TD>
                </TR>
              ))
            )}
          </TBody>
        </Table>
      </Card>

      <div className="flex items-center gap-2 text-xs text-text-muted">
        <TrendingUp className="h-3.5 w-3.5" />
        Click a row to drill into the creator's detail page.
      </div>
    </div>
  )
}
