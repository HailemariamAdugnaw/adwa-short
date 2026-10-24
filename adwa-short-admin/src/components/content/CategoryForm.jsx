import { useEffect, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Button } from '../ui/Button'
import { Input } from '../ui/Input'
import { Textarea } from '../ui/Textarea'
import { FileDropzone } from '../ui/FileDropzone'
import { post, put, upload, errMsg } from '../../lib/api'

export function CategoryForm({ initial, onSaved, onCancel }) {
  const qc = useQueryClient()
  const isEdit = !!initial

  const [form, setForm] = useState({
    name: '',
    description: '',
    icon_url: '',
    poster_url: '',
    sort_order: 0,
    is_active: true,
  })
  const [uploadingIcon, setUploadingIcon] = useState(false)
  const [uploadingPoster, setUploadingPoster] = useState(false)

  useEffect(() => {
    if (!initial) return
    setForm({
      name: initial.name,
      description: initial.description ?? '',
      icon_url: initial.icon_url ?? '',
      poster_url: initial.poster_url ?? '',
      sort_order: initial.sort_order,
      is_active: initial.is_active,
    })
  }, [initial])

  const mutation = useMutation({
    mutationFn: async (payload) => {
      if (isEdit && initial) return put(`/categories/${initial.id}`, payload)
      return post('/categories', payload)
    },
    onSuccess: () => {
      toast.success(isEdit ? 'Category updated' : 'Category created')
      qc.invalidateQueries({ queryKey: ['categories'] })
      onSaved?.()
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to save category')),
  })

  const uploadFile = async (kind, file) => {
    const setter = kind === 'icon' ? setUploadingIcon : setUploadingPoster
    setter(true)
    try {
      const res = await upload('/uploads/poster', file)
      setForm((f) => ({ ...f, [`${kind}_url`]: res.url }))
    } catch (e) {
      toast.error(errMsg(e, 'Upload failed'))
    } finally {
      setter(false)
    }
  }

  const onSubmit = (e) => {
    e.preventDefault()
    if (!form.name.trim()) return toast.error('Name is required')
    mutation.mutate(form)
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      <Input
        label="Name"
        value={form.name}
        onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
        placeholder="e.g. Drama"
        required
      />
      <Textarea
        label="Description"
        value={form.description ?? ''}
        onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
      />
      <div className="grid grid-cols-2 gap-4">
        <FileDropzone
          label="Icon"
          accept="image"
          currentUrl={form.icon_url || null}
          uploading={uploadingIcon}
          onFile={(f) => uploadFile('icon', f)}
          onClear={() => setForm((f) => ({ ...f, icon_url: '' }))}
          helperText="64×64 PNG"
        />
        <FileDropzone
          label="Poster"
          accept="image"
          currentUrl={form.poster_url || null}
          uploading={uploadingPoster}
          onFile={(f) => uploadFile('poster', f)}
          onClear={() => setForm((f) => ({ ...f, poster_url: '' }))}
          helperText="400×600"
        />
      </div>
      <div className="grid grid-cols-2 gap-4">
        <Input
          label="Sort Order"
          type="number"
          min={0}
          value={form.sort_order ?? 0}
          onChange={(e) => setForm((f) => ({ ...f, sort_order: Number(e.target.value) }))}
        />
        <label className="flex h-12 cursor-pointer items-center justify-between gap-3 rounded-md border border-border bg-surface-2 px-4 py-2 hover:border-border-strong self-end">
          <span className="text-sm font-medium text-text-primary">Active</span>
          <input
            type="checkbox"
            checked={form.is_active}
            onChange={(e) => setForm((f) => ({ ...f, is_active: e.target.checked }))}
            className="h-4 w-4 accent-accent"
          />
        </label>
      </div>
      <div className="flex items-center justify-end gap-2 pt-2">
        <Button type="button" variant="ghost" onClick={onCancel}>
          Cancel
        </Button>
        <Button type="submit" loading={mutation.isPending}>
          {isEdit ? 'Save Changes' : 'Create Category'}
        </Button>
      </div>
    </form>
  )
}
