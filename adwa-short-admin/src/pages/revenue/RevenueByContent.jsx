import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Download, Film, AlertCircle, RefreshCw } from 'lucide-react'
import { useRevenueByContent, useCreators, useSeriesList } from '../../lib/hooks'
import { useQueryClient } from '@tanstack/react-query'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Select } from '../../components/ui/Select'
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
import { formatBirr, truncate } from '../../lib/format'

function downloadCsv(rows) {
  if (!rows.length) return
  const headers = ['Title', 'Series', 'Creator', 'Type', 'Gross', 'Creator Share', 'Platform Share']
  const lines = [headers.join(',')]
  rows.forEach((r) => {
    lines.push(
      [
        `"${(r.title ?? '').replace(/"/g, '""')}"`,
        `"${(r.series_title ?? '').replace(/"/g, '""')}"`,
        `"${(r.creator_name ?? '').replace(/"/g, '""')}"`,
        r.content_type || (r.episode_id ? 'episode' : 'series'),
        r.gross_birr ?? 0,
        r.creator_share_birr ?? 0,
        r.platform_share_birr ?? 0,
      ].join(','),
    )
  })
  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `revenue-by-content-${new Date().toISOString().slice(0, 10)}.csv`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

export function RevenueByContent() {
  const navigate = useNavigate()
  const qc = useQueryClient()
  const [creatorFilter, setCreatorFilter] = useState('')
  const [seriesFilter, setSeriesFilter] = useState('')

  const { data, isLoading, isError } = useRevenueByContent({
    creator_id: creatorFilter || undefined,
    series_id: seriesFilter || undefined,
  })
  const { data: creators } = useCreators()
  const { data: rawSeries } = useSeriesList({ page: 1 })
  const seriesList = Array.isArray(rawSeries) ? rawSeries : (rawSeries?.items ?? [])

  let items = Array.isArray(data) ? data : []
  if (creatorFilter) {
    const cid = Number(creatorFilter)
    items = items.filter((c) => c.creator_id === cid)
  }
  if (seriesFilter) {
    const sid = Number(seriesFilter)
    items = items.filter((c) => c.series_id === sid)
  }

  const hasFilter = !!(creatorFilter || seriesFilter)

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Revenue by Content</h2>
          <p className="text-sm text-text-secondary">
            Per-series / per-episode revenue · {items.length} items
          </p>
        </div>
        <div className="flex items-center gap-2">
          {hasFilter && (
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setCreatorFilter('')
                setSeriesFilter('')
              }}
            >
              Reset Filters
            </Button>
          )}
          <Button
            variant="secondary"
            leftIcon={<Download className="h-4 w-4" />}
            onClick={() => downloadCsv(items)}
            disabled={!items.length}
          >
            Export CSV
          </Button>
        </div>
      </div>

      <Card padding="md">
        <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
          <Select
            label="Filter by Creator"
            value={creatorFilter}
            onChange={(e) => setCreatorFilter(e.target.value)}
          >
            <option value="">All creators</option>
            {(creators ?? []).map((c) => (
              <option key={c.id} value={c.id} className="bg-surface">
                {c.display_name || c.name}
              </option>
            ))}
          </Select>
          <Select
            label="Filter by Series"
            value={seriesFilter}
            onChange={(e) => setSeriesFilter(e.target.value)}
          >
            <option value="">All series</option>
            {seriesList.map((s) => (
              <option key={s.id} value={s.id} className="bg-surface">
                {s.title}
              </option>
            ))}
          </Select>
        </div>
      </Card>

      <Card padding="none" className="overflow-hidden">
        <Table>
          <THead>
            <TR>
              <TH>Content</TH>
              <TH>Creator</TH>
              <TH>Type</TH>
              <TH className="text-right">Gross</TH>
              <TH className="text-right">Creator Share</TH>
              <TH className="text-right">Platform</TH>
            </TR>
          </THead>
          <TBody>
            {isLoading ? (
              <SkeletonRow colSpan={6} rows={6} />
            ) : isError ? (
              <EmptyRow colSpan={6}>
                <div className="flex flex-col items-center justify-center gap-3 p-6 text-center">
                  <AlertCircle className="h-6 w-6 text-danger" />
                  <p className="text-sm text-text-secondary">Could not load content revenue.</p>
                  <Button
                    size="sm"
                    variant="ghost"
                    leftIcon={<RefreshCw className="h-3.5 w-3.5" />}
                    onClick={() => qc.invalidateQueries({ queryKey: ['revenue-by-content'] })}
                  >
                    Retry
                  </Button>
                </div>
              </EmptyRow>
            ) : items.length === 0 ? (
              <EmptyRow colSpan={6}>
                <EmptyState
                  icon={Film}
                  title="No content revenue"
                  description="Revenue will appear here once content starts generating coins, passes, or ad revenue."
                />
              </EmptyRow>
            ) : (
              items.map((c) => (
                <TR
                  key={`${c.series_id ?? 's'}-${c.episode_id ?? 'e'}`}
                  className="cursor-pointer"
                  onClick={() =>
                    c.series_id && navigate(`/content/series/${c.series_id}/edit`)
                  }
                >
                  <TD>
                    <div className="font-medium text-text-primary">{c.title ?? '—'}</div>
                    {c.series_title && c.episode_id && (
                      <div className="text-xs text-text-muted">{c.series_title}</div>
                    )}
                  </TD>
                  <TD className="text-xs text-text-secondary">
                    {c.creator_name || (c.creator_id ? `Creator #${c.creator_id}` : 'Platform')}
                  </TD>
                  <TD>
                    <span className="text-[10px] uppercase tracking-wider text-text-muted">
                      {c.content_type || (c.episode_id ? 'episode' : 'series')}
                    </span>
                  </TD>
                  <TD className="text-right tabular-nums font-medium">
                    {formatBirr(c.gross_birr ?? 0)}
                  </TD>
                  <TD className="text-right tabular-nums text-success">
                    {formatBirr(c.creator_share_birr ?? 0)}
                  </TD>
                  <TD className="text-right tabular-nums text-accent">
                    {formatBirr(c.platform_share_birr ?? 0)}
                  </TD>
                </TR>
              ))
            )}
          </TBody>
        </Table>
      </Card>
    </div>
  )
}
