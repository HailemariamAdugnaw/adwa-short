import { Link } from 'react-router-dom'
import {
  Users,
  CreditCard,
  Wallet,
  Eye,
  Film,
  Plus,
  FolderTree,
  HandCoins,
  Coins,
  ArrowUpRight,
  TrendingUp,
  MessageSquare,
  RefreshCw,
  AlertCircle,
} from 'lucide-react'
import {
  useAnalyticsOverview,
  useContentPerformance,
  useRevenueOverview,
  useRevenueByCreator,
  useReviews,
} from '../lib/hooks'
import { StatCard } from '../components/ui/StatCard'
import { Card, CardHeader, CardTitle } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import { AreaChartCard } from '../components/charts/AreaChartCard'
import { DonutChartCard } from '../components/charts/DonutChartCard'
import { Table, TBody, TD, TH, THead, TR, SkeletonRow, EmptyRow } from '../components/ui/Table'
import { EmptyState } from '../components/ui/EmptyState'
import { useQueryClient } from '@tanstack/react-query'
import {
  formatBirr,
  formatNumber,
  formatRelative,
  initials,
  truncate,
} from '../lib/format'

const quickActions = [
  { label: 'Add Series', to: '/content/series/new', icon: Film },
  { label: 'Add Category', to: '/categories', icon: FolderTree },
  { label: 'Manual Deposit', to: '/walkin/manual-deposit', icon: HandCoins },
  { label: 'New Coin Pack', to: '/monetization/coins', icon: Coins },
]

function ErrorCard({ message, onRetry }) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 rounded-lg border border-danger/40 bg-danger-soft/20 p-6 text-center">
      <AlertCircle className="h-6 w-6 text-danger" />
      <p className="text-sm text-text-secondary">{message || 'Failed to load data'}</p>
      <Button size="sm" variant="ghost" leftIcon={<RefreshCw className="h-3.5 w-3.5" />} onClick={onRetry}>
        Retry
      </Button>
    </div>
  )
}

export function Dashboard() {
  const qc = useQueryClient()
  const { data: overview, isLoading: loadingOverview, isError: overviewError, isFetching: refetchingOverview } = useAnalyticsOverview()
  const { data: topContent, isLoading: loadingContent, isError: contentError } = useContentPerformance()
  const { data: revenue, isLoading: loadingRevenue } = useRevenueOverview()
  const { data: byCreator, isLoading: loadingCreators, isError: creatorsError } = useRevenueByCreator()
  const { data: reviewsData, isLoading: loadingReviews, isError: reviewsError } = useReviews({ limit: 5 })

  const top = Array.isArray(topContent?.top_content)
    ? topContent.top_content.slice(0, 6)
    : []

  const creators = Array.isArray(byCreator) ? byCreator : []
  const topCreators = creators
    .slice()
    .sort((a, b) => Number(b.pending_balance_birr ?? 0) - Number(a.pending_balance_birr ?? 0))
    .slice(0, 5)

  const recentReviews = Array.isArray(reviewsData?.items)
    ? reviewsData.items.slice(0, 5)
    : []

  const totalGross = revenue?.total_gross_birr ?? 0

  const retryAll = () => {
    qc.invalidateQueries({ queryKey: ['analytics'] })
    qc.invalidateQueries({ queryKey: ['revenue-overview'] })
    qc.invalidateQueries({ queryKey: ['revenue-by-creator'] })
    qc.invalidateQueries({ queryKey: ['reviews'] })
  }

  return (
    <div className="space-y-6">
      {overviewError && (
        <ErrorCard message="Could not load dashboard overview." onRetry={retryAll} />
      )}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-5">
        <StatCard
          label="Total Users"
          value={formatNumber(overview?.total_users ?? 0)}
          icon={<Users className="h-5 w-5" />}
          hint="all time"
          loading={loadingOverview}
        />
        <StatCard
          label="Active Subscribers"
          value={formatNumber(overview?.active_subscriptions ?? 0)}
          icon={<CreditCard className="h-5 w-5" />}
          loading={loadingOverview}
        />
        <StatCard
          label="Total Deposits"
          value={formatBirr(overview?.total_birr_deposited ?? 0, { compact: true })}
          icon={<Wallet className="h-5 w-5" />}
          hint="Birr deposited"
          accent
          loading={loadingOverview}
        />
        <StatCard
          label="Views · 24h"
          value={formatNumber(overview?.total_views_24h ?? 0, { compact: true })}
          icon={<Eye className="h-5 w-5" />}
          loading={loadingOverview}
        />
        <StatCard
          label="Gross Revenue"
          value={formatBirr(totalGross, { compact: true })}
          icon={<TrendingUp className="h-5 w-5" />}
          hint="lifetime gross"
          loading={loadingRevenue}
        />
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <AreaChartCard
          title="Series Catalog"
          className="lg:col-span-2"
          data={[
            { name: 'Series', count: overview?.total_series ?? 0 },
            { name: 'Episodes', count: overview?.total_episodes ?? 0 },
            { name: 'Shorts', count: overview?.total_shorts ?? 0 },
          ]}
          xKey="name"
          series={[{ key: 'count', label: 'Count' }]}
          valueFormatter={(v) => formatNumber(v)}
          loading={loadingOverview || refetchingOverview}
        />
        <DonutChartCard
          title="Engagement Mix"
          data={[
            { name: 'Views (24h)', value: overview?.total_views_24h ?? 0, color: '#C8102E' },
            { name: 'Ratings', value: overview?.total_ratings ?? 0, color: '#10B981' },
            { name: 'Reviews', value: overview?.total_reviews ?? 0, color: '#F59E0B' },
            { name: 'Coins Spent', value: overview?.total_coins_spent ?? 0, color: '#A3A3A3' },
          ]}
          centerValue={formatNumber(overview?.total_ratings ?? 0, { compact: true })}
          centerLabel="Total Ratings"
          valueFormatter={(v) => formatNumber(v, { compact: true })}
          loading={loadingOverview}
        />
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card padding="none" className="lg:col-span-2 overflow-hidden">
          <div className="flex items-center justify-between px-5 py-4">
            <div className="flex items-center gap-2">
              <TrendingUp className="h-4 w-4 text-accent" />
              <h3 className="text-sm font-semibold uppercase tracking-wide text-text-secondary">
                Top Performing Content
              </h3>
            </div>
            <Link to="/analytics/content">
              <Button variant="ghost" size="sm" rightIcon={<ArrowUpRight className="h-3.5 w-3.5" />}>
                View all
              </Button>
            </Link>
          </div>
          {contentError ? (
            <div className="px-5 pb-5">
              <ErrorCard message="Could not load content performance." onRetry={() => qc.invalidateQueries({ queryKey: ['analytics', 'content'] })} />
            </div>
          ) : (
            <Table>
              <THead>
                <TR>
                  <TH>Title</TH>
                  <TH className="text-right">Views</TH>
                  <TH className="text-right">Ratings</TH>
                  <TH className="text-right">Reviews</TH>
                  <TH className="text-right">Score</TH>
                </TR>
              </THead>
              <TBody>
                {loadingContent ? (
                  <SkeletonRow colSpan={5} rows={5} />
                ) : top.length === 0 ? (
                  <EmptyRow colSpan={5}>
                    <p className="text-sm text-text-secondary">No content performance data yet.</p>
                  </EmptyRow>
                ) : (
                  top.map((row) => (
                    <TR key={row.series_id}>
                      <TD className="font-medium">{row.title}</TD>
                      <TD className="text-right tabular-nums">{formatNumber(row.views)}</TD>
                      <TD className="text-right tabular-nums">{formatNumber(row.likes)}</TD>
                      <TD className="text-right tabular-nums">{formatNumber(row.comments)}</TD>
                      <TD className="text-right tabular-nums">
                        {formatNumber(row.popular_score)}
                      </TD>
                    </TR>
                  ))
                )}
              </TBody>
            </Table>
          )}
        </Card>

        <Card padding="md">
          <CardHeader>
            <CardTitle>Quick Actions</CardTitle>
          </CardHeader>
          <div className="space-y-2">
            {quickActions.map((a) => (
              <Link
                key={a.label}
                to={a.to}
                className="group flex items-center gap-3 rounded-md border border-border bg-surface-2/40 px-4 py-3 transition-all hover:border-accent-border hover:bg-accent-soft"
              >
                <div className="flex h-9 w-9 items-center justify-center rounded-md bg-surface-2 text-accent transition-colors group-hover:bg-accent group-hover:text-white">
                  <a.icon className="h-4 w-4" />
                </div>
                <span className="flex-1 text-sm font-medium text-text-primary">{a.label}</span>
                <Plus className="h-4 w-4 text-text-muted opacity-0 transition-opacity group-hover:opacity-100" />
              </Link>
            ))}
          </div>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card padding="none" className="overflow-hidden lg:col-span-1">
          <CardHeader className="border-b border-border px-5 py-3">
            <div className="flex items-center gap-2">
              <HandCoins className="h-4 w-4 text-accent" />
              <CardTitle>Top Creators by Pending</CardTitle>
            </div>
            <Link to="/revenue/by-creator">
              <Button variant="ghost" size="sm" rightIcon={<ArrowUpRight className="h-3.5 w-3.5" />}>
                All
              </Button>
            </Link>
          </CardHeader>
          <div className="divide-y divide-border">
            {loadingCreators ? (
              Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="px-5 py-3">
                  <div className="skeleton h-8 w-full rounded" />
                </div>
              ))
            ) : creatorsError ? (
              <div className="px-5 py-5">
                <ErrorCard
                  message="Could not load creators."
                  onRetry={() => qc.invalidateQueries({ queryKey: ['revenue-by-creator'] })}
                />
              </div>
            ) : topCreators.length === 0 ? (
              <EmptyState
                icon={Users}
                title="No creators yet"
                description="Add creators and assign content to see pending balances."
              />
            ) : (
              topCreators.map((c) => (
                <Link
                  key={c.creator_id ?? c.id}
                  to={`/creators/${c.creator_id ?? c.id}`}
                  className="flex items-center justify-between gap-3 px-5 py-3 transition-colors hover:bg-surface-2/40"
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <div className="flex h-8 w-8 items-center justify-center rounded-full bg-accent-soft text-accent">
                      <span className="text-[10px] font-bold">
                        {initials(c.creator_name, null)}
                      </span>
                    </div>
                    <div className="min-w-0">
                      <p className="truncate text-sm font-medium text-text-primary">
                        {c.creator_name ?? '—'}
                      </p>
                      <p className="text-[10px] text-text-muted">
                        {c.creator_id ? `Creator #${c.creator_id}` : ''}
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-semibold tabular-nums text-warning">
                      {formatBirr(c.pending_balance_birr ?? 0, { compact: true })}
                    </p>
                    <p className="text-[10px] text-text-muted">pending</p>
                  </div>
                </Link>
              ))
            )}
          </div>
        </Card>

        <Card padding="none" className="overflow-hidden lg:col-span-2">
          <CardHeader className="border-b border-border px-5 py-3">
            <div className="flex items-center gap-2">
              <MessageSquare className="h-4 w-4 text-accent" />
              <CardTitle>Recent Reviews</CardTitle>
            </div>
            <Link to="/reviews">
              <Button variant="ghost" size="sm" rightIcon={<ArrowUpRight className="h-3.5 w-3.5" />}>
                View all
              </Button>
            </Link>
          </CardHeader>
          {reviewsError ? (
            <div className="px-5 py-5">
              <ErrorCard
                message="Could not load reviews."
                onRetry={() => qc.invalidateQueries({ queryKey: ['reviews'] })}
              />
            </div>
          ) : (
            <div className="divide-y divide-border">
              {loadingReviews ? (
                Array.from({ length: 5 }).map((_, i) => (
                  <div key={i} className="px-5 py-3">
                    <div className="skeleton h-8 w-full rounded" />
                  </div>
                ))
              ) : recentReviews.length === 0 ? (
                <EmptyState
                  icon={MessageSquare}
                  title="No reviews yet"
                  description="User-submitted reviews will appear here for quick moderation."
                />
              ) : (
                recentReviews.map((r) => (
                  <div key={r.id} className="flex items-start gap-3 px-5 py-3">
                    <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-surface-2 text-[10px] font-bold text-text-primary">
                      {initials(r.user_display_name, r.user_phone)}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center justify-between gap-2">
                        <p className="truncate text-sm font-medium text-text-primary">
                          {r.user_display_name ?? r.user_phone ?? `User #${r.user_id}`}
                        </p>
                        <p className="text-[10px] text-text-muted">
                          {formatRelative(r.created_at)}
                        </p>
                      </div>
                      <p className="mt-0.5 text-xs text-text-secondary line-clamp-2">
                        {truncate(r.text ?? '', 140) || <span className="text-text-muted">—</span>}
                      </p>
                      <p className="mt-0.5 text-[10px] text-text-muted">
                        Episode #{r.episode_id}
                      </p>
                    </div>
                  </div>
                ))
              )}
            </div>
          )}
        </Card>
      </div>

      <AreaChartCard
        title="Active Access"
        data={[
          { name: 'Subscriptions', count: overview?.active_subscriptions ?? 0 },
          { name: 'Passes', count: overview?.active_passes ?? 0 },
        ]}
        xKey="name"
        series={[
          { key: 'count', label: 'Active', color: '#C8102E' },
        ]}
        valueFormatter={(v) => formatNumber(v, { compact: true })}
        loading={loadingOverview}
        height={240}
      />
    </div>
  )
}
