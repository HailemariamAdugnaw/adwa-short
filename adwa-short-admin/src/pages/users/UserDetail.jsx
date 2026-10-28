import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import {
  ChevronLeft,
  Wallet,
  Smartphone,
  CreditCard,
  History,
  Ban,
  CheckCircle2,
  HandCoins,
  Monitor,
  Tv,
  Phone,
} from 'lucide-react'
import { useUser, useUserWallet, useUserDevices } from '../../lib/hooks'
import { useAuthStore } from '../../lib/store'
import { post, errMsg } from '../../lib/api'
import { Card, CardHeader, CardTitle, CardSection } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Modal } from '../../components/ui/Modal'
import { Input } from '../../components/ui/Input'
import { Textarea } from '../../components/ui/Textarea'
import { Badge } from '../../components/ui/Badge'
import { EmptyState } from '../../components/ui/EmptyState'
import { ConfirmDialog } from '../../components/ui/ConfirmDialog'
import {
  formatBirr,
  formatNumber,
  formatDate,
  formatDateTime,
  formatRelative,
  initials,
} from '../../lib/format'

const deviceIcon = (type) => {
  switch (type) {
    case 'ios':
    case 'android':
      return <Phone className="h-4 w-4" />
    case 'tv':
      return <Tv className="h-4 w-4" />
    default:
      return <Monitor className="h-4 w-4" />
  }
}

export function UserDetail() {
  const { id } = useParams()
  const qc = useQueryClient()
  const authUser = useAuthStore((s) => s.user)
  const adminRole = authUser?.admin_role || (authUser?.role === 'admin' ? 'super_admin' : authUser?.role)
  const isSuperAdmin = adminRole === 'super_admin'

  const { data: user, isLoading } = useUser(id)
  const { data: wallet } = useUserWallet(id)
  const { data: devices } = useUserDevices(id)
  const [depositOpen, setDepositOpen] = useState(false)
  const [banOpen, setBanOpen] = useState(false)
  const [amount, setAmount] = useState('')
  const [coins, setCoins] = useState('')
  const [notes, setNotes] = useState('')

  const banMutation = useMutation({
    mutationFn: async () => post(`/admin/users/${id}/${user?.is_banned ? 'unban' : 'ban'}`),
    onSuccess: () => {
      toast.success(user?.is_banned ? 'User unbanned' : 'User banned')
      qc.invalidateQueries({ queryKey: ['users', id] })
      setBanOpen(false)
    },
    onError: (e) => toast.error(errMsg(e)),
  })

  const depositMutation = useMutation({
    mutationFn: async () =>
      post('/admin/wallet/top-up', {
        user_id: id,
        amount_birr: Number(amount) || 0,
        coins_credited: coins ? Number(coins) : 0,
        notes,
      }),
    onSuccess: () => {
      toast.success('Wallet topped up')
      qc.invalidateQueries({ queryKey: ['users', id] })
      qc.invalidateQueries({ queryKey: ['users', id, 'wallet'] })
      qc.invalidateQueries({ queryKey: ['manual-deposits'] })
      setDepositOpen(false)
      setAmount('')
      setCoins('')
      setNotes('')
    },
    onError: (e) => toast.error(errMsg(e, 'Failed to top up wallet')),
  })

  if (isLoading || !user) {
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

  return (
    <div className="space-y-4">
      <div>
        <Link
          to="/users"
          className="inline-flex items-center gap-1 text-xs text-text-secondary hover:text-text-primary"
        >
          <ChevronLeft className="h-3.5 w-3.5" />
          Back to Users
        </Link>
      </div>

      <Card padding="lg">
        <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
          <div className="flex items-start gap-4">
            <div className="flex h-16 w-16 items-center justify-center rounded-full bg-accent text-xl font-bold text-white">
              {initials(user.display_name, user.phone)}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-xl font-bold text-text-primary">{user.display_name || 'Unnamed user'}</h2>
                {user.is_banned ? (
                  <Badge tone="danger">Banned</Badge>
                ) : (
                  <Badge tone="neutral">Active</Badge>
                )}
              </div>
              <p className="font-mono text-sm text-text-secondary">{user.phone}</p>
              <p className="mt-1 text-[11px] text-text-muted">
                User ID: <span className="font-mono">{user.id}</span>
              </p>
              <p className="text-[11px] text-text-muted">
                Joined {formatDate(user.created_at)} · {formatRelative(user.created_at)}
              </p>
            </div>
          </div>
          <div className="flex gap-2">
            {isSuperAdmin && (
              <Button
                variant="secondary"
                leftIcon={<HandCoins className="h-4 w-4" />}
                onClick={() => setDepositOpen(true)}
              >
                Manual Top-Up
              </Button>
            )}
            <Button
              variant={user.is_banned ? 'success' : 'danger'}
              leftIcon={user.is_banned ? <CheckCircle2 className="h-4 w-4" /> : <Ban className="h-4 w-4" />}
              onClick={() => setBanOpen(true)}
            >
              {user.is_banned ? 'Unban' : 'Ban'}
            </Button>
          </div>
        </div>
      </Card>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card padding="md">
          <CardHeader>
            <div className="flex items-center gap-2">
              <Wallet className="h-4 w-4 text-accent" />
              <CardTitle>Wallet</CardTitle>
            </div>
            {isSuperAdmin && (
              <Button size="sm" variant="ghost" onClick={() => setDepositOpen(true)}>
                Top-Up
              </Button>
            )}
          </CardHeader>
          <CardSection>
            <div className="grid grid-cols-2 gap-3">
              <div className="rounded-md border border-border bg-surface-2/50 p-3">
                <p className="text-[10px] uppercase tracking-wider text-text-muted">Birr Balance</p>
                <p className="mt-1 text-xl font-bold text-text-primary tabular-nums">
                  {formatBirr(wallet?.balance_birr ?? 0)}
                </p>
              </div>
              <div className="rounded-md border border-border bg-surface-2/50 p-3">
                <p className="text-[10px] uppercase tracking-wider text-text-muted">Coin Balance</p>
                <p className="mt-1 text-xl font-bold text-text-primary tabular-nums">
                  {formatNumber(wallet?.balance_coins ?? 0)}
                </p>
              </div>
            </div>
            <div className="mt-3">
              <p className="mb-2 text-[10px] uppercase tracking-wider text-text-muted">
                Recent Transactions
              </p>
              <div className="space-y-1.5 max-h-56 overflow-y-auto">
                {Array.isArray(wallet?.transactions) ? wallet.transactions.slice(0, 8).map((t) => (
                  <div
                    key={t.id}
                    className="flex items-center justify-between rounded border border-border bg-surface-2/30 px-3 py-1.5 text-xs"
                  >
                    <div>
                      <p className="font-medium capitalize text-text-primary">{String(t.type ?? '').replace('_', ' ')}</p>
                      <p className="text-[10px] text-text-muted">{formatDateTime(t.created_at)}</p>
                    </div>
                    <div className="text-right tabular-nums">
                      {t.amount_birr != null && (
                        <p className={t.amount_birr >= 0 ? 'text-success' : 'text-danger'}>
                          {t.amount_birr >= 0 ? '+' : ''}
                          {formatBirr(t.amount_birr)}
                        </p>
                      )}
                      {t.amount_coins != null && (
                        <p className="text-text-secondary">{t.amount_coins} c</p>
                      )}
                    </div>
                  </div>
                )) : null}
                {(!wallet?.transactions || wallet.transactions.length === 0) && (
                  <p className="px-1 py-3 text-center text-xs text-text-muted">No transactions yet</p>
                )}
              </div>
            </div>
          </CardSection>
        </Card>

        <Card padding="md">
          <CardHeader>
            <div className="flex items-center gap-2">
              <Smartphone className="h-4 w-4 text-accent" />
              <CardTitle>Devices ({(devices ?? []).length})</CardTitle>
            </div>
          </CardHeader>
          <div className="space-y-2">
            {(devices ?? []).map((d) => (
              <div
                key={d.id}
                className="flex items-center justify-between rounded border border-border bg-surface-2/30 px-3 py-2"
              >
                <div className="flex items-center gap-2">
                  <span className="flex h-7 w-7 items-center justify-center rounded bg-surface-2 text-text-secondary">
                    {deviceIcon(d.platform)}
                  </span>
                  <div>
                    <p className="text-xs font-medium text-text-primary">{d.device_name ?? '—'}</p>
                    <p className="text-[10px] text-text-muted">
                      {d.platform} · {formatRelative(d.last_seen)}
                    </p>
                  </div>
                </div>
                {d.is_active && <Badge tone="accent">Active</Badge>}
              </div>
            ))}
            {(devices ?? []).length === 0 && (
              <EmptyState icon={Smartphone} title="No devices" description="User has no registered devices." />
            )}
          </div>
        </Card>

        <Card padding="md">
          <CardHeader>
            <div className="flex items-center gap-2">
              <CreditCard className="h-4 w-4 text-accent" />
              <CardTitle>Subscriptions & Passes</CardTitle>
            </div>
          </CardHeader>
          <div className="space-y-2">
            {(user.subscriptions ?? []).map((s) => (
              <div
                key={s.id}
                className="rounded border border-border bg-surface-2/30 px-3 py-2 text-xs"
              >
                <div className="flex items-center justify-between">
                  <span className="font-medium text-text-primary">{s.plan?.name ?? 'Plan'}</span>
                  <Badge tone={s.status === 'active' ? 'success' : 'neutral'}>{s.status}</Badge>
                </div>
                <p className="mt-0.5 text-[10px] text-text-muted">
                  {formatDate(s.started_at ?? s.created_at)} → {formatDate(s.next_billing_at ?? s.expires_at)}
                </p>
              </div>
            ))}
            {(user.passes ?? []).map((p) => (
              <div
                key={p.id}
                className="rounded border border-border bg-surface-2/30 px-3 py-2 text-xs"
              >
                <div className="flex items-center justify-between">
                  <span className="font-medium text-text-primary">{p.pass?.name ?? 'Pass'}</span>
                  <Badge tone={p.is_active ? 'success' : 'neutral'}>{p.is_active ? 'active' : 'expired'}</Badge>
                </div>
                <p className="mt-0.5 text-[10px] text-text-muted">
                  {formatDate(p.starts_at ?? p.created_at)} → {formatDate(p.expires_at)}
                </p>
              </div>
            ))}
            {(!user.subscriptions?.length && !user.passes?.length) && (
              <EmptyState
                icon={CreditCard}
                title="No subscriptions"
                description="User has never subscribed or bought a pass."
              />
            )}
          </div>
        </Card>
      </div>

      <Card padding="md">
        <CardHeader>
          <div className="flex items-center gap-2">
            <History className="h-4 w-4 text-accent" />
            <CardTitle>Recent Watch History</CardTitle>
          </div>
        </CardHeader>
        <div className="space-y-1.5">
          {(user.watch_history ?? []).slice(0, 10).map((w) => (
            <div
              key={w.id}
              className="flex items-center justify-between rounded border border-border bg-surface-2/30 px-3 py-2 text-xs"
            >
              <div className="min-w-0">
                <p className="truncate font-medium text-text-primary">
                  {w.series_title ?? '—'} · Ep {w.episode_number ?? '?'}: {w.episode_title ?? '—'}
                </p>
                <p className="text-[10px] text-text-muted">{formatRelative(w.watched_at)}</p>
              </div>
              <div className="ml-2 flex items-center gap-2">
                <div className="h-1.5 w-16 overflow-hidden rounded-full bg-surface-2">
                  <div className="h-full bg-accent" style={{ width: `${w.progress_percent ?? 0}%` }} />
                </div>
                <span className="w-10 text-right tabular-nums text-text-secondary">
                  {Math.round(w.progress_percent ?? 0)}%
                </span>
              </div>
            </div>
          ))}
          {(!user.watch_history?.length) && (
            <EmptyState icon={History} title="No watch history" description="This user hasn't watched anything yet." />
          )}
        </div>
      </Card>

      <Modal
        open={depositOpen}
        onClose={() => setDepositOpen(false)}
        title="Manual Wallet Top-Up"
        description={`Add Birr/coins to ${user.display_name || user.phone}'s wallet`}
        size="md"
      >
        <div className="space-y-4">
          <Input
            label="Amount (Birr)"
            type="number"
            step="0.01"
            min={0}
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="e.g. 100"
            hint="Credits exact fiat balance without automatically generating 1-to-1 matching coins"
            required
          />
          <Input
            label="Coins to credit (optional)"
            type="number"
            min={0}
            value={coins}
            onChange={(e) => setCoins(e.target.value)}
            placeholder="Leave empty for cash-only top-up"
            hint="Optional: Credit promotional or granted coins (independent of cash balance)"
          />
          <Textarea
            label="Notes"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="e.g. Customer paid cash at office, 2025-10-08"
          />
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setDepositOpen(false)}>
              Cancel
            </Button>
            <Button
              loading={depositMutation.isPending}
              onClick={() => {
                if (!amount || Number(amount) <= 0) {
                  return toast.error('Enter a valid amount')
                }
                depositMutation.mutate()
              }}
            >
              Top-Up Wallet
            </Button>
          </div>
        </div>
      </Modal>

      <ConfirmDialog
        open={banOpen}
        title={user.is_banned ? 'Unban User?' : 'Ban User?'}
        description={
          user.is_banned
            ? `${user.display_name || user.phone} will regain access.`
            : `${user.display_name || user.phone} will be signed out and blocked.`
        }
        confirmLabel={user.is_banned ? 'Unban' : 'Ban'}
        variant={user.is_banned ? 'primary' : 'danger'}
        onConfirm={() => banMutation.mutate()}
        onCancel={() => setBanOpen(false)}
        loading={banMutation.isPending}
      />
    </div>
  )
}
