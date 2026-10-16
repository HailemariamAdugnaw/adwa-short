import { useState } from 'react'
import {
  Search,
  MessageSquare,
  Trash2,
  AlertCircle,
  RefreshCw,
} from 'lucide-react'
import {
  useReviews,
  useDeleteReview,
  useDebouncedValue,
} from '../../lib/hooks'
import { useQueryClient } from '@tanstack/react-query'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
import { EmptyState } from '../../components/ui/EmptyState'
import { ConfirmDialog } from '../../components/ui/ConfirmDialog'
import { Pagination } from '../../components/ui/Pagination'
import { formatDateTime, initials, formatRelative } from '../../lib/format'

const PAGE_SIZE = 20

export function Reviews() {
  const qc = useQueryClient()
  const [q, setQ] = useState('')
  const debouncedQ = useDebouncedValue(q, 300)
  const [episodeId, setEpisodeId] = useState('')
  const [userId, setUserId] = useState('')
  const [page, setPage] = useState(1)
  const [deleteTarget, setDeleteTarget] = useState(null)

  const { data, isLoading, isFetching, isError } = useReviews({
    q: debouncedQ || undefined,
    episode_id: episodeId || undefined,
    user_id: userId || undefined,
    page,
    limit: PAGE_SIZE,
  })

  const deleteMutation = useDeleteReview()

  const items = Array.isArray(data?.items) ? data.items : []
  const total = data?.total ?? items.length
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE))

  const reset = () => {
    setQ('')
    setEpisodeId('')
    setUserId('')
    setPage(1)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Reviews</h2>
          <p className="text-sm text-text-secondary">
            Public reviews from users · {total} reviews
          </p>
        </div>
        <Button variant="ghost" onClick={reset}>
          Reset filters
        </Button>
      </div>

      <Card padding="md">
        <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
          <Input
            placeholder="Search review text…"
            value={q}
            onChange={(e) => {
              setQ(e.target.value)
              setPage(1)
            }}
            leftIcon={<Search className="h-4 w-4" />}
            hint={isFetching && q ? 'Searching…' : undefined}
          />
          <Input
            placeholder="Episode ID"
            value={episodeId}
            onChange={(e) => {
              setEpisodeId(e.target.value)
              setPage(1)
            }}
          />
          <Input
            placeholder="User ID"
            value={userId}
            onChange={(e) => {
              setUserId(e.target.value)
              setPage(1)
            }}
          />
        </div>
      </Card>

      <Card padding="none" className="overflow-hidden">
        <div className="grid grid-cols-[1fr_auto_auto] gap-3 bg-surface px-5 py-3 text-[10px] font-semibold uppercase tracking-wider text-text-muted">
          <span>Conversation</span>
          <span className="text-right">When</span>
          <span className="text-right">Actions</span>
        </div>
        {isError ? (
          <div className="flex flex-col items-center justify-center gap-3 p-10 text-center">
            <AlertCircle className="h-6 w-6 text-danger" />
            <p className="text-sm text-text-secondary">Could not load reviews.</p>
            <Button
              size="sm"
              variant="ghost"
              leftIcon={<RefreshCw className="h-3.5 w-3.5" />}
              onClick={() => qc.invalidateQueries({ queryKey: ['reviews'] })}
            >
              Retry
            </Button>
          </div>
        ) : isLoading ? (
          <div className="divide-y divide-border">
            {Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="flex gap-3 px-5 py-4">
                <div className="skeleton h-10 w-10 rounded-full" />
                <div className="flex-1 space-y-2">
                  <div className="skeleton h-3 w-32 rounded" />
                  <div className="skeleton h-3 w-full rounded" />
                  <div className="skeleton h-3 w-2/3 rounded" />
                </div>
              </div>
            ))}
          </div>
        ) : items.length === 0 ? (
          <div className="p-6">
            <EmptyState
              icon={MessageSquare}
              title="No reviews found"
              description="Try adjusting your filters. New reviews will appear here as users submit them."
            />
          </div>
        ) : (
          <div className="divide-y divide-border">
            {items.map((r) => (
              <div
                key={r.id}
                className="flex items-start gap-3 px-5 py-4 transition-colors hover:bg-surface-2/30"
              >
                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-surface-2 text-xs font-bold text-text-primary">
                  {initials(r.user_display_name, r.user_phone)}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-baseline gap-x-2 gap-y-0.5">
                    <p className="text-sm font-semibold text-text-primary">
                      {r.user_display_name ?? r.user_phone ?? `User #${r.user_id}`}
                    </p>
                    <span className="text-[10px] text-text-muted">
                      · {formatRelative(r.created_at)}
                    </span>
                    <span className="rounded-full bg-surface-2 px-1.5 py-0.5 text-[10px] text-text-muted">
                      Ep #{r.episode_id}
                    </span>
                  </div>
                  <p className="mt-1 whitespace-pre-wrap break-words text-sm text-text-secondary">
                    {r.text || <span className="text-text-muted">—</span>}
                  </p>
                  <p className="mt-1 text-[10px] text-text-muted">
                    {formatDateTime(r.created_at)}
                  </p>
                </div>
                <div>
                  <Button
                    variant="ghost"
                    size="icon"
                    title="Delete review"
                    onClick={() => setDeleteTarget(r)}
                  >
                    <Trash2 className="h-4 w-4 text-danger" />
                  </Button>
                </div>
              </div>
            ))}
          </div>
        )}
        {total > PAGE_SIZE && (
          <div className="border-t border-border px-4">
            <Pagination
              page={page}
              pages={totalPages}
              total={total}
              pageSize={PAGE_SIZE}
              onChange={setPage}
            />
          </div>
        )}
      </Card>

      <ConfirmDialog
        open={!!deleteTarget}
        title="Delete Review?"
        description={`Review by "${
          deleteTarget?.user_display_name ?? deleteTarget?.user_phone ?? 'this user'
        }" will be permanently deleted.`}
        confirmLabel="Delete"
        onConfirm={() =>
          deleteTarget &&
          deleteMutation.mutate(deleteTarget.id, {
            onSuccess: () => setDeleteTarget(null),
          })
        }
        onCancel={() => setDeleteTarget(null)}
        loading={deleteMutation.isPending}
      />
    </div>
  )
}
