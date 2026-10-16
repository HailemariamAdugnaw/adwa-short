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
} from 'lucide-react'
import {
  useRevenueOverview,
  useRevenueByCreator,
  useRevenueByMethod,
  useRevenueTransactions,
  useProcessExpiredPasses,
} from '../../lib/hooks'
import { useQueryClient } from '@tanstack/react-query'
import { StatCard } from '../../components/ui/StatCard'
import { Card, CardHeader, CardTitle } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
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
import { BarChartCard } from '../../components/charts/BarChartCard'
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
  const processExpired = useProcessExpiredPasses()
  const [confirmExpired, setConfirmExpired] = useState(false)

  const methods = Array.isArray(byMethod) ? byMethod : []
  const creators = Array.isArray(byCreator) ? byCreator : []
  const txs = Array.isArray(txData?.items) ? txData.items : Array.isArray(txData) ? txData : []

  const methodDonut = methods.map((m, i) => ({
    name: m.source_type ?? '—',
    value: Number(m.gross_birr ?? 0),
    color: ['#C8102E', '#10B981', '#F59E0B', '#A3A3A3'][i % 4],
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
          <h2 className="text-xl font-bold text-text-primary">Revenue Overview</h2>
          <p className="text-sm text-text-secondary">
            Aggregate platform revenue, creator payouts, and method mix.
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

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Gross Revenue"
          value={formatBirr(totalGross, { compact: true })}
          icon={<TrendingUp className="h-5 w-5" />}
          accent
          loading={isLoading}
        />
        <StatCard
          label="Platform Share"
          value={formatBirr(totalPlatform, { compact: true })}
          icon={<Wallet className="h-5 w-5" />}
          loading={isLoading}
        />
        <StatCard
          label="Total Creator Payouts"
          value={formatBirr(totalPaidOut, { compact: true })}
          icon={<HandCoins className="h-5 w-5" />}
          loading={isLoading}
        />
        <StatCard
          label="Pending Balances"
          value={formatBirr(totalPending, { compact: true })}
          icon={<Clock3 className="h-5 w-5" />}
          loading={isLoading}
        />
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2" padding="md">
          <CardHeader>
            <CardTitle>Creator vs Platform Split</CardTitle>
            <span className="text-[10px] uppercase tracking-wider text-text-muted">
              {formatNumber(overview?.transaction_count ?? 0)} transactions
            </span>
          </CardHeader>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            <div className="rounded-md border border-border bg-surface-2/40 p-4">
              <p className="text-[10px] uppercase tracking-wider text-text-muted">Gross</p>
              <p className="mt-1 text-2xl font-bold text-text-primary">
                {formatBirr(totalGross, { compact: true })}
              </p>
            </div>
            <div className="rounded-md border border-border bg-surface-2/40 p-4">
              <p className="text-[10px] uppercase tracking-wider text-text-muted">Platform</p>
              <p className="mt-1 text-2xl font-bold text-accent">
                {formatBirr(totalPlatform, { compact: true })}
              </p>
            </div>
            <div className="rounded-md border border-border bg-surface-2/40 p-4">
              <p className="text-[10px] uppercase tracking-wider text-text-muted">Creators</p>
              <p className="mt-1 text-2xl font-bold text-success">
                {formatBirr(totalCreator, { compact: true })}
              </p>
            </div>
          </div>
        </Card>
        <DonutChartCard
          title="Revenue by Method"
          data={methodDonut}
          valueFormatter={(v) => formatBirr(v, { compact: true })}
          loading={loadingMethod || methodError}
          centerValue={formatBirr(totalGross, { compact: true })}
          centerLabel="Gross"
        />
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <BarChartCard
          className="lg:col-span-1"
          title="Top 5 Creators by Revenue"
          data={top5}
          xKey="name"
          bars={[{ key: 'revenue', label: 'Gross Revenue', color: '#C8102E' }]}
          horizontal
          valueFormatter={(v) => formatBirr(v, { compact: true })}
          loading={loadingCreators}
          height={320}
        />
        <Card padding="none" className="overflow-hidden lg:col-span-2">
          <CardHeader className="border-b border-border px-5 py-3">
            <CardTitle>Recent Transactions</CardTitle>
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
                  <TH className="text-right">Creator</TH>
                  <TH className="text-right">Platform</TH>
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
                      description="Revenue transactions will appear here as users buy coins, passes, and subscriptions."
                    />
                  </EmptyRow>
                ) : (
                  txs.slice(0, 10).map((t) => (
                    <TR key={t.id}>
                      <TD className="text-xs text-text-secondary">
                        {formatDateTime(t.created_at)}
                      </TD>
                      <TD className="capitalize text-text-secondary">
                        {t.source_type ?? '—'}
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
          )}
        </Card>
      </div>

      {creatorsError && (
        <ErrorCard
          message="Could not load creator revenue."
          onRetry={() => qc.invalidateQueries({ queryKey: ['revenue-by-creator'] })}
        />
      )}

      <ConfirmDialog
        open={confirmExpired}
        title="Process Expired Passes?"
        description="This will mark all expired passes as expired and settle any pending revenue. Run this once per day."
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
