import { useState, useEffect } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Search, Users as UsersIcon, Eye, Ban, CheckCircle2 } from 'lucide-react'
import { useUsers, useDebouncedValue } from '../../lib/hooks'
import { post, errMsg } from '../../lib/api'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
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
import { Badge } from '../../components/ui/Badge'
import { EmptyState } from '../../components/ui/EmptyState'
import { ConfirmDialog } from '../../components/ui/ConfirmDialog'
import { formatBirr, formatNumber, formatDate, initials } from '../../lib/format'

export function UsersList() {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const qc = useQueryClient()
  const [q, setQ] = useState(searchParams.get('q') ?? '')
  const debouncedQ = useDebouncedValue(q, 300)
  const [page, setPage] = useState(Number(searchParams.get('page') ?? 1))
  const [confirmBan, setConfirmBan] = useState(null)

  const { data, isLoading, isFetching } = useUsers({ q: debouncedQ || undefined, page })

  useEffect(() => {
    const params = new URLSearchParams()
    if (debouncedQ) params.set('q', debouncedQ)
    if (page > 1) params.set('page', String(page))
    setSearchParams(params, { replace: true })
  }, [debouncedQ, page, setSearchParams])

  const banMutation = useMutation({
    mutationFn: async (u) => post(`/admin/users/${u.id}/${u.is_banned ? 'unban' : 'ban'}`),
    onSuccess: (_d, u) => {
      toast.success(u.is_banned ? 'User unbanned' : 'User banned')
      qc.invalidateQueries({ queryKey: ['users'] })
      setConfirmBan(null)
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to update user')),
  })

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-xl font-bold text-text-primary">Users</h2>
        <p className="text-sm text-text-secondary">
          Search, inspect, and manage user accounts · {(Array.isArray(data) ? data : []).length} total
        </p>
      </div>

      <Card padding="md">
        <Input
          placeholder="Search by phone, name, or User ID…"
          value={q}
          onChange={(e) => {
            setQ(e.target.value)
            setPage(1)
          }}
          leftIcon={<Search className="h-4 w-4" />}
          hint={isFetching && q ? 'Searching…' : undefined}
        />
      </Card>

      <Card padding="none" className="overflow-hidden">
        <Table>
          <THead>
            <TR>
              <TH>User</TH>
              <TH>Phone</TH>
              <TH className="text-right">Wallet</TH>
              <TH className="text-right">Coins</TH>
              <TH>Status</TH>
              <TH>Joined</TH>
              <TH className="text-right">Actions</TH>
            </TR>
          </THead>
          <TBody>
            {isLoading ? (
              <SkeletonRow colSpan={7} rows={6} />
            ) : (Array.isArray(data) ? data : []).length === 0 ? (
              <EmptyRow colSpan={7}>
                <EmptyState
                  icon={UsersIcon}
                  title="No users found"
                  description="Try a different search term."
                />
              </EmptyRow>
            ) : (
              (Array.isArray(data) ? data : []).map((u) => (
                <TR key={u.id} className="cursor-pointer" onClick={() => navigate(`/users/${u.id}`)}>
                  <TD>
                    <div className="flex items-center gap-3">
                      <div className="flex h-9 w-9 items-center justify-center rounded-full bg-surface-2 text-xs font-bold text-text-primary">
                        {initials(u.display_name, u.phone)}
                      </div>
                      <div className="min-w-0">
                        <p className="truncate font-medium">{u.display_name || 'Unnamed'}</p>
                        <p className="truncate text-[10px] text-text-muted">User #{u.id}</p>
                      </div>
                    </div>
                  </TD>
                  <TD className="font-mono text-xs text-text-secondary">{u.phone}</TD>
                  <TD className="text-right tabular-nums font-medium text-emerald-400">
                    {formatBirr(u.balance_birr ?? 0)}
                  </TD>
                  <TD className="text-right tabular-nums font-medium text-amber-400">
                    <span className="inline-flex items-center justify-end gap-1">
                      🪙 {formatNumber(u.balance_coins ?? 0)}
                    </span>
                  </TD>
                  <TD>
                    {u.is_banned ? (
                      <Badge tone="danger">Banned</Badge>
                    ) : (
                      <Badge tone="neutral">Active</Badge>
                    )}
                  </TD>
                  <TD className="text-xs text-text-secondary">{formatDate(u.created_at)}</TD>
                  <TD onClick={(e) => e.stopPropagation()}>
                    <div className="flex items-center justify-end gap-1">
                      <Button
                        variant="ghost"
                        size="icon"
                        title="View"
                        onClick={() => navigate(`/users/${u.id}`)}
                      >
                        <Eye className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        title={u.is_banned ? 'Unban' : 'Ban'}
                        onClick={() => setConfirmBan(u)}
                      >
                        {u.is_banned ? (
                          <CheckCircle2 className="h-4 w-4 text-success" />
                        ) : (
                          <Ban className="h-4 w-4 text-danger" />
                        )}
                      </Button>
                    </div>
                  </TD>
                </TR>
              ))
            )}
          </TBody>
        </Table>
      </Card>

      <ConfirmDialog
        open={!!confirmBan}
        title={confirmBan?.is_banned ? 'Unban User?' : 'Ban User?'}
        description={
          confirmBan?.is_banned
            ? `"${confirmBan?.display_name || confirmBan?.phone}" will regain access to the platform.`
            : `"${confirmBan?.display_name || confirmBan?.phone}" will be immediately signed out and blocked from the app.`
        }
        confirmLabel={confirmBan?.is_banned ? 'Unban' : 'Ban'}
        variant={confirmBan?.is_banned ? 'primary' : 'danger'}
        onConfirm={() => confirmBan && banMutation.mutate(confirmBan)}
        onCancel={() => setConfirmBan(null)}
        loading={banMutation.isPending}
      />
    </div>
  )
}
