import { useState } from 'react'
import {
  TrendingUp,
  Filter,
  ArrowUpDown,
  AlertCircle,
  RefreshCw,
  Coins,
  Ticket,
  Tv,
  Clock,
  Eye,
  Film,
  Layers,
  Search,
  X,
} from 'lucide-react'
import { useContentPerformance, useContentEpisodesPerformance } from '../../lib/hooks'
import { useQueryClient } from '@tanstack/react-query'
import { Card, CardHeader, CardTitle } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Select } from '../../components/ui/Select'
import { Input } from '../../components/ui/Input'
import { Badge } from '../../components/ui/Badge'
import { StatCard } from '../../components/ui/StatCard'
import { Tabs } from '../../components/ui/Tabs'
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
import { formatNumber, formatPercent } from '../../lib/format'

export function ContentPerformance() {
  const qc = useQueryClient()
  const { data: seriesData, isLoading: loadingSeries, isError: errorSeries } = useContentPerformance()
  const [viewMode, setViewMode] = useState('series')
  const [selectedSeriesId, setSelectedSeriesId] = useState('')
  const [searchQuery, setSearchQuery] = useState('')
  const {
    data: episodesData,
    isLoading: loadingEpisodes,
    isError: errorEpisodes,
  } = useContentEpisodesPerformance(selectedSeriesId ? Number(selectedSeriesId) : undefined)

  const [sortBy, setSortBy] = useState('qualified_views')
  const [topN, setTopN] = useState(20)

  const seriesRows = Array.isArray(seriesData?.top_content) ? seriesData.top_content : []
  const episodeRows = Array.isArray(episodesData) ? episodesData : []

  // Global KPIs across all series
  const totalQualifiedViews = seriesRows.reduce((acc, r) => acc + (r.qualified_views ?? r.views ?? 0), 0)
  const totalCoinViews = seriesRows.reduce((acc, r) => acc + (r.coin_views ?? 0), 0)
  const totalPassSubViews = seriesRows.reduce(
    (acc, r) => acc + ((r.pass_views ?? 0) + (r.subscription_views ?? 0)),
    0,
  )
  const totalAdViews = seriesRows.reduce((acc, r) => acc + (r.ad_views ?? 0), 0)
  const totalWatchHours = seriesRows.reduce((acc, r) => acc + (r.watch_hours ?? 0), 0)

  // Filter series or episodes dynamically in real time
  let activeRows = viewMode === 'series' ? seriesRows : episodeRows

  if (selectedSeriesId) {
    activeRows = activeRows.filter((r) => String(r.series_id) === String(selectedSeriesId))
  }

  if (searchQuery.trim()) {
    const q = searchQuery.toLowerCase().trim()
    activeRows = activeRows.filter(
      (r) =>
        (r.title ?? '').toLowerCase().includes(q) ||
        (r.series_title ?? '').toLowerCase().includes(q)
    )
  }

  const sortedRows = activeRows
    .slice()
    .sort((a, b) => {
      const valA = a[sortBy] ?? (sortBy === 'views' ? a.qualified_views : 0) ?? 0
      const valB = b[sortBy] ?? (sortBy === 'views' ? b.qualified_views : 0) ?? 0
      return valB - valA
    })
    .slice(0, topN)

  const isLoading = viewMode === 'series' ? loadingSeries : loadingEpisodes
  const isError = viewMode === 'series' ? errorSeries : errorEpisodes

  const hasFilter = !!(selectedSeriesId || searchQuery)

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Content Performance Analytics</h2>
          <p className="text-sm text-text-secondary">
            Qualified views (watched ≥ 1 min), granular monetization breakdown, and watch-time attribution.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant={viewMode === 'series' ? 'primary' : 'secondary'}
            size="sm"
            leftIcon={<Layers className="h-3.5 w-3.5" />}
            onClick={() => setViewMode('series')}
          >
            Series View
          </Button>
          <Button
            variant={viewMode === 'episodes' ? 'primary' : 'secondary'}
            size="sm"
            leftIcon={<Film className="h-3.5 w-3.5" />}
            onClick={() => setViewMode('episodes')}
          >
            Episode Breakdown
          </Button>
        </div>
      </div>

      {/* KPI Stat Cards */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-5">
        <StatCard
          label="Qualified Views (≥1m)"
          value={formatNumber(totalQualifiedViews, { compact: true })}
          icon={<Eye className="h-5 w-5" />}
          accent
          hint="Views < 1 min excluded"
          loading={loadingSeries}
        />
        <StatCard
          label="Coin Views (PPV)"
          value={formatNumber(totalCoinViews, { compact: true })}
          icon={<Coins className="h-5 w-5 text-amber-500" />}
          hint="Paid episode unlocks"
          loading={loadingSeries}
        />
        <StatCard
          label="Pass & Sub Views"
          value={formatNumber(totalPassSubViews, { compact: true })}
          icon={<Ticket className="h-5 w-5 text-emerald-500" />}
          hint="Prorated time attribution"
          loading={loadingSeries}
        />
        <StatCard
          label="Ad-Unlocked Views"
          value={formatNumber(totalAdViews, { compact: true })}
          icon={<Tv className="h-5 w-5 text-sky-500" />}
          hint="100% platform share"
          loading={loadingSeries}
        />
        <StatCard
          label="Total Watch Hours"
          value={formatNumber(totalWatchHours, { compact: true })}
          icon={<Clock className="h-5 w-5 text-rose-500" />}
          hint="Qualified duration"
          loading={loadingSeries}
        />
      </div>

      <Card padding="md">
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Input
            label="Search Content"
            placeholder={viewMode === 'series' ? 'Filter by series title...' : 'Filter by episode or series...'}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            leftIcon={<Search className="h-4 w-4" />}
            rightIcon={
              searchQuery ? (
                <button
                  type="button"
                  onClick={() => setSearchQuery('')}
                  className="text-text-muted hover:text-text-primary"
                >
                  <X className="h-3.5 w-3.5" />
                </button>
              ) : undefined
            }
          />
          <Select
            label="Filter by Series"
            value={selectedSeriesId}
            onChange={(e) => setSelectedSeriesId(e.target.value)}
            options={[
              { value: '', label: 'All Series' },
              ...seriesRows.map((s) => ({ value: String(s.series_id), label: s.title })),
            ]}
          />
          <Select
            label="Sort By"
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value)}
            options={[
              { value: 'qualified_views', label: 'Qualified Views (≥1m)' },
              { value: 'coin_views', label: 'Coin-Unlocked Views' },
              { value: 'pass_views', label: 'Pass/Sub-Attributed Views' },
              { value: 'ad_views', label: 'Ad-Unlocked Views' },
              { value: 'watch_hours', label: 'Watch Hours' },
              { value: 'likes', label: 'Ratings' },
              { value: 'completion_rate', label: 'Completion Rate' },
            ]}
          />
          <div className="flex items-end gap-2">
            <div className="flex-1">
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
            </div>
            {hasFilter && (
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  setSelectedSeriesId('')
                  setSearchQuery('')
                }}
              >
                Clear
              </Button>
            )}
          </div>
        </div>
      </Card>

      <Card padding="none" className="overflow-hidden">
        <CardHeader className="border-b border-border px-5 py-3 flex flex-wrap items-center justify-between gap-2">
          <div>
            <CardTitle>
              {viewMode === 'series' ? 'Series Performance Breakdown' : 'Episode Performance Breakdown'}
              {hasFilter ? ' (Filtered)' : ''}
            </CardTitle>
            <p className="text-xs text-text-muted mt-0.5">
              Only views meeting the 1-minute (60s) threshold count towards views and monetization attribution.
              {hasFilter && (
                <span className="ml-2 font-medium text-accent">
                  Showing {sortedRows.length} of {activeRows.length} {viewMode}
                </span>
              )}
            </p>
          </div>
          <div className="flex items-center gap-2 text-xs">
            <span className="inline-flex items-center gap-1 rounded bg-amber-500/10 px-2 py-0.5 text-amber-500 font-medium">
              Coins
            </span>
            <span className="inline-flex items-center gap-1 rounded bg-emerald-500/10 px-2 py-0.5 text-emerald-500 font-medium">
              Time Pass
            </span>
            <span className="inline-flex items-center gap-1 rounded bg-purple-500/10 px-2 py-0.5 text-purple-400 font-medium">
              Subscription
            </span>
            <span className="inline-flex items-center gap-1 rounded bg-sky-500/10 px-2 py-0.5 text-sky-500 font-medium">
              Ads
            </span>
          </div>
        </CardHeader>
        <Table>
          <THead>
            <TR>
              <TH className="w-12 text-center">#</TH>
              <TH className="min-w-[180px]">{viewMode === 'series' ? 'Series' : 'Episode / Series'}</TH>
              <TH className="min-w-[130px] text-right">
                <span className="inline-flex items-center justify-end gap-1">
                  Qualified Views <ArrowUpDown className="h-3 w-3" />
                </span>
              </TH>
              <TH className="text-right">Coins</TH>
              <TH className="text-right">Time Pass</TH>
              <TH className="text-right">Subscription</TH>
              <TH className="text-right">Ads</TH>
              <TH className="min-w-[120px] text-right">Watch Duration</TH>
              <TH className="text-right">Ratings</TH>
              <TH className="text-right">Reviews</TH>
              <TH className="text-right">Completion</TH>
            </TR>
          </THead>
          <TBody>
            {isLoading ? (
              <SkeletonRow colSpan={11} rows={8} />
            ) : isError ? (
              <EmptyRow colSpan={11}>
                <div className="flex flex-col items-center justify-center gap-3 p-6 text-center">
                  <AlertCircle className="h-6 w-6 text-danger" />
                  <p className="text-sm text-text-secondary">Could not load content data.</p>
                  <Button
                    size="sm"
                    variant="ghost"
                    leftIcon={<RefreshCw className="h-3.5 w-3.5" />}
                    onClick={() => {
                      qc.invalidateQueries({ queryKey: ['analytics', 'content'] })
                      qc.invalidateQueries({ queryKey: ['analytics', 'content', 'episodes'] })
                    }}
                  >
                    Retry
                  </Button>
                </div>
              </EmptyRow>
            ) : sortedRows.length === 0 ? (
              <EmptyRow colSpan={11}>
                <EmptyState
                  icon={TrendingUp}
                  title="No content data"
                  description="No content metrics matching the criteria."
                />
              </EmptyRow>
            ) : (
              sortedRows.map((r, i) => {
                const qViews = r.qualified_views ?? r.views ?? 0
                return (
                  <TR
                    key={r.episode_id ? `ep-${r.episode_id}` : `s-${r.series_id}`}
                    className={viewMode === 'series' ? 'cursor-pointer hover:bg-surface-2/60 transition-colors' : undefined}
                    onClick={() => {
                      if (viewMode === 'series') {
                        setSelectedSeriesId(String(r.series_id))
                        setViewMode('episodes')
                      }
                    }}
                    title={viewMode === 'series' ? 'Click to view episode breakdown' : undefined}
                  >
                    <TD className="text-center font-mono text-text-muted">{i + 1}</TD>
                    <TD>
                      <div className="font-medium text-text-primary">{r.title}</div>
                      {r.series_title && (
                        <div className="text-xs text-text-muted">
                          {r.series_title} · Ep #{r.episode_number}
                        </div>
                      )}
                    </TD>
                    <TD className="text-right tabular-nums">
                      <span className="font-semibold text-text-primary">{formatNumber(qViews)}</span>
                      {r.total_raw_views !== undefined && r.total_raw_views > qViews && (
                        <div className="text-[10px] text-text-muted">
                          {formatNumber(r.total_raw_views)} raw attempts
                        </div>
                      )}
                    </TD>
                    <TD className="text-right tabular-nums font-medium text-amber-400">
                      {formatNumber(r.coin_views ?? 0)}
                    </TD>
                    <TD className="text-right tabular-nums font-medium text-emerald-400">
                      {formatNumber(r.pass_views ?? 0)}
                    </TD>
                    <TD className="text-right tabular-nums font-medium text-purple-400">
                      {formatNumber(r.subscription_views ?? 0)}
                    </TD>
                    <TD className="text-right tabular-nums font-medium text-sky-400">
                      {formatNumber(r.ad_views ?? 0)}
                    </TD>
                    <TD className="text-right tabular-nums">
                      <span className="font-medium">{formatNumber(r.watch_hours ?? 0, { compact: true })} hrs</span>
                      {r.total_watch_seconds !== undefined && (
                        <div className="text-[10px] text-text-muted">
                          {formatNumber(r.total_watch_seconds)}s
                        </div>
                      )}
                    </TD>
                    <TD className="text-right tabular-nums">{formatNumber(r.likes ?? 0)}</TD>
                    <TD className="text-right tabular-nums">{formatNumber(r.comments ?? 0)}</TD>
                    <TD className="text-right">
                      <Badge
                        tone={
                          r.completion_rate >= 60
                            ? 'success'
                            : r.completion_rate >= 30
                              ? 'warning'
                              : 'danger'
                        }
                      >
                        {formatPercent(r.completion_rate ?? 0)}
                      </Badge>
                    </TD>
                  </TR>
                )
              })
            )}
          </TBody>
        </Table>
      </Card>
    </div>
  )
}
