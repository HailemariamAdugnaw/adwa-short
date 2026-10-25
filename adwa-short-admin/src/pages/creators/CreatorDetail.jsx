import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import {
  ChevronLeft,
  Phone,
  Mail,
  Building2,
  CreditCard,
  FileText,
  Pencil,
  Scissors,
  HandCoins,
  TrendingUp,
  Eye,
  Wallet,
  Plus,
  Trash2,
} from 'lucide-react'
import { useCreator, useCreatorRevenue, useCreatorContent, useCreatorPayouts } from '../../lib/hooks'
import { Card, CardHeader, CardTitle } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Modal } from '../../components/ui/Modal'
import { Badge } from '../../components/ui/Badge'
import { Tabs } from '../../components/ui/Tabs'
import { StatCard } from '../../components/ui/StatCard'
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
import { EmptyState } from '../../components/ui/EmptyState'
import { AreaChartCard } from '../../components/charts/AreaChartCard'
import { DonutChartCard } from '../../components/charts/DonutChartCard'
import { CreatorForm } from '../../components/content/CreatorForm'
import { PayoutForm } from '../../components/content/PayoutForm'
import {
  formatBirr,
  formatNumber,
  formatPercent,
  formatDate,
  formatDateTime,
  initials,
} from '../../lib/format'

export function CreatorDetail() {
  const { id } = useParams()
  const qc = useQueryClient()
  const { data: creator, isLoading } = useCreator(id)
  const { data: revenue, isLoading: loadingRevenue } = useCreatorRevenue(id)
  const { data: content, isLoading: loadingContent } = useCreatorContent(id)
  const { data: payouts, isLoading: loadingPayouts } = useCreatorPayouts(id)

  const [tab, setTab] = useState('overview')
  const [contentViewMode, setContentViewMode] = useState('series')
  const [revenueViewMode, setRevenueViewMode] = useState('series')
  const [editOpen, setEditOpen] = useState(false)
  const [payoutOpen, setPayoutOpen] = useState(false)

  if (isLoading || !creator) {
    return (
      <div className="space-y-4">
        <div className="skeleton h-6 w-40 rounded" />
        <div className="skeleton h-32 w-full rounded-lg" />
        <div className="grid grid-cols-2 gap-4">
          <div className="skeleton h-64 rounded-lg" />
          <div className="skeleton h-64 rounded-lg" />
        </div>
      </div>
    )
  }

  const rules = Array.isArray(creator.split_rules) ? creator.split_rules : []
  const contentList = Array.isArray(content) ? content : []
  const seriesItems = contentList.filter((item) => item.is_series)
  const episodeItems = contentList.filter((item) => !item.is_series)
  const seriesList = seriesItems
  const monthly = Array.isArray(revenue?.by_month) ? revenue.by_month : []
  const payoutsList = Array.isArray(payouts) ? payouts : []
  const pendingBalance =
    creator.pending_balance_birr ?? revenue?.pending_balance_birr ?? 0
  const grossRevenue = revenue?.gross_amount_birr ?? 0
  const creatorNet = revenue?.creator_net_birr ?? 0
  const totalViews = revenue?.total_views ?? 0
  const platformShare = revenue?.platform_share_birr ?? grossRevenue - creatorNet

  const methodDonut = [
    { name: 'Creator Net', value: Number(creatorNet ?? 0), color: '#10B981' },
    { name: 'Platform', value: Number(platformShare ?? 0), color: '#C8102E' },
  ]

  const tabs = [
    {
      id: 'overview',
      label: 'Overview',
      content: (
        <div className="space-y-4">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <StatCard
              label="Total Views"
              value={formatNumber(totalViews, { compact: true })}
              icon={<Eye className="h-5 w-5" />}
              loading={loadingRevenue}
            />
            <StatCard
              label="Gross Revenue"
              value={formatBirr(grossRevenue, { compact: true })}
              icon={<TrendingUp className="h-5 w-5" />}
              accent
              loading={loadingRevenue}
            />
            <StatCard
              label="Creator Net"
              value={formatBirr(creatorNet, { compact: true })}
              icon={<Wallet className="h-5 w-5" />}
              loading={loadingRevenue}
            />
            <StatCard
              label="Pending Balance"
              value={formatBirr(pendingBalance, { compact: true })}
              icon={<HandCoins className="h-5 w-5" />}
              loading={loadingRevenue}
            />
          </div>
          <AreaChartCard
            title="Monthly Revenue"
            data={monthly}
            xKey="month"
            series={[
              { key: 'gross', label: 'Gross', color: '#C8102E' },
              { key: 'creator_net', label: 'Creator Net', color: '#10B981' },
            ]}
            valueFormatter={(v) => formatBirr(v, { compact: true })}
            loading={loadingRevenue}
          />
          <Card padding="md">
            <CardHeader>
              <CardTitle>Revenue Breakdown</CardTitle>
            </CardHeader>
            <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
              <div className="md:col-span-2">
                <DonutChartCard
                  title="Creator vs Platform"
                  data={methodDonut}
                  valueFormatter={(v) => formatBirr(v, { compact: true })}
                  loading={loadingRevenue}
                  centerValue={formatBirr(grossRevenue, { compact: true })}
                  centerLabel="Gross"
                />
              </div>
              <div className="space-y-2">
                <p className="text-[10px] uppercase tracking-wider text-text-muted">
                  Default Split
                </p>
                <p className="text-2xl font-bold text-text-primary">
                  {formatPercent(creator.default_revenue_split_pct ?? 0, 0)}
                </p>
                <p className="text-[11px] text-text-secondary">creator share</p>
                <div className="mt-3 rounded-md border border-border bg-surface-2/50 p-3 text-xs text-text-secondary">
                  <p className="font-semibold text-text-primary">Platform share</p>
                  <p className="mt-1 text-lg text-accent">
                    {formatPercent(100 - (creator.default_revenue_split_pct ?? 0), 0)}
                  </p>
                </div>
              </div>
            </div>
          </Card>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <Card padding="md">
              <CardHeader>
                <CardTitle className="text-sm font-semibold flex items-center gap-2">
                  <CreditCard className="h-4 w-4 text-accent" />
                  Linked Bank &amp; Payout Account
                </CardTitle>
              </CardHeader>
              <div className="space-y-2.5 text-xs">
                <div className="flex items-center justify-between rounded border border-border bg-surface-2/30 px-3 py-2">
                  <span className="text-text-secondary">Bank / Service</span>
                  <span className="font-medium text-text-primary">{creator.bank_name || 'Not configured'}</span>
                </div>
                <div className="flex items-center justify-between rounded border border-border bg-surface-2/30 px-3 py-2">
                  <span className="text-text-secondary">Account Holder</span>
                  <span className="font-medium text-text-primary">{creator.bank_account_name || '—'}</span>
                </div>
                <div className="flex items-center justify-between rounded border border-border bg-surface-2/30 px-3 py-2">
                  <span className="text-text-secondary">Account Number</span>
                  <span className="font-mono text-text-primary">{creator.bank_account_number || '—'}</span>
                </div>
                <div className="flex items-center justify-between rounded border border-border bg-surface-2/30 px-3 py-2">
                  <span className="text-text-secondary">Payout Method</span>
                  <span className="font-medium capitalize text-text-primary">{creator.payment_method || 'Bank Transfer'}</span>
                </div>
              </div>
            </Card>

            <Card padding="md">
              <CardHeader>
                <CardTitle className="text-sm font-semibold flex items-center gap-2">
                  <FileText className="h-4 w-4 text-accent" />
                  Legal Contract &amp; Custom Split Rules
                </CardTitle>
              </CardHeader>
              <div className="space-y-2.5 text-xs">
                <div className="flex items-center justify-between rounded border border-border bg-surface-2/30 px-3 py-2">
                  <span className="text-text-secondary">Contract Status</span>
                  {creator.legal_contract_url ? (
                    <a
                      href={creator.legal_contract_url}
                      target="_blank"
                      rel="noreferrer"
                      className="font-medium text-accent hover:underline flex items-center gap-1"
                    >
                      View Signed Agreement ({formatDate(creator.contract_signed_date)})
                    </a>
                  ) : (
                    <span className="text-text-muted">No contract on file</span>
                  )}
                </div>
                <div className="flex items-center justify-between rounded border border-border bg-surface-2/30 px-3 py-2">
                  <span className="text-text-secondary">Default Split Ratio</span>
                  <span className="font-semibold text-text-primary">
                    {formatPercent(creator.default_revenue_split_pct ?? 50, 0)} Creator / {formatPercent(100 - (creator.default_revenue_split_pct ?? 50), 0)} Platform
                  </span>
                </div>
                <div className="flex items-center justify-between rounded border border-border bg-surface-2/30 px-3 py-2">
                  <span className="text-text-secondary">Active Split Overrides</span>
                  <span className="font-medium text-text-primary">
                    {rules.length} rule{rules.length === 1 ? '' : 's'} configured
                  </span>
                </div>
                <div className="pt-1">
                  <Button
                    size="sm"
                    variant="secondary"
                    className="w-full text-xs"
                    leftIcon={<Pencil className="h-3.5 w-3.5" />}
                    onClick={() => setEditOpen(true)}
                  >
                    Edit Creator Info &amp; Revenue Split
                  </Button>
                </div>
              </div>
            </Card>
          </div>
        </div>
      ),
    },
    {
      id: 'content',
      label: 'Content',
      content: (
        <Card padding="none" className="overflow-hidden">
          <CardHeader className="border-b border-border px-5 py-3 flex flex-wrap items-center justify-between gap-3">
            <div>
              <CardTitle>Creator Content</CardTitle>
              <p className="text-xs text-text-muted mt-0.5">
                Qualified views (≥1 min) per series and individual episodes.
              </p>
            </div>
            <div className="flex items-center rounded-lg border border-border bg-surface-2 p-0.5 text-xs">
              <button
                type="button"
                className={`rounded-md px-3 py-1.5 font-medium transition-colors ${
                  contentViewMode === 'series'
                    ? 'bg-accent text-white shadow-sm'
                    : 'text-text-secondary hover:text-text-primary'
                }`}
                onClick={() => setContentViewMode('series')}
              >
                Series ({seriesItems.length})
              </button>
              <button
                type="button"
                className={`rounded-md px-3 py-1.5 font-medium transition-colors ${
                  contentViewMode === 'episode'
                    ? 'bg-accent text-white shadow-sm'
                    : 'text-text-secondary hover:text-text-primary'
                }`}
                onClick={() => setContentViewMode('episode')}
              >
                Episodes ({episodeItems.length})
              </button>
            </div>
          </CardHeader>
          <Table>
            {contentViewMode === 'series' ? (
              <>
                <THead>
                  <TR>
                    <TH>Series Name</TH>
                    <TH className="text-center">Total Number of Episodes</TH>
                    <TH className="text-right">View by Coin</TH>
                    <TH className="text-right">View by Time Pass</TH>
                    <TH className="text-right">View by Subscription</TH>
                    <TH className="text-right">View by Ad</TH>
                    <TH className="text-right">Total Number of Views of the Series</TH>
                  </TR>
                </THead>
                <TBody>
                  {loadingContent ? (
                    <SkeletonRow colSpan={7} rows={4} />
                  ) : seriesItems.length === 0 ? (
                    <EmptyRow colSpan={7}>
                      <EmptyState
                        icon={FileText}
                        title="No series assigned"
                        description="This creator has no series assigned yet."
                      />
                    </EmptyRow>
                  ) : (
                    seriesItems.map((item) => (
                      <TR key={`series-${item.series_id}`}>
                        <TD className="font-medium text-text-primary">{item.title}</TD>
                        <TD className="text-center tabular-nums text-text-secondary">
                          {formatNumber(item.episodes_count ?? 0)}
                        </TD>
                        <TD className="text-right tabular-nums font-medium text-amber-400">
                          {formatNumber(item.coin_views ?? 0)}
                        </TD>
                        <TD className="text-right tabular-nums font-medium text-emerald-400">
                          {formatNumber(item.pass_views ?? 0)}
                        </TD>
                        <TD className="text-right tabular-nums font-medium text-purple-400">
                          {formatNumber(item.subscription_views ?? 0)}
                        </TD>
                        <TD className="text-right tabular-nums font-medium text-sky-400">
                          {formatNumber(item.ad_views ?? 0)}
                        </TD>
                        <TD className="text-right tabular-nums font-semibold text-text-primary">
                          {formatNumber(item.total_views ?? item.view_count ?? 0)}
                        </TD>
                      </TR>
                    ))
                  )}
                </TBody>
              </>
            ) : (
              <>
                <THead>
                  <TR>
                    <TH>Episode Title</TH>
                    <TH className="w-24 text-center">Episode Number</TH>
                    <TH>Series It Contained</TH>
                    <TH className="text-right">View by Coin</TH>
                    <TH className="text-right">View by Time Pass</TH>
                    <TH className="text-right">View by Subscription</TH>
                    <TH className="text-right">View by Ad</TH>
                    <TH className="text-right">Total Number of Views of the Episode</TH>
                  </TR>
                </THead>
                <TBody>
                  {loadingContent ? (
                    <SkeletonRow colSpan={8} rows={5} />
                  ) : episodeItems.length === 0 ? (
                    <EmptyRow colSpan={8}>
                      <EmptyState
                        icon={FileText}
                        title="No episodes assigned"
                        description="This creator has no episodes assigned yet."
                      />
                    </EmptyRow>
                  ) : (
                    episodeItems.map((item) => (
                      <TR key={`ep-${item.episode_id}`}>
                        <TD className="font-medium text-text-primary">{item.title}</TD>
                        <TD className="text-center font-mono text-xs">
                          {item.episode_number != null ? `#${item.episode_number}` : '—'}
                        </TD>
                        <TD className="text-text-secondary">{item.series_title || '—'}</TD>
                        <TD className="text-right tabular-nums font-medium text-amber-400">
                          {formatNumber(item.coin_views ?? 0)}
                        </TD>
                        <TD className="text-right tabular-nums font-medium text-emerald-400">
                          {formatNumber(item.pass_views ?? 0)}
                        </TD>
                        <TD className="text-right tabular-nums font-medium text-purple-400">
                          {formatNumber(item.subscription_views ?? 0)}
                        </TD>
                        <TD className="text-right tabular-nums font-medium text-sky-400">
                          {formatNumber(item.ad_views ?? 0)}
                        </TD>
                        <TD className="text-right tabular-nums font-semibold text-text-primary">
                          {formatNumber(item.total_views ?? item.view_count ?? 0)}
                        </TD>
                      </TR>
                    ))
                  )}
                </TBody>
              </>
            )}
          </Table>
        </Card>
      ),
    },
    {
      id: 'revenue',
      label: 'Revenue',
      content: (
        <div className="space-y-4">
          <AreaChartCard
            title="Monthly Revenue Trend"
            data={monthly}
            xKey="month"
            series={[
              { key: 'gross', label: 'Gross', color: '#C8102E' },
              { key: 'creator_net', label: 'Creator Net', color: '#10B981' },
              { key: 'platform', label: 'Platform', color: '#F59E0B' },
            ]}
            valueFormatter={(v) => formatBirr(v, { compact: true })}
            loading={loadingRevenue}
            height={320}
          />
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <DonutChartCard
              title="Creator vs Platform"
              data={methodDonut}
              valueFormatter={(v) => formatBirr(v, { compact: true })}
              loading={loadingRevenue}
              centerValue={formatBirr(grossRevenue, { compact: true })}
              centerLabel="Gross"
            />
            <Card padding="md">
              <CardHeader>
                <CardTitle>Revenue Summary</CardTitle>
              </CardHeader>
              <div className="space-y-2">
                <div className="flex items-center justify-between rounded border border-border bg-surface-2/30 px-3 py-2">
                  <span className="text-xs text-text-secondary">Gross Attributed</span>
                  <span className="text-sm font-semibold tabular-nums">
                    {formatBirr(grossRevenue)}
                  </span>
                </div>
                <div className="flex items-center justify-between rounded border border-border bg-surface-2/30 px-3 py-2">
                  <span className="text-xs text-text-secondary">Creator Net Payable</span>
                  <span className="text-sm font-semibold tabular-nums text-success">
                    {formatBirr(creatorNet)}
                  </span>
                </div>
                <div className="flex items-center justify-between rounded border border-border bg-surface-2/30 px-3 py-2">
                  <span className="text-xs text-text-secondary">Platform Share</span>
                  <span className="text-sm font-semibold tabular-nums text-accent">
                    {formatBirr(platformShare)}
                  </span>
                </div>
                <div className="flex items-center justify-between rounded border border-border bg-surface-2/30 px-3 py-2">
                  <span className="text-xs text-text-secondary">Paid Out</span>
                  <span className="text-sm font-semibold tabular-nums">
                    {formatBirr(revenue?.paid_out_birr ?? 0)}
                  </span>
                </div>
              </div>
            </Card>
          </div>

          <Card padding="none" className="overflow-hidden">
            <CardHeader className="border-b border-border px-5 py-3 flex flex-wrap items-center justify-between gap-3">
              <div>
                <CardTitle>Content Revenue Breakdown</CardTitle>
                <p className="text-xs text-text-muted mt-0.5">
                  Revenue breakdown by content item (Coins, Time Passes, Subscriptions).
                </p>
              </div>
              <div className="flex items-center rounded-lg border border-border bg-surface-2 p-0.5 text-xs">
                <button
                  type="button"
                  className={`rounded-md px-3 py-1.5 font-medium transition-colors ${
                    revenueViewMode === 'series'
                      ? 'bg-accent text-white shadow-sm'
                      : 'text-text-secondary hover:text-text-primary'
                  }`}
                  onClick={() => setRevenueViewMode('series')}
                >
                  Series ({seriesItems.length})
                </button>
                <button
                  type="button"
                  className={`rounded-md px-3 py-1.5 font-medium transition-colors ${
                    revenueViewMode === 'episode'
                      ? 'bg-accent text-white shadow-sm'
                      : 'text-text-secondary hover:text-text-primary'
                  }`}
                  onClick={() => setRevenueViewMode('episode')}
                >
                  Episodes ({episodeItems.length})
                </button>
              </div>
            </CardHeader>
            <Table>
              {revenueViewMode === 'series' ? (
                <>
                  <THead>
                    <TR>
                      <TH>Series Name</TH>
                      <TH className="text-right">Revenue by Coin</TH>
                      <TH className="text-right">Revenue by Time Pass</TH>
                      <TH className="text-right">Revenue by Subscription</TH>
                      <TH className="text-right">Total Revenue</TH>
                    </TR>
                  </THead>
                  <TBody>
                    {loadingContent ? (
                      <SkeletonRow colSpan={5} rows={4} />
                    ) : seriesItems.length === 0 ? (
                      <EmptyRow colSpan={5}>
                        <EmptyState
                          icon={Wallet}
                          title="No series revenue"
                          description="No series revenue transactions found for this creator."
                        />
                      </EmptyRow>
                    ) : (
                      seriesItems.map((item) => (
                        <TR key={`rev-s-${item.series_id}`}>
                          <TD className="font-medium text-text-primary">{item.title}</TD>
                          <TD className="text-right tabular-nums text-amber-400 font-medium">
                            {formatBirr(item.revenue_coins_birr ?? 0)}
                          </TD>
                          <TD className="text-right tabular-nums text-emerald-400 font-medium">
                            {formatBirr(item.revenue_pass_birr ?? 0)}
                          </TD>
                          <TD className="text-right tabular-nums text-purple-400 font-medium">
                            {formatBirr(item.revenue_sub_birr ?? 0)}
                          </TD>
                          <TD className="text-right tabular-nums font-semibold text-success">
                            {formatBirr(item.total_revenue_birr ?? 0)}
                          </TD>
                        </TR>
                      ))
                    )}
                  </TBody>
                </>
              ) : (
                <>
                  <THead>
                    <TR>
                      <TH>Episode Title</TH>
                      <TH className="w-24 text-center">Episode Number</TH>
                      <TH>Series It Contained</TH>
                      <TH className="text-right">Revenue by Coin</TH>
                      <TH className="text-right">Revenue by Time Pass</TH>
                      <TH className="text-right">Revenue by Subscription</TH>
                      <TH className="text-right">Total Revenue</TH>
                    </TR>
                  </THead>
                  <TBody>
                    {loadingContent ? (
                      <SkeletonRow colSpan={7} rows={5} />
                    ) : episodeItems.length === 0 ? (
                      <EmptyRow colSpan={7}>
                        <EmptyState
                          icon={Wallet}
                          title="No episode revenue"
                          description="No episode revenue transactions found for this creator."
                        />
                      </EmptyRow>
                    ) : (
                      episodeItems.map((item) => (
                        <TR key={`rev-ep-${item.episode_id}`}>
                          <TD className="font-medium text-text-primary">{item.title}</TD>
                          <TD className="text-center font-mono text-xs">
                            {item.episode_number != null ? `#${item.episode_number}` : '—'}
                          </TD>
                          <TD className="text-text-secondary">{item.series_title || '—'}</TD>
                          <TD className="text-right tabular-nums text-amber-400 font-medium">
                            {formatBirr(item.revenue_coins_birr ?? 0)}
                          </TD>
                          <TD className="text-right tabular-nums text-emerald-400 font-medium">
                            {formatBirr(item.revenue_pass_birr ?? 0)}
                          </TD>
                          <TD className="text-right tabular-nums text-purple-400 font-medium">
                            {formatBirr(item.revenue_sub_birr ?? 0)}
                          </TD>
                          <TD className="text-right tabular-nums font-semibold text-success">
                            {formatBirr(item.total_revenue_birr ?? 0)}
                          </TD>
                        </TR>
                      ))
                    )}
                  </TBody>
                </>
              )}
            </Table>
          </Card>
        </div>
      ),
    },
    {
      id: 'payouts',
      label: 'Payouts',
      content: (
        <Card padding="none" className="overflow-hidden">
          <CardHeader className="border-b border-border px-5 py-3">
            <CardTitle>Payout History</CardTitle>
            <Button
              size="sm"
              leftIcon={<HandCoins className="h-3.5 w-3.5" />}
              onClick={() => setPayoutOpen(true)}
              disabled={pendingBalance <= 0}
            >
              Process Payout
            </Button>
          </CardHeader>
          <Table>
            <THead>
              <TR>
                <TH>Date</TH>
                <TH className="text-right">Amount</TH>
                <TH>Reference</TH>
                <TH>Status</TH>
                <TH>Notes</TH>
              </TR>
            </THead>
            <TBody>
              {loadingPayouts ? (
                <SkeletonRow colSpan={5} rows={4} />
              ) : payoutsList.length === 0 ? (
                <EmptyRow colSpan={5}>
                  <EmptyState
                    icon={HandCoins}
                    title="No payouts yet"
                    description="Process a payout to settle the creator's pending balance."
                  />
                </EmptyRow>
              ) : (
                payoutsList.map((p) => (
                  <TR key={p.id}>
                    <TD className="text-xs text-text-secondary">
                      {formatDateTime(p.created_at)}
                    </TD>
                    <TD className="text-right tabular-nums font-medium text-success">
                      {formatBirr(p.amount_birr)}
                    </TD>
                    <TD className="font-mono text-xs">{p.reference ?? '—'}</TD>
                    <TD>
                      <Badge tone={p.status === 'processed' ? 'success' : 'warning'}>
                        {p.status ?? 'pending'}
                      </Badge>
                    </TD>
                    <TD className="text-xs text-text-secondary">{p.notes ?? '—'}</TD>
                  </TR>
                ))
              )}
            </TBody>
          </Table>
        </Card>
      ),
    },
  ]

  return (
    <div className="space-y-4">
      <div>
        <Link
          to="/creators"
          className="inline-flex items-center gap-1 text-xs text-text-secondary hover:text-text-primary"
        >
          <ChevronLeft className="h-3.5 w-3.5" />
          Back to Creators
        </Link>
      </div>

      <Card padding="lg">
        <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
          <div className="flex items-start gap-4">
            <div className="flex h-16 w-16 items-center justify-center rounded-full bg-accent text-xl font-bold text-white">
              {creator.avatar_url ? (
                <img
                  src={creator.avatar_url}
                  alt=""
                  className="h-full w-full rounded-full object-cover"
                />
              ) : (
                initials(creator.name, creator.phone)
              )}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-xl font-bold text-text-primary">{creator.name}</h2>
                {creator.is_active ? (
                  <Badge tone="success">Active</Badge>
                ) : (
                  <Badge tone="neutral">Inactive</Badge>
                )}
              </div>
              {creator.display_name && creator.display_name !== creator.name && (
                <p className="text-sm text-text-secondary">{creator.display_name}</p>
              )}
              <div className="mt-2 flex flex-wrap items-center gap-3 text-xs text-text-secondary">
                {creator.phone && (
                  <span className="inline-flex items-center gap-1">
                    <Phone className="h-3.5 w-3.5" /> {creator.phone}
                  </span>
                )}
                {creator.email && (
                  <span className="inline-flex items-center gap-1">
                    <Mail className="h-3.5 w-3.5" /> {creator.email}
                  </span>
                )}
                <span className="inline-flex items-center gap-1">
                  <Building2 className="h-3.5 w-3.5" />{' '}
                  {creator.bank_name || 'No bank on file'}
                </span>
                <span className="inline-flex items-center gap-1">
                  <CreditCard className="h-3.5 w-3.5" />{' '}
                  {creator.bank_account_number
                    ? `••••${String(creator.bank_account_number).slice(-4)}`
                    : '—'}
                </span>
                <span className="inline-flex items-center gap-1">
                  <FileText className="h-3.5 w-3.5" />{' '}
                  {creator.legal_contract_url
                    ? `Signed ${formatDate(creator.contract_signed_date)}`
                    : 'No contract'}
                </span>
              </div>
            </div>
          </div>
          <div className="flex flex-wrap gap-2">
            <Button
              variant="secondary"
              leftIcon={<Pencil className="h-4 w-4" />}
              onClick={() => setEditOpen(true)}
            >
              Edit
            </Button>
            <Button
              variant="primary"
              leftIcon={<HandCoins className="h-4 w-4" />}
              onClick={() => setPayoutOpen(true)}
              disabled={pendingBalance <= 0}
            >
              Process Payout
            </Button>
          </div>
        </div>
      </Card>

      <Tabs items={tabs} value={tab} onChange={setTab} />

      <Modal
        open={editOpen}
        onClose={() => setEditOpen(false)}
        title="Edit Creator"
        size="xl"
      >
        <CreatorForm
          initial={creator}
          onSaved={() => setEditOpen(false)}
          onCancel={() => setEditOpen(false)}
        />
      </Modal>

      <Modal
        open={payoutOpen}
        onClose={() => setPayoutOpen(false)}
        title="Process Payout"
        size="md"
        description={`Settle pending balance of ${formatBirr(pendingBalance)}`}
      >
        <PayoutForm
          creator={creator}
          pendingBalance={pendingBalance}
          onSaved={() => setPayoutOpen(false)}
          onCancel={() => setPayoutOpen(false)}
        />
      </Modal>
    </div>
  )
}
