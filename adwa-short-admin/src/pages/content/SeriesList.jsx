import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import {
  Plus,
  Search,
  Pencil,
  Trash2,
  Eye,
  EyeOff,
  Film,
  Filter,
} from 'lucide-react'
import { useSeriesList, useCategories, useDebouncedValue } from '../../lib/hooks'
import { del, post, errMsg } from '../../lib/api'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
import { Select } from '../../components/ui/Select'
import { Card } from '../../components/ui/Card'
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
import { ConfirmDialog } from '../../components/ui/ConfirmDialog'
import {
  Badge,
  VIPBadge,
  ExclusiveBadge,
  PublishedBadge,
  PendingBadge,
} from '../../components/ui/Badge'
import { EmptyState } from '../../components/ui/EmptyState'

const STATUSES = [
  { value: 'all', label: 'All' },
  { value: 'pending', label: 'Pending' },
  { value: 'published', label: 'Published' },
]

export function SeriesList() {
  const navigate = useNavigate()
  const qc = useQueryClient()
  const [status, setStatus] = useState('all')
  const [category, setCategory] = useState('')
  const [q, setQ] = useState('')
  const debouncedQ = useDebouncedValue(q, 300)
  const [page, setPage] = useState(1)
  const [confirmDelete, setConfirmDelete] = useState(null)
  const [confirmToggle, setConfirmToggle] = useState(null)

  const { data: categories } = useCategories()
  const { data, isLoading, isFetching } = useSeriesList({
    status,
    category_id: category || undefined,
    q: debouncedQ || undefined,
    page,
  })

  const toggleMutation = useMutation({
    mutationFn: async (s) => {
      return post(`/admin/content/series/${s.id}/${s.is_published ? 'unpublish' : 'publish'}`)
    },
    onSuccess: () => {
      toast.success('Status updated')
      qc.invalidateQueries({ queryKey: ['series'] })
      setConfirmToggle(null)
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to update status')),
  })

  const deleteMutation = useMutation({
    mutationFn: async (s) => del(`/series/${s.id}`),
    onSuccess: () => {
      toast.success('Series deleted')
      qc.invalidateQueries({ queryKey: ['series'] })
      setConfirmDelete(null)
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to delete')),
  })

  const items = Array.isArray(data) ? data : []

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Series Catalog</h2>
          <p className="text-sm text-text-secondary">
            Manage all series &amp; shorts — {items.length} total
          </p>
        </div>
        <Button leftIcon={<Plus className="h-4 w-4" />} onClick={() => navigate('/content/series/new')}>
          Add Series
        </Button>
      </div>

      <Card padding="md">
        <div className="grid grid-cols-1 gap-3 md:grid-cols-4">
          <Input
            placeholder="Search title…"
            value={q}
            onChange={(e) => {
              setQ(e.target.value)
              setPage(1)
            }}
            leftIcon={<Search className="h-4 w-4" />}
            hint={q && q !== debouncedQ ? 'Searching…' : undefined}
          />
          <Select
            value={status}
            onChange={(e) => {
              setStatus(e.target.value)
              setPage(1)
            }}
            options={STATUSES}
          />
          <Select
            value={category}
            onChange={(e) => {
              setCategory(e.target.value)
              setPage(1)
            }}
          >
            <option value="">All categories</option>
            {categories?.map((c) => (
              <option key={c.id} value={c.id} className="bg-surface">
                {c.name}
              </option>
            ))}
          </Select>
          <div className="flex items-center text-xs text-text-secondary">
            <Filter className="mr-1.5 h-3.5 w-3.5" />
            {isFetching ? 'Updating…' : 'Filters applied'}
          </div>
        </div>
      </Card>

      <Card padding="none" className="overflow-hidden">
        <Table>
          <THead>
            <TR>
              <TH>Series</TH>
              <TH>Category</TH>
              <TH>Type</TH>
              <TH className="text-center">Eps</TH>
              <TH>Status</TH>
              <TH>Flags</TH>
              <TH className="text-right">Actions</TH>
            </TR>
          </THead>
          <TBody>
            {isLoading ? (
              <SkeletonRow colSpan={7} rows={6} />
            ) : items.length === 0 ? (
              <EmptyRow colSpan={7}>
                <EmptyState
                  icon={Film}
                  title="No series found"
                  description="Try adjusting your filters, or create a new series."
                  action={
                    <Button
                      leftIcon={<Plus className="h-4 w-4" />}
                      onClick={() => navigate('/content/series/new')}
                    >
                      Add Series
                    </Button>
                  }
                />
              </EmptyRow>
            ) : (
              items.map((s) => (
                <TR key={s.id}>
                  <TD>
                    <div className="flex items-center gap-3">
                      <div className="aspect-[9/16] w-10 flex-shrink-0 overflow-hidden rounded border border-border bg-surface-2">
                        {s.poster_url ? (
                          <img src={s.poster_url} alt="" className="h-full w-full object-cover" />
                        ) : (
                          <div className="flex h-full w-full items-center justify-center text-text-muted">
                            <Film className="h-4 w-4" />
                          </div>
                        )}
                      </div>
                      <div className="min-w-0">
                        <Link
                          to={`/content/series/${s.id}/edit`}
                          className="block truncate font-medium hover:text-accent"
                        >
                          {s.title}
                        </Link>
                        <p className="truncate text-xs text-text-muted">
                          {s.director || '—'}
                        </p>
                      </div>
                    </div>
                  </TD>
                  <TD>
                    <Badge tone="neutral">{s.category?.name ?? '—'}</Badge>
                  </TD>
                  <TD className="capitalize">{s.type}</TD>
                  <TD className="text-center tabular-nums">{s.episodes_count ?? 0}</TD>
                  <TD>
                    {s.is_published ? <PublishedBadge /> : <PendingBadge />}
                    <span className="ml-1 text-[10px] text-text-muted">
                      Free: {s.free_episode_count}
                    </span>
                  </TD>
                  <TD>
                    <div className="flex gap-1">
                      {s.is_vip && <VIPBadge />}
                      {s.is_exclusive && <ExclusiveBadge />}
                    </div>
                  </TD>
                  <TD>
                    <div className="flex items-center justify-end gap-1">
                      <Button
                        variant="ghost"
                        size="icon"
                        title="Edit"
                        onClick={() => navigate(`/content/series/${s.id}/edit`)}
                      >
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        title={s.is_published ? 'Unpublish' : 'Publish'}
                        onClick={() => setConfirmToggle(s)}
                      >
                        {s.is_published ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        title="Delete"
                        onClick={() => setConfirmDelete(s)}
                      >
                        <Trash2 className="h-4 w-4 text-danger" />
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
        open={!!confirmDelete}
        title="Delete Series?"
        description={`This will permanently delete "${confirmDelete?.title}" and all its episodes. This cannot be undone.`}
        confirmLabel="Delete"
        onConfirm={() => confirmDelete && deleteMutation.mutate(confirmDelete)}
        onCancel={() => setConfirmDelete(null)}
        loading={deleteMutation.isPending}
      />

      <ConfirmDialog
        open={!!confirmToggle}
        title={confirmToggle?.is_published ? 'Unpublish Series?' : 'Publish Series?'}
        description={
          confirmToggle?.is_published
            ? `"${confirmToggle?.title}" will no longer be visible to users.`
            : `"${confirmToggle?.title}" will be visible to all users.`
        }
        confirmLabel={confirmToggle?.is_published ? 'Unpublish' : 'Publish'}
        variant="warning"
        onConfirm={() => confirmToggle && toggleMutation.mutate(confirmToggle)}
        onCancel={() => setConfirmToggle(null)}
        loading={toggleMutation.isPending}
      />
    </div>
  )
}
