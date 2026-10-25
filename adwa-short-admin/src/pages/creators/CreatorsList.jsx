import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Search, Plus, Users, UserCircle, Phone, Eye, HandCoins, TrendingUp, Wallet } from 'lucide-react'
import { useCreators, useDebouncedValue } from '../../lib/hooks'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
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
import { EmptyState } from '../../components/ui/EmptyState'
import { Pagination } from '../../components/ui/Pagination'
import { formatBirr, formatNumber, formatDate, initials } from '../../lib/format'

const PAGE_SIZE = 20

export function CreatorsList() {
  const navigate = useNavigate()
  const [q, setQ] = useState('')
  const debouncedQ = useDebouncedValue(q, 300)
  const [page, setPage] = useState(1)
  const [sortKey, setSortKey] = useState('name')
  const [sortDir, setSortDir] = useState('asc')

  const { data, isLoading, isFetching } = useCreators({
    q: debouncedQ || undefined,
    page,
    sort: sortKey,
    order: sortDir,
  })

  const filtered = (Array.isArray(data) ? data : []).filter((c) => {
    if (!debouncedQ) return true
    const needle = debouncedQ.toLowerCase()
    return (
      (c.name ?? '').toLowerCase().includes(needle) ||
      (c.phone ?? '').toLowerCase().includes(needle) ||
      (c.display_name ?? '').toLowerCase().includes(needle)
    )
  })

  const sorted = filtered.slice().sort((a, b) => {
    const dir = sortDir === 'asc' ? 1 : -1
    const av = a[sortKey] ?? 0
    const bv = b[sortKey] ?? 0
    if (typeof av === 'string' || typeof bv === 'string') {
      return String(av).localeCompare(String(bv)) * dir
    }
    return (Number(av) - Number(bv)) * dir
  })

  const total = sorted.length
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE))

  const toggleSort = (key) => {
    if (sortKey === key) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'))
    } else {
      setSortKey(key)
      setSortDir('asc')
    }
    setPage(1)
  }

  const SortTH = ({ k, children, className = '' }) => {
    const isRight = className.includes('text-right')
    return (
      <TH
        className={`cursor-pointer select-none hover:text-text-primary transition-colors ${className}`}
        onClick={() => toggleSort(k)}
      >
        <span className={`inline-flex items-center gap-1 ${isRight ? 'justify-end w-full' : ''}`}>
          {children}
          <span className="text-[10px] text-text-muted">
            {sortKey === k ? (sortDir === 'asc' ? '▲' : '▼') : '↕'}
          </span>
        </span>
      </TH>
    )
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Creators</h2>
          <p className="text-sm text-text-secondary">
            Manage content creators, splits, and payouts · {total} total
          </p>
        </div>
        <Button leftIcon={<Plus className="h-4 w-4" />} onClick={() => navigate('/creators/new')}>
          Add Creator
        </Button>
      </div>

      <Card padding="md">
        <Input
          placeholder="Search by name or phone…"
          value={q}
          onChange={(e) => {
            setQ(e.target.value)
            setPage(1)
          }}
          leftIcon={<Search className="h-4 w-4" />}
          hint={isFetching && q ? 'Searching…' : undefined}
        />
      </Card>

      <Card padding="none" className="overflow-hidden">
        <Table>
          <THead>
            <TR>
              <SortTH k="name">Creator</SortTH>
              <SortTH k="phone">Phone</SortTH>
              <SortTH k="default_revenue_split_pct" className="text-right">Split</SortTH>
              <SortTH k="content_count" className="text-right">Content</SortTH>
              <SortTH k="total_views" className="text-right">Views</SortTH>
              <SortTH k="gross_revenue" className="text-right">Gross</SortTH>
              <SortTH k="creator_net" className="text-right">Creator Net</SortTH>
              <SortTH k="pending_balance" className="text-right">Pending</SortTH>
              <SortTH k="last_payout_date">Last Payout</SortTH>
              <TH>Status</TH>
            </TR>
          </THead>
          <TBody>
            {isLoading ? (
              <SkeletonRow colSpan={10} rows={6} />
            ) : sorted.length === 0 ? (
              <EmptyRow colSpan={10}>
                <EmptyState
                  icon={Users}
                  title="No creators yet"
                  description="Add your first creator to start tracking content ownership and payouts."
                  action={
                    <Button
                      leftIcon={<Plus className="h-4 w-4" />}
                      onClick={() => navigate('/creators/new')}
                    >
                      Add Creator
                    </Button>
                  }
                />
              </EmptyRow>
            ) : (
              sorted
                .slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)
                .map((c) => (
                  <TR
                    key={c.id}
                    className="cursor-pointer"
                    onClick={() => navigate(`/creators/${c.id}`)}
                  >
                    <TD>
                      <div className="flex items-center gap-3">
                        <div className="flex h-9 w-9 items-center justify-center rounded-full bg-accent-soft text-accent">
                          {c.avatar_url ? (
                            <img
                              src={c.avatar_url}
                              alt=""
                              className="h-full w-full rounded-full object-cover"
                            />
                          ) : (
                            <span className="text-xs font-bold">
                              {initials(c.name, c.phone)}
                            </span>
                          )}
                        </div>
                        <div className="min-w-0">
                          <p className="truncate font-medium">{c.name}</p>
                          <p className="truncate text-[10px] text-text-muted">
                            {c.display_name || c.email || `Creator #${c.id}`}
                          </p>
                        </div>
                      </div>
                    </TD>
                    <TD className="font-mono text-xs">
                      <span className="inline-flex items-center gap-1">
                        <Phone className="h-3 w-3 text-text-muted" />
                        {c.phone || '—'}
                      </span>
                    </TD>
                    <TD className="text-right tabular-nums">
                      <span className="inline-flex items-center gap-1 text-success">
                        {formatNumber(c.default_revenue_split_pct ?? 0)}%
                      </span>
                    </TD>
                    <TD className="text-right tabular-nums">
                      {formatNumber(c.content_count ?? 0)}
                    </TD>
                    <TD className="text-right tabular-nums">
                      <span className="inline-flex items-center gap-1 text-text-secondary">
                        <Eye className="h-3 w-3 text-text-muted" />
                        {formatNumber(c.total_views ?? 0, { compact: true })}
                      </span>
                    </TD>
                    <TD className="text-right tabular-nums">
                      <span className="inline-flex items-center gap-1">
                        <TrendingUp className="h-3 w-3 text-text-muted" />
                        {formatBirr(c.gross_revenue ?? 0, { compact: true })}
                      </span>
                    </TD>
                    <TD className="text-right tabular-nums text-success">
                      <span className="inline-flex items-center gap-1">
                        <Wallet className="h-3 w-3 text-text-muted" />
                        {formatBirr(c.creator_net ?? 0, { compact: true })}
                      </span>
                    </TD>
                    <TD className="text-right tabular-nums font-medium">
                      <span className="inline-flex items-center gap-1">
                        <HandCoins className="h-3 w-3 text-warning" />
                        {formatBirr(c.pending_balance ?? 0, { compact: true })}
                      </span>
                    </TD>
                    <TD className="text-xs text-text-secondary">
                      {c.last_payout_date ? formatDate(c.last_payout_date) : '—'}
                    </TD>
                    <TD>
                      {c.is_active ? (
                        <Badge tone="success">Active</Badge>
                      ) : (
                        <Badge tone="neutral">Inactive</Badge>
                      )}
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

      <div className="flex items-center gap-2 text-xs text-text-muted">
        <UserCircle className="h-3.5 w-3.5" />
        Click a row to view creator details, splits, content, and payouts.
      </div>
    </div>
  )
}
