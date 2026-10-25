import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import {
  Search,
  HandCoins,
  Printer,
  CheckCircle2,
  Receipt,
  User as UserIcon,
  Wallet,
} from 'lucide-react'
import { useUsers, useManualDeposits, useSettings } from '../../lib/hooks'
import { post, errMsg } from '../../lib/api'
import { Card, CardHeader, CardTitle } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
import { Textarea } from '../../components/ui/Textarea'
import { Badge } from '../../components/ui/Badge'
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
import { formatBirr, formatNumber, formatDateTime, initials } from '../../lib/format'

export function ManualDeposit() {
  const qc = useQueryClient()
  const [query, setQuery] = useState('')
  const [searched, setSearched] = useState(false)
  const [selected, setSelected] = useState(null)
  const [amount, setAmount] = useState('')
  const [notes, setNotes] = useState('')
  const [page] = useState(1)
  const [receipt, setReceipt] = useState(null)

  const { data: settings } = useSettings()
  const settingsArr = Array.isArray(settings) ? settings : []
  const coinPrice = Number(settingsArr.find((s) => s.key === 'coin_price_birr')?.value ?? 1) || 1

  const { data: usersResult, isFetching } = useUsers({
    q: searched ? query : undefined,
    page: 1,
  })
  const usersArr = Array.isArray(usersResult) ? usersResult : []

  const { data: deposits, isLoading: loadingDeposits } = useManualDeposits(page)

  const depositMutation = useMutation({
    mutationFn: async () => {
      const amountNum = Number(amount)
      if (!selected) throw new Error('Select a user first')
      if (!amountNum || amountNum <= 0) throw new Error('Enter a valid amount')
      const coinsCredited = Math.floor(amountNum / coinPrice)
      return post('/admin/wallet/manual-deposit', {
        user_id: selected.id,
        amount_birr: amountNum,
        coins_credited: coinsCredited,
        notes,
      })
    },
    onSuccess: (data) => {
      const amountNum = Number(amount)
      const coinsCredited = Math.floor(amountNum / coinPrice)
      toast.success('Wallet topped up successfully')
      setReceipt({
        user: selected,
        amount: amountNum,
        coins: coinsCredited,
        reference: data.id,
        timestamp: data.created_at,
      })
      qc.invalidateQueries({ queryKey: ['manual-deposits'] })
      qc.invalidateQueries({ queryKey: ['users', selected.id] })
      setSelected(null)
      setAmount('')
      setNotes('')
    },
    onError: (e) => toast.error(errMsg(e, 'Failed to process deposit')),
  })

  const onSearch = () => {
    if (!query.trim()) return toast.error('Enter a phone, name, or User ID')
    setSearched(true)
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3">
        <div className="flex h-11 w-11 items-center justify-center rounded-md bg-accent shadow-[0_0_24px_-6px_rgba(200,16,46,0.8)]">
          <HandCoins className="h-6 w-6 text-white" />
        </div>
        <div>
          <h2 className="text-xl font-bold text-text-primary">Walk-in Center · Manual Deposit</h2>
          <p className="text-sm text-text-secondary">
            Top up a user's wallet with cash received at the office.
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="lg:col-span-2 space-y-4">
          <Card padding="lg">
            <div className="mb-3 flex items-center gap-2">
              <span className="flex h-6 w-6 items-center justify-center rounded-full bg-accent text-xs font-bold text-white">
                1
              </span>
              <h3 className="text-sm font-semibold uppercase tracking-wide text-text-secondary">
                Find the User
              </h3>
            </div>
            <div className="flex gap-2">
              <Input
                placeholder="Phone, name, or User ID…"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && onSearch()}
                leftIcon={<Search className="h-4 w-4" />}
              />
              <Button onClick={onSearch} loading={isFetching}>
                Search
              </Button>
            </div>

            {searched && (
              <div className="mt-3 max-h-72 space-y-2 overflow-y-auto">
                {usersArr.length === 0 ? (
                  <p className="rounded border border-border bg-surface-2/40 px-3 py-4 text-center text-xs text-text-muted">
                    No users found for "{query}"
                  </p>
                ) : (
                  usersArr.slice(0, 8).map((u) => (
                    <button
                      key={u.id}
                      onClick={() => setSelected(u)}
                      className={`flex w-full items-center justify-between rounded border px-3 py-2 text-left transition-colors ${
                        selected?.id === u.id
                          ? 'border-accent-border bg-accent-soft'
                          : 'border-border bg-surface-2/40 hover:bg-surface-2'
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <div className="flex h-9 w-9 items-center justify-center rounded-full bg-surface-2 text-xs font-bold text-text-primary">
                          {initials(u.display_name, u.phone)}
                        </div>
                        <div>
                          <p className="text-sm font-medium text-text-primary">{u.display_name || 'Unnamed'}</p>
                          <p className="text-[11px] font-mono text-text-muted">{u.phone}</p>
                        </div>
                      </div>
                      <div className="text-right">
                        <p className="text-xs tabular-nums text-text-primary">
                          User #{u.id}
                        </p>
                        <p className="text-[10px] text-text-muted">
                          {u.phone}
                        </p>
                      </div>
                    </button>
                  ))
                )}
              </div>
            )}
          </Card>

          <Card padding="lg">
            <div className="mb-3 flex items-center gap-2">
              <span
                className={`flex h-6 w-6 items-center justify-center rounded-full text-xs font-bold ${
                  selected ? 'bg-accent text-white' : 'bg-surface-2 text-text-muted'
                }`}
              >
                2
              </span>
              <h3 className="text-sm font-semibold uppercase tracking-wide text-text-secondary">
                Enter Cash Amount
              </h3>
            </div>

            {!selected ? (
              <EmptyState
                icon={UserIcon}
                title="Select a user above"
                description="Once a user is selected, you can enter the cash amount and complete the top-up."
              />
            ) : (
              <div className="space-y-4">
                <div className="flex items-center justify-between rounded-md border border-accent-border bg-accent-soft px-4 py-3">
                  <div className="flex items-center gap-3">
                    <div className="flex h-9 w-9 items-center justify-center rounded-full bg-accent text-xs font-bold text-white">
                      {initials(selected.display_name, selected.phone)}
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-text-primary">{selected.display_name || 'Unnamed'}</p>
                      <p className="text-[11px] font-mono text-text-muted">{selected.phone}</p>
                    </div>
                  </div>
                  <Badge tone="neutral">
                    <Wallet className="h-3 w-3" />
                    User #{selected.id}
                  </Badge>
                </div>

                <Input
                  label="Cash Received (Birr)"
                  type="number"
                  step="0.01"
                  min={0}
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="e.g. 100"
                  hint={`Auto-suggest: ${amount && Number(amount) > 0 ? Math.floor(Number(amount) / coinPrice) : 0} coins (1 coin = ${formatBirr(coinPrice)})`}
                />

                <Textarea
                  label="Notes (optional)"
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="e.g. Customer paid cash at office, 2025-10-08 · receipt #1234"
                />

                <Button
                  fullWidth
                  size="lg"
                  loading={depositMutation.isPending}
                  leftIcon={<HandCoins className="h-5 w-5" />}
                  onClick={() => depositMutation.mutate()}
                >
                  Top-Up Wallet
                </Button>
              </div>
            )}
          </Card>
        </div>

        <Card padding="md" className="self-start">
          <CardHeader>
            <CardTitle>Walk-in Workflow</CardTitle>
          </CardHeader>
          <ol className="space-y-3 text-xs text-text-secondary">
            <li className="flex gap-2">
              <span className="flex h-5 w-5 flex-shrink-0 items-center justify-center rounded-full bg-surface-2 text-[10px] font-bold text-accent">1</span>
              <span>Search the user by phone, name, or ID</span>
            </li>
            <li className="flex gap-2">
              <span className="flex h-5 w-5 flex-shrink-0 items-center justify-center rounded-full bg-surface-2 text-[10px] font-bold text-accent">2</span>
              <span>Verify the user's current wallet balance</span>
            </li>
            <li className="flex gap-2">
              <span className="flex h-5 w-5 flex-shrink-0 items-center justify-center rounded-full bg-surface-2 text-[10px] font-bold text-accent">3</span>
              <span>Enter the cash received (in Birr)</span>
            </li>
            <li className="flex gap-2">
              <span className="flex h-5 w-5 flex-shrink-0 items-center justify-center rounded-full bg-surface-2 text-[10px] font-bold text-accent">4</span>
              <span>Coins auto-calculated from the coin price setting</span>
            </li>
            <li className="flex gap-2">
              <span className="flex h-5 w-5 flex-shrink-0 items-center justify-center rounded-full bg-surface-2 text-[10px] font-bold text-accent">5</span>
              <span>Click <span className="text-accent">Top-Up Wallet</span> — receipt prints on success</span>
            </li>
          </ol>
          <div className="mt-4 rounded-md border border-border bg-surface-2/40 p-3 text-[11px] text-text-secondary">
            <p className="font-semibold text-text-primary">Coin price</p>
            <p className="mt-1">
              Currently set to <span className="text-accent">{formatBirr(coinPrice)}</span> per coin.
              Change this in <span className="text-text-primary">Settings → Pricing</span>.
            </p>
          </div>
        </Card>
      </div>

      <Card padding="none" className="overflow-hidden">
        <CardHeader className="border-b border-border px-5 py-4">
          <CardTitle>Recent Manual Deposits</CardTitle>
        </CardHeader>
        <Table>
          <THead>
            <TR>
              <TH>User</TH>
              <TH className="text-right">Amount</TH>
              <TH className="text-right">Coins</TH>
              <TH>Admin</TH>
              <TH>When</TH>
              <TH>Notes</TH>
            </TR>
          </THead>
          <TBody>
            {loadingDeposits ? (
              <SkeletonRow colSpan={6} rows={5} />
            ) : (Array.isArray(deposits) ? deposits : []).length === 0 ? (
              <EmptyRow colSpan={6}>
                <EmptyState
                  icon={Receipt}
                  title="No deposits yet"
                  description="Manual deposits will appear here once processed."
                />
              </EmptyRow>
            ) : (
              (Array.isArray(deposits) ? deposits : []).map((d) => (
                <TR key={d.id}>
                  <TD>
                    <p className="font-medium text-text-primary">
                      {d.user_display_name ?? d.user?.display_name ?? (d.user_phone ? d.user_phone : `User #${d.user_id}`)}
                    </p>
                    <p className="font-mono text-[10px] text-text-muted">
                      {d.user_phone ? `${d.user_phone} · ` : ''}User #{d.user_id ?? '—'}
                    </p>
                  </TD>
                  <TD className="text-right tabular-nums font-medium text-success">
                    +{formatBirr(d.amount_birr)}
                  </TD>
                  <TD className="text-right tabular-nums text-text-secondary">
                    +{formatNumber(d.coins_credited)}
                  </TD>
                  <TD className="text-xs text-text-secondary">Admin #{d.admin_id ?? '—'}</TD>
                  <TD className="text-xs text-text-muted">{formatDateTime(d.created_at)}</TD>
                  <TD className="text-xs text-text-secondary">{d.notes ?? '—'}</TD>
                </TR>
              ))
            )}
          </TBody>
        </Table>
      </Card>

      {receipt && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4 animate-fade-in"
          onMouseDown={(e) => e.target === e.currentTarget && setReceipt(null)}
        >
          <div className="print-receipt w-full max-w-md card-surface overflow-hidden">
            <div className="no-print flex items-center justify-between border-b border-border px-5 py-3">
              <h3 className="text-sm font-semibold text-text-primary">Deposit Receipt</h3>
              <div className="flex gap-2">
                <Button size="sm" variant="ghost" onClick={() => window.print()}>
                  <Printer className="h-4 w-4" /> Print
                </Button>
                <Button size="sm" variant="ghost" onClick={() => setReceipt(null)}>
                  Close
                </Button>
              </div>
            </div>

            <div className="bg-white p-6 text-black">
              <div className="text-center">
                <div className="mx-auto mb-2 flex h-12 w-12 items-center justify-center rounded-full bg-green-100">
                  <CheckCircle2 className="h-7 w-7 text-green-600" />
                </div>
                <h2 className="text-xl font-bold">ADWA SHORT</h2>
                <p className="text-xs text-gray-600">Walk-in Center · Manual Deposit</p>
              </div>

              <div className="my-4 border-t border-dashed border-gray-300" />

              <div className="space-y-2 text-sm">
                <Row label="Reference" value={`#${receipt.reference ?? ''}`} />
                <Row label="Date" value={formatDateTime(receipt.timestamp)} />
                <Row label="Customer" value={receipt.user.display_name || receipt.user.phone} />
                <Row label="Phone" value={receipt.user.phone} />
              </div>

              <div className="my-4 border-t border-dashed border-gray-300" />

              <div className="space-y-2 text-sm">
                <Row label="Cash received" value={formatBirr(receipt.amount)} bold />
                <Row label="Coins credited" value={`${receipt.coins} c`} bold />
                <Row
                  label="Top-up amount"
                  value={formatBirr(receipt.amount)}
                />
              </div>

              <div className="my-4 border-t border-dashed border-gray-300" />

              <p className="text-center text-xs text-gray-600">
                Thank you for using ADWA SHORT.
                <br />
                This receipt is system-generated and valid without signature.
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function Row({ label, value, bold }) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-gray-600">{label}</span>
      <span className={bold ? 'font-bold' : 'font-medium'}>{value}</span>
    </div>
  )
}
