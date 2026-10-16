import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Save, X, Smartphone } from 'lucide-react'
import { Button } from '../ui/Button'
import { Input } from '../ui/Input'
import { Textarea } from '../ui/Textarea'
import { Select } from '../ui/Select'
import { FileDropzone } from '../ui/FileDropzone'
import { Card } from '../ui/Card'
import { post, put, upload, errMsg } from '../../lib/api'
import { useCategories, useCreators } from '../../lib/hooks'

export function SeriesForm({ initial, onSaved, onCancel }) {
  const navigate = useNavigate()
  const qc = useQueryClient()
  const { data: categories } = useCategories()
  const { data: creators } = useCreators()
  const isEdit = !!initial

  const [form, setForm] = useState({
    title: '',
    description: '',
    category_id: '',
    creator_id: '',
    is_vip: false,
    is_exclusive: false,
    free_episode_count: 0,
    director: '',
    cast: [],
    tags: [],
    poster_url: '',
    banner_url: '',
    intro_bumper_url: '',
  })
  const [castStr, setCastStr] = useState('')
  const [tagsStr, setTagsStr] = useState('')
  const [uploading, setUploading] = useState(null)
  const [bumperFile, setBumperFile] = useState(null)

  useEffect(() => {
    if (!initial) return
    setForm({
      title: initial.title ?? '',
      description: initial.description ?? '',
      category_id: initial.category_id ?? '',
      creator_id: initial.creator_id ?? '',
      is_vip: !!initial.is_vip,
      is_exclusive: !!initial.is_exclusive,
      free_episode_count: initial.free_episode_count ?? 0,
      director: initial.director ?? '',
      cast: initial.cast ?? [],
      tags: initial.tags ?? [],
      poster_url: initial.poster_url ?? '',
      banner_url: initial.banner_url ?? '',
      intro_bumper_url: initial.intro_bumper_url ?? '',
    })
    setCastStr((initial.cast ?? []).join(', '))
    setTagsStr((initial.tags ?? []).join(', '))
  }, [initial])

  const mutation = useMutation({
    mutationFn: async (payload) => {
      if (isEdit && initial) {
        return put(`/series/${initial.id}`, payload)
      }
      return post('/series', payload)
    },
    onSuccess: (saved) => {
      toast.success(isEdit ? 'Series updated' : 'Series created')
      qc.invalidateQueries({ queryKey: ['series'] })
      onSaved?.(saved)
      if (!isEdit) navigate(`/content/series/${saved.id}/edit`)
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to save series')),
  })

  const handleUpload = async (kind, file) => {
    setUploading(kind)
    if (kind === 'bumper') setBumperFile(file)
    try {
      const endpoint = kind === 'bumper' ? '/uploads/video' : '/uploads/poster'
      const res = await upload(endpoint, file)
      setForm((f) => ({ ...f, [`${kind}_url`]: res.url }))
      toast.success(`${kind} uploaded`)
      if (kind === 'bumper') setBumperFile(null)
    } catch (e) {
      toast.error(errMsg(e, 'Upload failed'))
      if (kind === 'bumper') setBumperFile(null)
    } finally {
      setUploading(null)
    }
  }

  const clearUpload = (kind) => {
    setForm((f) => ({ ...f, [`${kind}_url`]: '' }))
    if (kind === 'bumper') setBumperFile(null)
  }

  const onSubmit = (e) => {
    e.preventDefault()
    const payload = {
      ...form,
      type: 'series',
      total_episodes: 0,
      creator_id: form.creator_id ? Number(form.creator_id) : undefined,
      cast: castStr
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean),
      tags: tagsStr
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean),
    }
    if (!payload.title.trim()) return toast.error('Title is required')
    if (!payload.category_id) return toast.error('Category is required')
    if (!payload.creator_id) return toast.error('Creator is required')
    mutation.mutate(payload)
  }

  return (
    <form onSubmit={onSubmit} className="space-y-6">
      <Card padding="lg">
        <h3 className="mb-4 text-sm font-semibold uppercase tracking-wide text-text-secondary">
          Basic Information
        </h3>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <Input
            label="Title"
            value={form.title}
            onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
            placeholder="e.g. Yewubdar"
            required
          />
          <Select
            label="Category"
            value={form.category_id}
            onChange={(e) => setForm((f) => ({ ...f, category_id: e.target.value }))}
            required
          >
            <option value="">Select category…</option>
            {categories?.map((c) => (
              <option key={c.id} value={c.id} className="bg-surface">
                {c.name}
              </option>
            ))}
          </Select>
          <Select
            label="Creator"
            value={form.creator_id}
            onChange={(e) => setForm((f) => ({ ...f, creator_id: e.target.value }))}
            required
          >
            <option value="">Select creator…</option>
            {(creators ?? []).map((c) => (
              <option key={c.id} value={c.id} className="bg-surface">
                {c.name} ({c.default_revenue_split_pct ?? 50}% split)
              </option>
            ))}
          </Select>
          <div className="md:col-span-2">
            <Textarea
              label="Description"
              value={form.description}
              onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
              placeholder="Short synopsis for the series…"
            />
          </div>
        </div>
      </Card>

      <Card padding="lg">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
          <h3 className="text-sm font-semibold uppercase tracking-wide text-text-secondary">
            Branding &amp; Media
          </h3>
          <span className="inline-flex items-center gap-1 rounded-full border border-accent-border bg-accent-soft px-2.5 py-1 text-[11px] font-medium text-accent">
            <Smartphone className="h-3 w-3" />
            Vertical platform · 9:16 videos
          </span>
        </div>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
          <FileDropzone
            label="Poster"
            accept="image"
            previewAspect="poster"
            currentUrl={form.poster_url || null}
            uploading={uploading === 'poster'}
            onFile={(f) => handleUpload('poster', f)}
            onClear={() => clearUpload('poster')}
            helperText="JPG/PNG · 2:3 vertical"
          />
          <FileDropzone
            label="Banner"
            accept="image"
            previewAspect="banner"
            currentUrl={form.banner_url || null}
            uploading={uploading === 'banner'}
            onFile={(f) => handleUpload('banner', f)}
            onClear={() => clearUpload('banner')}
            helperText="JPG/PNG · 16:9 hero"
          />
          <FileDropzone
            label="Intro Bumper"
            accept="video"
            previewType="video"
            previewAspect="vertical"
            currentUrl={form.intro_bumper_url || null}
            previewFile={bumperFile}
            uploading={uploading === 'bumper'}
            onFile={(f) => handleUpload('bumper', f)}
            onClear={() => clearUpload('bumper')}
            helperText="MP4, MOV, MKV… · 2–5s · 9:16"
          />
        </div>
      </Card>

      <Card padding="lg">
        <h3 className="mb-4 text-sm font-semibold uppercase tracking-wide text-text-secondary">
          Flags & Access
        </h3>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
          <label className="flex h-20 cursor-pointer items-center justify-between gap-3 rounded-md border border-border bg-surface-2 px-4 py-3 hover:border-border-strong">
            <div>
              <p className="text-sm font-medium text-text-primary">VIP</p>
              <p className="text-[11px] text-text-muted">Subscribers-only</p>
            </div>
            <input
              type="checkbox"
              checked={form.is_vip}
              onChange={(e) => setForm((f) => ({ ...f, is_vip: e.target.checked }))}
              className="h-4 w-4 accent-accent"
            />
          </label>
          <label className="flex h-20 cursor-pointer items-center justify-between gap-3 rounded-md border border-border bg-surface-2 px-4 py-3 hover:border-border-strong">
            <div>
              <p className="text-sm font-medium text-text-primary">Exclusive</p>
              <p className="text-[11px] text-text-muted">Platform exclusive</p>
            </div>
            <input
              type="checkbox"
              checked={form.is_exclusive}
              onChange={(e) => setForm((f) => ({ ...f, is_exclusive: e.target.checked }))}
              className="h-4 w-4 accent-accent"
            />
          </label>
          <Input
            label="Free Episodes"
            type="number"
            min={0}
            value={form.free_episode_count}
            onChange={(e) => setForm((f) => ({ ...f, free_episode_count: Number(e.target.value) }))}
            hint="Episodes free without subscription"
          />
          <Input
            label="Director"
            value={form.director ?? ''}
            onChange={(e) => setForm((f) => ({ ...f, director: e.target.value }))}
            placeholder="e.g. Abebe Bekele"
          />
        </div>
      </Card>

      <Card padding="lg">
        <h3 className="mb-4 text-sm font-semibold uppercase tracking-wide text-text-secondary">
          Cast & Tags
        </h3>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <Input
            label="Cast (comma-separated)"
            value={castStr}
            onChange={(e) => setCastStr(e.target.value)}
            placeholder="Selam Tesfaye, Dawit Fikadu"
            hint="Will be stored as a list"
          />
          <Input
            label="Tags (comma-separated)"
            value={tagsStr}
            onChange={(e) => setTagsStr(e.target.value)}
            placeholder="drama, romance, amharic"
            hint="Used for search & discovery"
          />
        </div>
      </Card>

      <div className="sticky bottom-0 flex items-center justify-end gap-2 border-t border-border bg-base/95 px-4 py-3 backdrop-blur">
        <Button
          type="button"
          variant="ghost"
          onClick={() => (onCancel ? onCancel() : navigate(-1))}
          leftIcon={<X className="h-4 w-4" />}
        >
          Cancel
        </Button>
        <Button type="submit" loading={mutation.isPending} leftIcon={<Save className="h-4 w-4" />}>
          {isEdit ? 'Save Changes' : 'Create Series'}
        </Button>
      </div>
    </form>
  )
}
