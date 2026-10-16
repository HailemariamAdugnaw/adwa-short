import { useEffect, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Save, X, Smartphone } from 'lucide-react'
import { Button } from '../ui/Button'
import { Input } from '../ui/Input'
import { Select } from '../ui/Select'
import { Textarea } from '../ui/Textarea'
import { FileDropzone } from '../ui/FileDropzone'
import { Card } from '../ui/Card'
import { post, put, upload, errMsg } from '../../lib/api'
import { getVideoDuration } from '../../lib/media'
import { useSeries, useCreators } from '../../lib/hooks'

export function EpisodeForm({ seriesId, initial, onSaved, onCancel }) {
  const qc = useQueryClient()
  const isEdit = !!initial
  const { data: series } = useSeries(seriesId)
  const { data: creators } = useCreators()
  const inheritedCreatorId = series?.creator_id

  const [form, setForm] = useState({
    episode_number: initial?.episode_number ?? 1,
    title: initial?.title ?? '',
    description: initial?.description ?? '',
    video_url: initial?.video_url ?? '',
    duration_seconds: initial?.duration_seconds ?? 0,
    thumbnail_url: initial?.thumbnail_url ?? '',
    is_short: initial?.is_short ?? false,
    vertical_video_url: initial?.vertical_video_url ?? '',
    coin_cost: initial?.coin_cost ?? 0,
    creator_id: initial?.creator_id ?? inheritedCreatorId ?? '',
  })
  const [uploadingVideo, setUploadingVideo] = useState(false)
  const [uploadingThumb, setUploadingThumb] = useState(false)
  const [videoFile, setVideoFile] = useState(null)
  const [durationAuto, setDurationAuto] = useState(false)

  useEffect(() => {
    if (form.creator_id || !inheritedCreatorId) return
    setForm((f) => ({ ...f, creator_id: String(inheritedCreatorId) }))
  }, [inheritedCreatorId, form.creator_id])

  const selectedCreator = (creators ?? []).find(
    (c) => String(c.id) === String(form.creator_id),
  )

  const mutation = useMutation({
    mutationFn: async (payload) => {
      if (isEdit && initial) return put(`/episodes/${initial.id}`, payload)
      return post('/episodes', { ...payload, series_id: seriesId })
    },
    onSuccess: () => {
      toast.success(isEdit ? 'Episode updated' : 'Episode created')
      qc.invalidateQueries({ queryKey: ['series', seriesId, 'episodes'] })
      setVideoFile(null)
      setDurationAuto(false)
      onSaved?.()
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to save episode')),
  })

  const handleVideoFile = async (file) => {
    setUploadingVideo(true)
    setVideoFile(file)
    setDurationAuto(false)
    const duration = await getVideoDuration(file)
    if (duration) {
      setForm((f) => ({ ...f, duration_seconds: duration }))
      setDurationAuto(true)
    }
    try {
      const res = await upload('/uploads/video', file)
      setForm((f) => ({ ...f, video_url: res.url }))
      toast.success('Upload complete')
    } catch (e) {
      toast.error(errMsg(e, 'Upload failed'))
      setVideoFile(null)
    } finally {
      setUploadingVideo(false)
    }
  }

  const handleThumbFile = async (file) => {
    setUploadingThumb(true)
    try {
      const res = await upload('/uploads/poster', file)
      setForm((f) => ({ ...f, thumbnail_url: res.url }))
      toast.success('Upload complete')
    } catch (e) {
      toast.error(errMsg(e, 'Upload failed'))
    } finally {
      setUploadingThumb(false)
    }
  }

  const clearVideo = () => {
    setForm((f) => ({ ...f, video_url: '' }))
    setVideoFile(null)
    setDurationAuto(false)
  }

  const clearThumb = () => {
    setForm((f) => ({ ...f, thumbnail_url: '' }))
  }

  const onSubmit = (e) => {
    e.preventDefault()
    if (!form.title.trim()) return toast.error('Title is required')
    if (!form.video_url) return toast.error('Video file is required')
    if (!form.creator_id) return toast.error('Creator is required')
    const payload = {
      ...form,
      creator_id: form.creator_id ? Number(form.creator_id) : undefined,
    }
    mutation.mutate(payload)
  }

  return (
    <form onSubmit={onSubmit} className="space-y-6">
      <Card padding="lg">
        <h3 className="mb-4 text-sm font-semibold uppercase tracking-wide text-text-secondary">
          Episode Details
        </h3>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <Input
            label="Episode Number"
            type="number"
            min={1}
            value={form.episode_number}
            onChange={(e) => setForm((f) => ({ ...f, episode_number: Number(e.target.value) }))}
            required
          />
          <Input
            label="Coin Cost"
            type="number"
            min={0}
            value={form.coin_cost}
            onChange={(e) => setForm((f) => ({ ...f, coin_cost: Number(e.target.value) }))}
            hint="0 = free with subscription"
          />
          <div className="md:col-span-2">
            <Input
              label="Title"
              value={form.title}
              onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
              placeholder="e.g. The Beginning"
              required
            />
          </div>
          <div className="md:col-span-2">
            <Textarea
              label="Description"
              value={form.description ?? ''}
              onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
            />
          </div>
          <Input
            label="Duration (seconds)"
            type="number"
            min={0}
            value={form.duration_seconds}
            onChange={(e) => {
              setForm((f) => ({ ...f, duration_seconds: Number(e.target.value) }))
              setDurationAuto(false)
            }}
            hint={durationAuto ? 'Auto-detected from video · editable' : undefined}
          />
          <label className="flex h-12 cursor-pointer items-center justify-between gap-3 rounded-md border border-border bg-surface-2 px-4 py-2 hover:border-border-strong self-end">
            <span className="text-sm font-medium text-text-primary">Short episode</span>
            <input
              type="checkbox"
              checked={form.is_short}
              onChange={(e) => setForm((f) => ({ ...f, is_short: e.target.checked }))}
              className="h-4 w-4 accent-accent"
            />
          </label>
          <div className="md:col-span-2">
            <Select
              label="Creator"
              value={form.creator_id}
              onChange={(e) => setForm((f) => ({ ...f, creator_id: e.target.value }))}
              required
              hint={
                selectedCreator
                  ? `Split: ${selectedCreator.default_revenue_split_pct ?? 50}% creator / ${
                      100 - (selectedCreator.default_revenue_split_pct ?? 50)
                    }% platform${
                      inheritedCreatorId && String(inheritedCreatorId) === String(form.creator_id)
                        ? ' · inherited from series'
                        : ''
                      }`
                  : 'Select the creator who owns this episode'
              }
            >
              <option value="">Select creator…</option>
              {(creators ?? []).map((c) => (
                <option key={c.id} value={c.id} className="bg-surface">
                  {c.name} ({c.default_revenue_split_pct ?? 50}% split)
                </option>
              ))}
            </Select>
          </div>
        </div>
      </Card>

      <Card padding="lg">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
          <h3 className="text-sm font-semibold uppercase tracking-wide text-text-secondary">
            Media
          </h3>
          <span className="inline-flex items-center gap-1 rounded-full border border-accent-border bg-accent-soft px-2.5 py-1 text-[11px] font-medium text-accent">
            <Smartphone className="h-3 w-3" />
            Vertical only · 9:16
          </span>
        </div>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <FileDropzone
            label="Video"
            accept="video"
            previewType="video"
            previewAspect="vertical"
            currentUrl={form.video_url || null}
            previewFile={videoFile}
            uploading={uploadingVideo}
            onFile={handleVideoFile}
            onClear={clearVideo}
            helperText="MP4, MOV, MKV, WebM, AVI · vertical 9:16"
          />
          <FileDropzone
            label="Thumbnail"
            accept="image"
            previewAspect="vertical"
            currentUrl={form.thumbnail_url || null}
            uploading={uploadingThumb}
            onFile={handleThumbFile}
            onClear={clearThumb}
            helperText="JPG/PNG · vertical 9:16"
          />
        </div>
      </Card>

      <div className="rounded-md border border-border bg-surface-2/60 px-4 py-3 text-xs text-text-secondary">
        Episode will be saved as draft. Use the Publish button to make it visible to users.
      </div>

      <div className="flex items-center justify-end gap-2">
        <Button type="button" variant="ghost" onClick={onCancel} leftIcon={<X className="h-4 w-4" />}>
          Cancel
        </Button>
        <Button type="submit" loading={mutation.isPending} leftIcon={<Save className="h-4 w-4" />}>
          {isEdit ? 'Save Episode' : 'Add Episode'}
        </Button>
      </div>
    </form>
  )
}
