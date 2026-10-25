import { useState } from 'react'
import { Link } from 'react-router-dom'
import {
  TrendingUp,
  Wallet,
  HandCoins,
  Clock3,
  RefreshCw,
  ArrowUpRight,
  AlertCircle,
  Receipt,
  ShieldCheck,
  Tv,
  Hourglass,
  Percent,
} from 'lucide-react'
import {
  useRevenueOverview,
  useRevenueByCreator,
  useRevenueByMethod,
  useRevenueTransactions,
  useProcessExpiredPasses,
  useAdminPayouts,
} from '../../lib/hooks'
import { useQueryClient } from '@tanstack/react-query'
import { StatCard } from '../../components/ui/StatCard'
import { Card, CardHeader, CardTitle } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Badge } from '../../components/ui/Badge'
import { ConfirmDialog } from '../../components/ui/ConfirmDialog'
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
import { DonutChartCard } from '../../components/charts/DonutChartCard'
import { formatBirr, formatDateTime, formatNumber } from '../../lib/format'

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

export function RevenueOverview() {
  const qc = useQueryClient()
  const { data: overview, isLoading, isError: overviewError } = useRevenueOverview()
  const { data: byMethod, isLoading: loadingMethod, isError: methodError } = useRevenueByMethod()
  const { data: byCreator, isLoading: loadingCreators, isError: creatorsError } = useRevenueByCreator()
  const { data: txData, isLoading: loadingTx, isError: txError } = useRevenueTransactions({ limit: 20 })
  const { data: payoutsData, isLoading: loadingPayouts } = useAdminPayouts({ limit: 10 })
  const processExpired = useProcessExpiredPasses()
  const [confirmExpired, setConfirmExpired] = useState(false)

  const methods = Array.isArray(byMethod) ? byMethod : []
  const creators = Array.isArray(byCreator) ? byCreator : []
  const txs = Array.isArray(txData?.items) ? txData.items : Array.isArray(txData) ? txData : []
  const payoutsList = Array.isArray(payoutsData) ? payoutsData : []

  // Compute Platform Share Breakdown components:
  // 1. Ad Revenue (100% retained)
  const adRevenueMethod = methods.find((m) => m.source_type === 'ad_revenue')
  const adRevenuePlatform = Number(adRevenueMethod?.platform_share_birr ?? 0)

  // 2. Unconsumed Pass / Sub (100% retained)
  const unconsumedPassMethod = methods.find((m) => m.source_type === 'unconsumed_pass')
  const unconsumedSubMethod = methods.find((m) => m.source_type === 'unconsumed_subscription')
  const unconsumedPlatform =
    Number(unconsumedPassMethod?.platform_share_birr ?? 0) +
    Number(unconsumedSubMethod?.platform_share_birr ?? 0)

  // 3. Split Fees from watched content (coins + passes + subs)
  const coinMethod = methods.find((m) => m.source_type === 'coin_payment')
  const passMethod = methods.find((m) => m.source_type === 'pass_consumption')
  const subMethod = methods.find((m) => m.source_type === 'subscription_consumption')
  const splitFeesPlatform =
    Number(coinMethod?.platform_share_birr ?? 0) +
    Number(passMethod?.platform_share_birr ?? 0) +
    Number(subMethod?.platform_share_birr ?? 0)

  const methodDonut = methods.map((m, i) => ({
    name: m.source_type ? m.source_type.replace('_', ' ') : '—',
    value: Number(m.gross_birr ?? 0),
    color: ['#C8102E', '#10B981', '#F59E0B', '#3B82F6', '#8B5CF6', '#A3A3A3'][i % 6],
  }))

  const top5 = creators.slice(0, 5).map((c) => ({
    name: c.creator_name ?? `Creator #${c.creator_id ?? '?'}`,
    revenue: Number(c.gross_birr ?? 0),
  }))

  const totalGross = overview?.total_gross_birr ?? 0
  const totalPlatform = overview?.total_platform_share_birr ?? 0
  const totalCreator = overview?.total_creator_share_birr ?? 0
  const totalPaidOut = overview?.total_paid_out_birr ?? 0
  const totalPending = overview?.total_pending_balance_birr ?? 0

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Revenue &amp; Payout Summary</h2>
          <p className="text-sm text-text-secondary">
            Aggregate revenue generation, platform retention breakdown, and creator payout audit trails.
          </p>
        </div>
        <Button
          variant="secondary"
          leftIcon={<RefreshCw className="h-4 w-4" />}
          onClick={() => setConfirmExpired(true)}
          loading={processExpired.isPending}
        >
          Process Expired Passes
        </Button>
      </div>

      {overviewError && (
        <ErrorCard
          message="Could not load revenue overview."
          onRetry={() => qc.invalidateQueries({ queryKey: ['revenue-overview'] })}
        />
      )}

      {/* KPI Stat Cards */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Gross Revenue Generated"
          value={formatBirr(totalGross, { compact: true })}
          icon={<TrendingUp className="h-5 w-5" />}
          accent
          hint="All coins, passes, subscriptions"
          loading={isLoading}
        />
        <StatCard
          label="Platform Share"
          value={formatBirr(totalPlatform, { compact: true })}
          icon={<Wallet className="h-5 w-5 text-accent" />}
          hint="Split fees + unconsumed + ads"
          loading={isLoading}
        />
        <StatCard
          label="Creator Net Payable"
          value={formatBirr(totalPending, { compact: true })}
          icon={<Clock3 className="h-5 w-5 text-amber-500" />}
          hint="Pending balance owed"
          loading={isLoading}
        />
        <StatCard
          label="Total Settled Payouts"
          value={formatBirr(totalPaidOut, { compact: true })}
          icon={<HandCoins className="h-5 w-5 text-emerald-500" />}
          hint="Processed creator payouts"
          loading={isLoading}
        />
      </div>

      {/* Platform Share Breakdown Details */}
      <Card padding="md">
        <CardHeader className="mb-2">
          <CardTitle className="text-sm font-semibold flex items-center gap-2">
            <ShieldCheck className="h-4 w-4 text-accent" />
            Platform Share Composition &amp; Retention Breakdown
          </CardTitle>
          <span className="text-xs text-text-muted">Total: {formatBirr(totalPlatform)}</span>
        </CardHeader>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
          <div className="rounded-lg border border-border bg-surface-2/40 p-3.5">
            <div className="flex items-center gap-2 text-xs font-semibold text-text-secondary uppercase tracking-wider">
              <Percent className="h-3.5 w-3.5 text-accent" />
              Content Split Fees
            </div>
            <p className="mt-1.5 text-xl font-bold text-text-primary tabular-nums">
              {formatBirr(splitFeesPlatform)}
            </p>
            <p className="text-[11px] text-text-muted mt-0.5">
              Platform share from watched Coin PPV &amp; time consumption
            </p>
          </div>
          <div className="rounded-lg border border-border bg-surface-2/40 p-3.5">
            <div className="flex items-center gap-2 text-xs font-semibold text-text-secondary uppercase tracking-wider">
              <Hourglass className="h-3.5 w-3.5 text-amber-500" />
              Unconsumed Pass Duration
            </div>
            <p className="mt-1.5 text-xl font-bold text-amber-500 tabular-nums">
              {formatBirr(unconsumedPlatform)}
            </p>
            <p className="text-[11px] text-text-muted mt-0.5">
              100% retained by ADWA SHORT for unconsumed pass time
            </p>
          </div>
          <div className="rounded-lg border border-border bg-surface-2/40 p-3.5">
            <div className="flex items-center gap-2 text-xs font-semibold text-text-secondary uppercase tracking-wider">
              <Tv className="h-3.5 w-3.5 text-sky-500" />
              Ad-Supported Viewing
            </div>
            <p className="mt-1.5 text-xl font-bold text-sky-500 tabular-nums">
              {formatBirr(adRevenuePlatform)}
            </p>
            <p className="text-[11px] text-text-muted mt-0.5">
              100% retained by ADWA SHORT (creators earn 0% on ads)
            </p>
          </div>
        </div>
      </Card>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2" padding="md">
          <CardHeader>
            <CardTitle>Creator vs Platform Net Attribution</CardTitle>
            <span className="text-[10px] uppercase tracking-wider text-text-muted">
              {formatNumber(overview?.transaction_count ?? 0)} transactions recorded
            </span>
          </CardHeader>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            <div className="rounded-md border border-border bg-surface-2/40 p-4">
              <p className="text-[10px] uppercase tracking-wider text-text-muted">Gross Generated</p>
              <p className="mt-1 text-2xl font-bold text-text-primary">
                {formatBirr(totalGross, { compact: true })}
              </p>
            </div>
            <div className="rounded-md border border-border bg-surface-2/40 p-4">
              <p className="text-[10px] uppercase tracking-wider text-text-muted">Platform Retained</p>
              <p className="mt-1 text-2xl font-bold text-accent">
                {formatBirr(totalPlatform, { compact: true })}
              </p>
            </div>
            <div className="rounded-md border border-border bg-surface-2/40 p-4">
              <p className="text-[10px] uppercase tracking-wider text-text-muted">Creators Credited</p>
              <p className="mt-1 text-2xl font-bold text-success">
                {formatBirr(totalCreator, { compact: true })}
              </p>
            </div>
          </div>
        </Card>
        <DonutChartCard
          title="Revenue by Consumption Source"
          data={methodDonut}
          valueFormatter={(v) => formatBirr(v, { compact: true })}
          loading={loadingMethod || methodError}
          centerValue={formatBirr(totalGross, { compact: true })}
          centerLabel="Gross"
        />
      </div>

      <Card padding="none" className="overflow-hidden">
          <CardHeader className="border-b border-border px-5 py-3 flex items-center justify-between">
            <CardTitle>Recent Attribution Transactions</CardTitle>
            <Link to="/revenue/transactions">
              <Button
                variant="ghost"
                size="sm"
                rightIcon={<ArrowUpRight className="h-3.5 w-3.5" />}
              >
                View all
              </Button>
            </Link>
          </CardHeader>
          {txError ? (
            <div className="p-5">
              <ErrorCard
                message="Could not load transactions."
                onRetry={() => qc.invalidateQueries({ queryKey: ['revenue-transactions'] })}
              />
            </div>
          ) : (
            <Table>
              <THead>
                <TR>
                  <TH>When</TH>
                  <TH>Source</TH>
                  <TH className="text-right">Gross</TH>
                  <TH className="text-right">Creator Share</TH>
                  <TH className="text-right">Platform Share</TH>
                </TR>
              </THead>
              <TBody>
                {loadingTx ? (
                  <SkeletonRow colSpan={5} rows={6} />
                ) : txs.length === 0 ? (
                  <EmptyRow colSpan={5}>
                    <EmptyState
                      icon={Receipt}
                      title="No transactions yet"
                      description="Revenue transactions will appear here as users watch and unlock content."
                    />
                  </EmptyRow>
                ) : (
                  txs.slice(0, 8).map((t) => (
                    <TR key={t.id}>
                      <TD className="text-xs text-text-secondary">
                        {formatDateTime(t.created_at)}
                      </TD>
                      <TD>
                        <Badge
                          tone={
                            t.source_type === 'unconsumed_pass' || t.source_type === 'unconsumed_subscription'
                              ? 'warning'
                              : t.source_type === 'ad_revenue'
                                ? 'neutral'
                                : 'accent'
                          }
                        >
                          {t.source_type ? t.source_type.replace('_', ' ') : '—'}
                        </Badge>
                      </TD>
                      <TD className="text-right tabular-nums font-medium text-text-primary">
                        +{formatBirr(t.gross_amount_birr ?? 0)}
                      </TD>
                      <TD className="text-right tabular-nums text-success font-medium">
                        {formatBirr(t.creator_share_birr ?? 0)}
                      </TD>
                      <TD className="text-right tabular-nums text-accent font-medium">
                        {formatBirr(t.platform_share_birr ?? 0)}
                      </TD>
                    </TR>
                  ))
                )}
              </TBody>
            </Table>
          )}
        </Card>

      {/* Payout Status Audit Trails Section */}
      <Card padding="none" className="overflow-hidden">
        <CardHeader className="border-b border-border px-5 py-3 flex items-center justify-between">
          <div>
            <CardTitle>Payout Status Audit Trails</CardTitle>
            <p className="text-xs text-text-muted mt-0.5">
              Audit log of creator payouts, disbursement status, and authorized admins.
            </p>
          </div>
        </CardHeader>
        <Table>
          <THead>
            <TR>
              <TH>Requested At</TH>
              <TH>Creator</TH>
              <TH className="text-right">Amount</TH>
              <TH>Status</TH>
              <TH>Reference</TH>
              <TH>Processed By Admin</TH>
              <TH>Notes</TH>
            </TR>
          </THead>
          <TBody>
            {loadingPayouts ? (
              <SkeletonRow colSpan={7} rows={4} />
            ) : payoutsList.length === 0 ? (
              <EmptyRow colSpan={7}>
                <EmptyState
                  icon={HandCoins}
                  title="No payouts on record"
                  description="Payout records and their status transitions will appear here."
                />
              </EmptyRow>
            ) : (
              payoutsList.map((p) => (
                <TR key={p.id}>
                  <TD className="text-xs text-text-secondary">
                    {p.created_at ? formatDateTime(p.created_at) : '—'}
                  </TD>
                  <TD className="font-medium text-text-primary">
                    {p.creator_name || `Creator #${p.creator_id}`}
                  </TD>
                  <TD className="text-right tabular-nums font-medium text-success">
                    {formatBirr(p.amount_birr)}
                  </TD>
                  <TD>
                    <Badge
                      tone={
                        p.status === 'processed'
                          ? 'success'
                          : p.status === 'pending'
                            ? 'warning'
                            : 'danger'
                      }
                    >
                      {p.status}
                    </Badge>
                  </TD>
                  <TD className="font-mono text-xs">{p.reference || '—'}</TD>
                  <TD className="text-xs text-text-secondary">
                    {p.processed_by_admin_id ? `Admin #${p.processed_by_admin_id}` : 'Pending'}
                  </TD>
                  <TD className="text-xs text-text-secondary">{p.notes || '—'}</TD>
                </TR>
              ))
            )}
          </TBody>
        </Table>
      </Card>

      <ConfirmDialog
        open={confirmExpired}
        title="Process Expired Passes?"
        description="This will mark all expired passes as inactive and calculate time-based revenue consumption and unconsumed platform share."
        confirmLabel="Process"
        variant="warning"
        onConfirm={async () => {
          await processExpired.mutateAsync()
          setConfirmExpired(false)
        }}
        onCancel={() => setConfirmExpired(false)}
        loading={processExpired.isPending}
      />
    </div>
  )
}
