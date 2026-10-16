import { useState } from 'react'
import { TrendingUp, Filter, ArrowUpDown, AlertCircle, RefreshCw } from 'lucide-react'
import { useContentPerformance } from '../../lib/hooks'
import { useQueryClient } from '@tanstack/react-query'
import { Card, CardHeader, CardTitle } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Select } from '../../components/ui/Select'
import { Badge } from '../../components/ui/Badge'
import { EmptyState } from '../../components/ui/EmptyState'
import { BarChartCard } from '../../components/charts/BarChartCard'
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
import { formatNumber, formatPercent } from '../../lib/format'

export function ContentPerformance() {
  const qc = useQueryClient()
  const { data, isLoading, isError } = useContentPerformance()
  const [sortBy, setSortBy] = useState('views')
  const [topN, setTopN] = useState(20)

  const rows = Array.isArray(data?.top_content)
    ? data.top_content.slice().sort((a, b) => (b[sortBy] ?? 0) - (a[sortBy] ?? 0)).slice(0, topN)
    : []

  const chartData = rows.slice(0, 10).map((r) => ({
    name: r.title && r.title.length > 18 ? `${r.title.slice(0, 16)}…` : (r.title ?? ''),
    views: r.views ?? 0,
    watch_hours: r.watch_hours ?? 0,
  }))

  return (
    <div className="space-y-4">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Content Performance</h2>
          <p className="text-sm text-text-secondary">
            How each series is performing across views, ratings, reviews, and watch time.
          </p>
        </div>
      </div>

      <Card padding="md">
        <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
          <Select
            label="Sort By"
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value)}
            options={[
              { value: 'views', label: 'Views' },
              { value: 'likes', label: 'Ratings' },
              { value: 'comments', label: 'Reviews' },
              { value: 'watch_hours', label: 'Watch Hours' },
              { value: 'completion_rate', label: 'Completion Rate' },
            ]}
          />
          <Select
            label="Top N"
            value={String(topN)}
            onChange={(e) => setTopN(Number(e.target.value))}
            options={[
              { value: '10', label: 'Top 10' },
              { value: '20', label: 'Top 20' },
              { value: '50', label: 'Top 50' },
            ]}
          />
          <div className="flex items-end text-xs text-text-secondary">
            <Filter className="mr-1.5 h-3.5 w-3.5" />
            Showing top {rows.length} of {data?.top_content?.length ?? 0}
          </div>
        </div>
      </Card>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <BarChartCard
          title={`Top 10 by ${sortBy.replace('_', ' ')}`}
          data={chartData}
          xKey="name"
          bars={[{ key: sortBy === 'watch_hours' ? 'watch_hours' : 'views', label: sortBy.replace('_', ' ') }]}
          horizontal
          height={400}
          valueFormatter={(v) => formatNumber(v, { compact: true })}
          loading={isLoading}
        />
        <BarChartCard
          title="Watch Hours · Top 10"
          data={chartData}
          xKey="name"
          bars={[{ key: 'watch_hours', label: 'Hours', color: '#10B981' }]}
          horizontal
          height={400}
          valueFormatter={(v) => formatNumber(v, { compact: true })}
          loading={isLoading}
        />
      </div>

      <Card padding="none" className="overflow-hidden">
        <CardHeader className="border-b border-border px-5 py-3">
          <CardTitle>Detailed Breakdown</CardTitle>
        </CardHeader>
        <Table>
          <THead>
            <TR>
              <TH className="w-12 text-center">#</TH>
              <TH>Title</TH>
              <TH className="text-right">
                <span className="inline-flex items-center gap-1">
                  Views <ArrowUpDown className="h-3 w-3" />
                </span>
              </TH>
              <TH className="text-right">Ratings</TH>
              <TH className="text-right">Reviews</TH>
              <TH className="text-right">Watch hrs</TH>
              <TH className="text-right">Completion</TH>
            </TR>
          </THead>
          <TBody>
            {isLoading ? (
              <SkeletonRow colSpan={7} rows={8} />
            ) : isError ? (
              <EmptyRow colSpan={7}>
                <div className="flex flex-col items-center justify-center gap-3 p-6 text-center">
                  <AlertCircle className="h-6 w-6 text-danger" />
                  <p className="text-sm text-text-secondary">Could not load content data.</p>
                  <Button
                    size="sm"
                    variant="ghost"
                    leftIcon={<RefreshCw className="h-3.5 w-3.5" />}
                    onClick={() => qc.invalidateQueries({ queryKey: ['analytics', 'content'] })}
                  >
                    Retry
                  </Button>
                </div>
              </EmptyRow>
            ) : rows.length === 0 ? (
              <EmptyRow colSpan={7}>
                <EmptyState
                  icon={TrendingUp}
                  title="No content data"
                  description="No series performance metrics available yet."
                />
              </EmptyRow>
            ) : (
              rows.map((r, i) => (
                <TR key={r.series_id}>
                  <TD className="text-center font-mono text-text-muted">{i + 1}</TD>
                  <TD className="font-medium">{r.title}</TD>
                  <TD className="text-right tabular-nums">{formatNumber(r.views)}</TD>
                  <TD className="text-right tabular-nums">{formatNumber(r.likes)}</TD>
                  <TD className="text-right tabular-nums">{formatNumber(r.comments)}</TD>
                  <TD className="text-right tabular-nums">{formatNumber(r.watch_hours, { compact: true })}</TD>
                  <TD className="text-right">
                    <Badge tone={r.completion_rate >= 60 ? 'success' : r.completion_rate >= 30 ? 'warning' : 'danger'}>
                      {formatPercent(r.completion_rate)}
                    </Badge>
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
