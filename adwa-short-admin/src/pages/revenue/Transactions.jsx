import { useState } from 'react'
import { Download, Receipt, Search, AlertCircle, RefreshCw } from 'lucide-react'
import {
  useRevenueTransactions,
  useCreators,
  useDebouncedValue,
} from '../../lib/hooks'
import { useQueryClient } from '@tanstack/react-query'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
import { Select } from '../../components/ui/Select'
import { EmptyState } from '../../components/ui/EmptyState'
import { Pagination } from '../../components/ui/Pagination'
import { Badge } from '../../components/ui/Badge'
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
import { formatBirr, formatDateTime } from '../../lib/format'

const PAGE_SIZE = 20
const SOURCE_TYPES = [
  { value: '', label: 'All sources' },
  { value: 'coin_payment', label: 'Coin payment' },
  { value: 'pass_consumption', label: 'Time pass' },
  { value: 'subscription', label: 'Subscription' },
  { value: 'ad_revenue', label: 'Ad reward' },
  { value: 'deposit', label: 'Deposit' },
]

function downloadCsv(rows, creatorsMap = {}) {
  if (!rows.length) return
  const headers = ['Date', 'Creator', 'Source', 'Gross', 'Creator Share', 'Platform', 'Reference']
  const lines = [headers.join(',')]
  rows.forEach((r) => {
    const creatorLabel =
      r.creator_display_name ||
      r.creator_name ||
      creatorsMap[r.creator_id]?.display_name ||
      creatorsMap[r.creator_id]?.name ||
      (r.creator_id ? `Creator #${r.creator_id}` : 'Platform')
    lines.push(
      [
        r.created_at ?? '',
        `"${creatorLabel.toString().replace(/"/g, '""')}"`,
        r.source_type ?? '',
        r.gross_amount_birr ?? 0,
        r.creator_share_birr ?? 0,
        r.platform_share_birr ?? 0,
        r.reference ?? r.id ?? '',
      ].join(','),
    )
  })
  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `revenue-transactions-${new Date().toISOString().slice(0, 10)}.csv`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

export function Transactions() {
  const qc = useQueryClient()
  const [q, setQ] = useState('')
  const debouncedQ = useDebouncedValue(q, 300)
  const [creatorId, setCreatorId] = useState('')
  const [sourceType, setSourceType] = useState('')
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')
  const [page, setPage] = useState(1)

  const { data: creators } = useCreators()
  const creatorsMap = Object.fromEntries((creators ?? []).map((c) => [c.id, c]))
  const { data, isLoading, isFetching, isError } = useRevenueTransactions({
    q: debouncedQ || undefined,
    creator_id: creatorId || undefined,
    source_type: sourceType || undefined,
    start_date: from || undefined,
    end_date: to || undefined,
    page,
    limit: PAGE_SIZE,
  })

  const items = Array.isArray(data?.items) ? data.items : Array.isArray(data) ? data : []
  const total = data?.total ?? items.length
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE))

  const reset = () => {
    setQ('')
    setCreatorId('')
    setSourceType('')
    setFrom('')
    setTo('')
    setPage(1)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Transactions</h2>
          <p className="text-sm text-text-secondary">
            Full revenue ledger · {total} transactions
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="ghost" onClick={reset}>
            Reset filters
          </Button>
          <Button
            variant="secondary"
            leftIcon={<Download className="h-4 w-4" />}
            onClick={() => downloadCsv(items, creatorsMap)}
            disabled={!items.length}
          >
            Export CSV
          </Button>
        </div>
      </div>

      <Card padding="md">
        <div className="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-5">
          <Input
            placeholder="Search reference…"
            value={q}
            onChange={(e) => {
              setQ(e.target.value)
              setPage(1)
            }}
            leftIcon={<Search className="h-4 w-4" />}
            hint={isFetching && q ? 'Searching…' : undefined}
          />
          <Select
            value={creatorId}
            onChange={(e) => {
              setCreatorId(e.target.value)
              setPage(1)
            }}
          >
            <option value="">All creators</option>
            {(creators ?? []).map((c) => (
              <option key={c.id} value={c.id} className="bg-surface">
                {c.name}
              </option>
            ))}
          </Select>
          <Select
            value={sourceType}
            onChange={(e) => {
              setSourceType(e.target.value)
              setPage(1)
            }}
            options={SOURCE_TYPES}
          />
          <Input
            type="date"
            label="From"
            value={from}
            onChange={(e) => {
              setFrom(e.target.value)
              setPage(1)
            }}
            containerClassName="!block"
          />
          <Input
            type="date"
            label="To"
            value={to}
            onChange={(e) => {
              setTo(e.target.value)
              setPage(1)
            }}
            containerClassName="!block"
          />
        </div>
      </Card>

      <Card padding="none" className="overflow-hidden">
        <Table>
          <THead>
            <TR>
              <TH>Date</TH>
              <TH>Creator</TH>
              <TH>Source</TH>
              <TH>Reference</TH>
              <TH className="text-right">Gross</TH>
              <TH className="text-right">Creator</TH>
              <TH className="text-right">Platform</TH>
            </TR>
          </THead>
          <TBody>
            {isLoading ? (
              <SkeletonRow colSpan={7} rows={8} />
            ) : isError ? (
              <EmptyRow colSpan={7}>
                <div className="flex flex-col items-center justify-center gap-3 p-6 text-center">
                  <AlertCircle className="h-6 w-6 text-danger" />
                  <p className="text-sm text-text-secondary">Could not load transactions.</p>
                  <Button
                    size="sm"
                    variant="ghost"
                    leftIcon={<RefreshCw className="h-3.5 w-3.5" />}
                    onClick={() => qc.invalidateQueries({ queryKey: ['revenue-transactions'] })}
                  >
                    Retry
                  </Button>
                </div>
              </EmptyRow>
            ) : items.length === 0 ? (
              <EmptyRow colSpan={7}>
                <EmptyState
                  icon={Receipt}
                  title="No transactions found"
                  description="Try adjusting your filters or date range."
                />
              </EmptyRow>
            ) : (
              items.map((t) => (
                <TR key={t.id}>
                  <TD className="text-xs text-text-secondary">
                    {formatDateTime(t.created_at)}
                  </TD>
                  <TD className="text-xs font-medium text-text-primary">
                    {t.creator_display_name ||
                      t.creator_name ||
                      creatorsMap[t.creator_id]?.display_name ||
                      creatorsMap[t.creator_id]?.name ||
                      (t.creator_id ? `Creator #${t.creator_id}` : 'Platform')}
                  </TD>
                  <TD>
                    <Badge tone="neutral" className="capitalize">
                      {t.source_type ?? '—'}
                    </Badge>
                  </TD>
                  <TD className="font-mono text-[10px] text-text-muted">
                    {t.reference ?? `#${t.id}`}
                  </TD>
                  <TD className="text-right tabular-nums font-medium text-success">
                    +{formatBirr(t.gross_amount_birr ?? 0)}
                  </TD>
                  <TD className="text-right tabular-nums text-success">
                    {formatBirr(t.creator_share_birr ?? 0)}
                  </TD>
                  <TD className="text-right tabular-nums text-accent">
                    {formatBirr(t.platform_share_birr ?? 0)}
                  </TD>
                </TR>
              ))
            )}
          </TBody>
        </Table>
        {total > PAGE_SIZE && (
          <div className="border-t border-border px-4">
            <Pagination
              page={page}
              pages={totalPages}
              total={total}
              pageSize={PAGE_SIZE}
              onChange={setPage}
            />
          </div>
        )}
      </Card>
    </div>
  )
}
