import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { ChevronLeft, Plus, Pencil, Trash2, Clock, Film, Eye, EyeOff } from 'lucide-react'
import {
  useSeries,
  useEpisodes,
  usePublishEpisode,
  useUnpublishEpisode,
} from '../../lib/hooks'
import { del, errMsg } from '../../lib/api'
import { SeriesForm } from '../../components/content/SeriesForm'
import { EpisodeForm } from '../../components/content/EpisodeForm'
import { Card, CardHeader, CardTitle } from '../../components/ui/Card'
import { Tabs } from '../../components/ui/Tabs'
import { Button } from '../../components/ui/Button'
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
import { Modal } from '../../components/ui/Modal'
import { ConfirmDialog } from '../../components/ui/ConfirmDialog'
import { EmptyState } from '../../components/ui/EmptyState'
import { formatDuration } from '../../lib/format'

export function SeriesEdit() {
  const { id } = useParams()
  const qc = useQueryClient()
  const { data: series, isLoading } = useSeries(id)
  const { data: episodes, isLoading: loadingEpisodes } = useEpisodes(id)
  const [openEpisode, setOpenEpisode] = useState(false)
  const [editEpisode, setEditEpisode] = useState(undefined)
  const [deleteEpisode, setDeleteEpisode] = useState(null)
  const [toggleEpisode, setToggleEpisode] = useState(null)

  const deleteMutation = useMutation({
    mutationFn: async (ep) => del(`/episodes/${ep.id}`),
    onSuccess: () => {
      toast.success('Episode deleted')
      qc.invalidateQueries({ queryKey: ['series', id, 'episodes'] })
      setDeleteEpisode(null)
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to delete episode')),
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

  if (isLoading || !series) {
    return (
      <div className="space-y-4">
        <div className="skeleton h-6 w-40 rounded" />
        <div className="skeleton h-96 w-full rounded-lg" />
      </div>
    )
  }

  const episodesTable = (
    <Card padding="none" className="overflow-hidden">
      <CardHeader className="border-b border-border px-5 py-3">
        <CardTitle>Episodes</CardTitle>
        <Button
          size="sm"
          leftIcon={<Plus className="h-3.5 w-3.5" />}
          onClick={() => {
            setEditEpisode(undefined)
            setOpenEpisode(true)
          }}
        >
          Add Episode
        </Button>
      </CardHeader>
      <Table>
        <THead>
          <TR>
            <TH className="w-16 text-center">#</TH>
            <TH>Title</TH>
            <TH className="text-right">Duration</TH>
            <TH className="text-right">Coin cost</TH>
            <TH>Status</TH>
            <TH className="text-right">Actions</TH>
          </TR>
        </THead>
        <TBody>
          {loadingEpisodes ? (
            <SkeletonRow colSpan={6} rows={4} />
          ) : (episodes ?? []).length === 0 ? (
            <EmptyRow colSpan={6}>
              <EmptyState
                icon={Clock}
                title="No episodes yet"
                description="Add your first episode to this series."
                action={
                  <Button
                    leftIcon={<Plus className="h-4 w-4" />}
                    onClick={() => setOpenEpisode(true)}
                  >
                    Add Episode
                  </Button>
                }
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
                      onClick={() => {
                        setEditEpisode(ep)
                        setOpenEpisode(true)
                      }}
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
  )

  return (
    <div className="space-y-4">
      <div>
        <Link
          to="/content/series"
          className="inline-flex items-center gap-1 text-xs text-text-secondary hover:text-text-primary"
        >
          <ChevronLeft className="h-3.5 w-3.5" />
          Back to Series
        </Link>
        <h2 className="mt-1 text-xl font-bold text-text-primary">Edit Series</h2>
        <p className="text-sm text-text-secondary">
          {series.title} · <span className="text-text-muted">ID: {String(series.id)}</span>
        </p>
      </div>

      <Tabs
        items={[
          {
            id: 'details',
            label: 'Series Details',
            icon: <Film className="h-4 w-4" />,
            content: <SeriesForm initial={series} />,
          },
          {
            id: 'episodes',
            label: `Episodes (${episodes?.length ?? 0})`,
            icon: <Clock className="h-4 w-4" />,
            content: episodesTable,
          },
        ]}
      />

      <Modal
        open={openEpisode}
        onClose={() => setOpenEpisode(false)}
        title={editEpisode ? 'Edit Episode' : 'Add Episode'}
        size="xl"
      >
        <EpisodeForm
          seriesId={id}
          initial={editEpisode}
          onCancel={() => setOpenEpisode(false)}
          onSaved={() => setOpenEpisode(false)}
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
