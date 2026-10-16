import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Plus, Trash2, Clock, Film, Eye, EyeOff, Pencil } from 'lucide-react'
import { useSeriesList, useEpisodes, usePublishEpisode, useUnpublishEpisode } from '../../lib/hooks'
import { del, errMsg } from '../../lib/api'
import { Card, CardHeader, CardTitle } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Select } from '../../components/ui/Select'
import { Modal } from '../../components/ui/Modal'
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
import { EmptyState } from '../../components/ui/EmptyState'
import { Badge } from '../../components/ui/Badge'
import { EpisodeForm } from '../../components/content/EpisodeForm'
import { formatDuration } from '../../lib/format'

export function Episodes() {
  const navigate = useNavigate()
  const qc = useQueryClient()
  const [selectedSeries, setSelectedSeries] = useState('')
  const [deleteEpisode, setDeleteEpisode] = useState(null)
  const [toggleEpisode, setToggleEpisode] = useState(null)
  const [editEpisode, setEditEpisode] = useState(undefined)
  const [editOpen, setEditOpen] = useState(false)

  const { data: seriesList, isLoading: loadingSeries } = useSeriesList({ page: 1 })
  const { data: episodes, isLoading: loadingEpisodes } = useEpisodes(selectedSeries || undefined)

  const deleteMutation = useMutation({
    mutationFn: async (ep) => del(`/episodes/${ep.id}`),
    onSuccess: () => {
      toast.success('Episode deleted')
      qc.invalidateQueries({ queryKey: ['series', selectedSeries, 'episodes'] })
      qc.invalidateQueries({ queryKey: ['series'] })
      setDeleteEpisode(null)
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to delete')),
  })

  const publishMutation = usePublishEpisode()
  const unpublishMutation = useUnpublishEpisode()

  const onToggle = async (ep) => {
    const mutation = ep.is_published ? unpublishMutation : publishMutation
    try {
      await mutation.mutateAsync(ep.id)
      toast.success(ep.is_published ? 'Episode unpublished' : 'Episode published')
      setToggleEpisode(null)
    } catch (err) {
      toast.error(errMsg(err, 'Failed to update status'))
    }
  }

  const togglePending = publishMutation.isPending || unpublishMutation.isPending

  const openEdit = (ep) => {
    setEditEpisode(ep)
    setEditOpen(true)
  }

  return (
    <div className="space-y-4">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Episodes</h2>
          <p className="text-sm text-text-secondary">
            Select a series to manage its episodes.
          </p>
        </div>
      </div>

      <Card padding="md">
        <Select
          label="Select Series"
          value={selectedSeries}
          onChange={(e) => setSelectedSeries(e.target.value)}
        >
          <option value="">Choose a series…</option>
          {!loadingSeries &&
            (seriesList ?? []).map((s) => (
              <option key={s.id} value={s.id} className="bg-surface">
                {s.title}
              </option>
            ))}
        </Select>
      </Card>

      {selectedSeries && (
        <Card padding="none" className="overflow-hidden">
          <CardHeader className="border-b border-border px-5 py-3">
            <CardTitle>Episodes</CardTitle>
            <Button
              size="sm"
              leftIcon={<Plus className="h-3.5 w-3.5" />}
              onClick={() => navigate(`/content/series/${selectedSeries}/edit`)}
            >
              Manage in Series
            </Button>
          </CardHeader>
          <Table>
            <THead>
              <TR>
                <TH className="w-16 text-center">#</TH>
                <TH>Title</TH>
                <TH className="text-right">Duration</TH>
                <TH className="text-right">Coin Cost</TH>
                <TH>Type</TH>
                <TH>Status</TH>
                <TH className="text-right">Actions</TH>
              </TR>
            </THead>
            <TBody>
              {loadingEpisodes ? (
                <SkeletonRow colSpan={7} rows={4} />
              ) : (episodes ?? []).length === 0 ? (
                <EmptyRow colSpan={7}>
                  <EmptyState
                    icon={Clock}
                    title="No episodes"
                    description="This series has no episodes yet."
                  />
                </EmptyRow>
              ) : (
                (episodes ?? []).map((ep) => (
                  <TR key={ep.id}>
                    <TD className="text-center font-mono text-text-secondary">
                      {ep.episode_number}
                    </TD>
                    <TD className="font-medium">{ep.title}</TD>
                    <TD className="text-right tabular-nums">
                      {formatDuration(ep.duration_seconds)}
                    </TD>
                    <TD className="text-right tabular-nums">{ep.coin_cost}</TD>
                    <TD>
                      <Badge tone={ep.is_short ? 'accent' : 'neutral'}>
                        {ep.is_short ? 'Short' : 'Full'}
                      </Badge>
                    </TD>
                    <TD>
                      {ep.is_published ? (
                        <Badge tone="success">Published</Badge>
                      ) : (
                        <Badge tone="warning">Draft</Badge>
                      )}
                    </TD>
                    <TD>
                      <div className="flex items-center justify-end gap-1">
                        <Button
                          variant="ghost"
                          size="icon"
                          title="Edit"
                          onClick={() => openEdit(ep)}
                        >
                          <Pencil className="h-4 w-4" />
                        </Button>
                        <Button
                          variant={ep.is_published ? 'ghost' : 'primary'}
                          size="icon"
                          title={ep.is_published ? 'Unpublish' : 'Publish'}
                          onClick={() => setToggleEpisode(ep)}
                        >
                          {ep.is_published ? (
                            <EyeOff className="h-4 w-4" />
                          ) : (
                            <Eye className="h-4 w-4" />
                          )}
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          title="Delete"
                          onClick={() => setDeleteEpisode(ep)}
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
      )}

      {!selectedSeries && (
        <Card padding="md">
          <EmptyState
            icon={Film}
            title="Select a series"
            description="Pick a series above to view and manage its episodes."
          />
        </Card>
      )}

      <Modal
        open={editOpen}
        onClose={() => setEditOpen(false)}
        title={editEpisode ? 'Edit Episode' : 'Add Episode'}
        size="xl"
      >
        <EpisodeForm
          seriesId={selectedSeries || (editEpisode?.series_id ?? '')}
          initial={editEpisode}
          onCancel={() => setEditOpen(false)}
          onSaved={() => setEditOpen(false)}
        />
      </Modal>

      <ConfirmDialog
        open={!!deleteEpisode}
        title="Delete Episode?"
        description={`"${deleteEpisode?.title}" will be permanently removed.`}
        confirmLabel="Delete"
        onConfirm={() => deleteEpisode && deleteMutation.mutate(deleteEpisode)}
        onCancel={() => setDeleteEpisode(null)}
        loading={deleteMutation.isPending}
      />

      <ConfirmDialog
        open={!!toggleEpisode}
        title={toggleEpisode?.is_published ? 'Unpublish Episode?' : 'Publish Episode?'}
        description={
          toggleEpisode?.is_published
            ? `"${toggleEpisode?.title}" will no longer be visible to users.`
            : `"${toggleEpisode?.title}" will be visible to all users.`
        }
        confirmLabel={toggleEpisode?.is_published ? 'Unpublish' : 'Publish'}
        variant="warning"
        onConfirm={() => toggleEpisode && onToggle(toggleEpisode)}
        onCancel={() => setToggleEpisode(null)}
        loading={togglePending}
      />
    </div>
  )
}
