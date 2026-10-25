import { Link } from 'react-router-dom'
import {
  TrendingUp,
  DollarSign,
  Film,
  ListVideo,
  Clock,
  Eye,
  ArrowUpRight,
  ShieldAlert,
  Wallet,
  Sparkles,
  CheckCircle2,
  AlertCircle,
  HelpCircle,
} from 'lucide-react'
import { useCreatorPortalDashboard } from '../../lib/hooks'
import { formatBirr, formatNumber, formatDuration } from '../../lib/format'
import { Badge } from '../../components/ui/Badge'
import { Button } from '../../components/ui/Button'

export function CreatorDashboard() {
  const { data, isLoading, error } = useCreatorPortalDashboard()

  if (isLoading) {
    return (
      <div className="flex h-96 items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-accent border-t-transparent" />
      </div>
    )
  }

  if (error || !data) {
    return (
      <div className="rounded-lg border border-border bg-surface-1 p-8 text-center">
        <ShieldAlert className="mx-auto h-12 w-12 text-accent" />
        <h2 className="mt-3 text-lg font-bold text-text-primary">Unable to load Creator Studio</h2>
        <p className="mt-1 text-xs text-text-secondary">
          {error?.message || 'Could not fetch your creator dashboard metrics.'}
        </p>
      </div>
    )
  }

  const { creator, earnings, metrics, pending_balance_birr, recent_payouts, monthly_trend } = data

  return (
    <div className="space-y-6">
      {/* Top Hero Banner */}
      <div className="relative overflow-hidden rounded-xl border border-border bg-gradient-to-r from-surface-1 via-surface-2/60 to-surface-1 p-6 lg:p-8">
        <div className="pointer-events-none absolute -right-12 -top-12 h-64 w-64 rounded-full bg-accent/10 blur-3xl" />
        <div className="pointer-events-none absolute -left-12 -bottom-12 h-64 w-64 rounded-full bg-amber-500/10 blur-3xl" />

        <div className="relative flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-4">
            <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-accent to-red-900 text-2xl font-black text-white shadow-lg shadow-accent/20 border border-accent/40">
              {(creator.display_name || creator.name)[0].toUpperCase()}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-2xl font-black tracking-tight text-text-primary">
                  {creator.display_name || creator.name}
                </h1>
                <Badge tone="accent" className="flex items-center gap-1">
                  <Sparkles className="h-3 w-3" /> Verified Creator
                </Badge>
              </div>
              <p className="mt-1 text-xs text-text-secondary">
                Creator ID: <code className="text-text-primary font-mono font-bold">#{creator.id}</code> · Agreed Revenue Split:{' '}
                <span className="font-bold text-amber-400">{creator.default_revenue_split_pct}% Net Share</span>
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2.5">
            <Link to="/creator/content">
              <Button size="sm" variant="secondary" rightIcon={<ArrowUpRight className="h-4 w-4" />}>
                My Content
              </Button>
            </Link>
            <Link to="/creator/financials">
              <Button size="sm" rightIcon={<Wallet className="h-4 w-4" />}>
                Payout Account
              </Button>
            </Link>
          </div>
        </div>
      </div>

      {/* 1. Real-Time Financial Snapshot */}
      <div>
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-sm font-bold uppercase tracking-wider text-text-secondary">
            Earnings Summary
          </h2>
          <span className="text-[11px] text-text-muted">Live Prorated Net Attribution</span>
        </div>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div className="card-surface p-5 border-l-4 border-l-blue-500">
            <div className="flex items-center justify-between text-text-muted">
              <span className="text-xs font-medium">Gross Revenue</span>
              <DollarSign className="h-4 w-4 text-blue-400" />
            </div>
            <p className="mt-2 text-2xl font-black text-text-primary">
              {formatBirr(earnings.gross_revenue_birr)}
            </p>
            <p className="mt-1 text-[11px] text-text-secondary">
              Total volume across coin & pass consumption
            </p>
          </div>

          <div className="card-surface p-5 border-l-4 border-l-amber-500">
            <div className="flex items-center justify-between text-text-muted">
              <span className="text-xs font-medium">Platform Commission</span>
              <TrendingUp className="h-4 w-4 text-amber-400" />
            </div>
            <p className="mt-2 text-2xl font-black text-text-primary">
              {formatBirr(earnings.platform_commission_birr)}
            </p>
            <p className="mt-1 text-[11px] text-text-secondary">
              ADWA SHORT platform infrastructure share
            </p>
          </div>

          <div className="card-surface p-5 border-l-4 border-l-emerald-500 bg-emerald-500/5">
            <div className="flex items-center justify-between text-text-muted">
              <span className="text-xs font-semibold text-emerald-400">Net Payable Balance</span>
              <Wallet className="h-4 w-4 text-emerald-400" />
            </div>
            <p className="mt-2 text-2xl font-black text-emerald-400">
              {formatBirr(pending_balance_birr)}
            </p>
            <div className="mt-1 flex items-center gap-1.5">
              <Badge tone="success" size="sm">Available for Payout</Badge>
            </div>
          </div>

          <div className="card-surface p-5 border-l-4 border-l-purple-500">
            <div className="flex items-center justify-between text-text-muted">
              <span className="text-xs font-medium">Total Paid Out</span>
              <CheckCircle2 className="h-4 w-4 text-purple-400" />
            </div>
            <p className="mt-2 text-2xl font-black text-text-primary">
              {formatBirr(earnings.paid_out_birr)}
            </p>
            <p className="mt-1 text-[11px] text-text-secondary">
              Disbursed via bank transfer & mobile money
            </p>
          </div>
        </div>
      </div>

      {/* 2. Performance Metrics */}
      <div>
        <div className="mb-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <h2 className="text-sm font-bold uppercase tracking-wider text-text-secondary">
              Performance Metrics
            </h2>
            <div className="group relative flex items-center">
              <HelpCircle className="h-3.5 w-3.5 text-text-muted hover:text-text-primary cursor-pointer" />
              <div className="pointer-events-none absolute left-full ml-2 hidden w-64 rounded bg-surface-2 p-2 text-[10px] text-text-secondary shadow-lg group-hover:block z-20 border border-border">
                Views are strictly counted once user watches an episode for at least 1 minute (60 seconds).
              </div>
            </div>
          </div>
          <Badge tone="neutral" size="sm">1-Minute Watch Rule Enforced</Badge>
        </div>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div className="card-surface p-5">
            <div className="flex items-center justify-between text-text-muted">
              <span className="text-xs font-medium">Qualified Views</span>
              <Eye className="h-4 w-4 text-accent" />
            </div>
            <p className="mt-2 text-2xl font-black text-text-primary">
              {formatNumber(metrics.qualified_views)}
            </p>
            <p className="mt-1 text-[11px] text-emerald-400 font-medium">
              ≥ 60s completed watch-time threshold
            </p>
          </div>

          <div className="card-surface p-5">
            <div className="flex items-center justify-between text-text-muted">
              <span className="text-xs font-medium">Watch-Time Duration</span>
              <Clock className="h-4 w-4 text-blue-400" />
            </div>
            <p className="mt-2 text-2xl font-black text-text-primary">
              {metrics.watch_time_hours} <span className="text-sm font-normal text-text-muted">hours</span>
            </p>
            <p className="mt-1 text-[11px] text-text-secondary">
              {formatNumber(metrics.watch_time_seconds)} total seconds consumed
            </p>
          </div>

          <div className="card-surface p-5">
            <div className="flex items-center justify-between text-text-muted">
              <span className="text-xs font-medium">Active Series</span>
              <Film className="h-4 w-4 text-amber-400" />
            </div>
            <p className="mt-2 text-2xl font-black text-text-primary">
              {metrics.series_count}
            </p>
            <p className="mt-1 text-[11px] text-text-secondary">
              Assigned series catalog
            </p>
          </div>

          <div className="card-surface p-5">
            <div className="flex items-center justify-between text-text-muted">
              <span className="text-xs font-medium">Active Episodes</span>
              <ListVideo className="h-4 w-4 text-purple-400" />
            </div>
            <p className="mt-2 text-2xl font-black text-text-primary">
              {metrics.episodes_count}
            </p>
            <p className="mt-1 text-[11px] text-text-secondary">
              Published episode streams
            </p>
          </div>
        </div>
      </div>

      {/* 3. Monthly Trend & Recent Payouts */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* Monthly Trend */}
        <div className="card-surface p-6">
          <div className="mb-4 flex items-center justify-between">
            <h3 className="text-sm font-bold text-text-primary">Monthly Revenue Performance</h3>
            <span className="text-[11px] text-text-muted">Gross vs Creator Net</span>
          </div>

          {monthly_trend && monthly_trend.length > 0 ? (
            <div className="space-y-3">
              {monthly_trend.map((m) => (
                <div key={m.month} className="rounded-lg border border-border bg-surface-2/40 p-3.5">
                  <div className="flex items-center justify-between text-xs font-semibold">
                    <span className="font-mono text-text-primary">{m.month}</span>
                    <span className="text-emerald-400">{formatBirr(m.creator_net)} Net</span>
                  </div>
                  <div className="mt-2 flex items-center justify-between text-[11px] text-text-muted">
                    <span>Gross: {formatBirr(m.gross)}</span>
                    <span>Platform: {formatBirr(m.platform)}</span>
                  </div>
                  <div className="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-surface-3">
                    <div
                      className="h-full bg-emerald-500 rounded-full"
                      style={{
                        width: `${m.gross > 0 ? Math.min(100, (m.creator_net / m.gross) * 100) : 0}%`,
                      }}
                    />
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="flex h-48 flex-col items-center justify-center rounded-lg border border-dashed border-border text-center text-xs text-text-muted">
              <p>No monthly revenue history recorded yet.</p>
              <p className="mt-1 text-[11px]">Earnings will automatically track as viewers consume content.</p>
            </div>
          )}
        </div>

        {/* Payout Status & Recent History */}
        <div className="card-surface p-6">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <h3 className="text-sm font-bold text-text-primary">Payout Status & Timeline</h3>
              <p className="text-[11px] text-text-muted">Processed and pending payouts</p>
            </div>
            <Link to="/creator/financials">
              <Button size="xs" variant="ghost">View Ledger</Button>
            </Link>
          </div>

          {recent_payouts && recent_payouts.length > 0 ? (
            <div className="space-y-2.5">
              {recent_payouts.map((p) => (
                <div
                  key={p.id}
                  className="flex items-center justify-between rounded-lg border border-border bg-surface-2/40 p-3 text-xs"
                >
                  <div className="flex items-center gap-3">
                    <div className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-3 text-text-secondary">
                      <Wallet className="h-4 w-4" />
                    </div>
                    <div>
                      <p className="font-bold text-text-primary">{formatBirr(p.amount_birr)}</p>
                      <p className="text-[10px] text-text-muted">
                        {p.created_at ? new Date(p.created_at).toLocaleDateString() : 'N/A'}
                        {p.reference ? ` · Ref: ${p.reference}` : ''}
                      </p>
                    </div>
                  </div>
                  <Badge
                    tone={
                      p.status === 'processed'
                        ? 'success'
                        : p.status === 'pending'
                        ? 'warning'
                        : 'danger'
                    }
                  >
                    {p.status.toUpperCase()}
                  </Badge>
                </div>
              ))}
            </div>
          ) : (
            <div className="flex h-48 flex-col items-center justify-center rounded-lg border border-dashed border-border text-center text-xs text-text-muted">
              <p>No payout transfers recorded yet.</p>
              <p className="mt-1 text-[11px]">
                Pending balance accumulates until processed by platform administration.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
