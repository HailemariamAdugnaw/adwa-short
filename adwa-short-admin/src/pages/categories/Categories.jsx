import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import { Plus, Pencil, Trash2, FolderTree, GripVertical } from 'lucide-react'
import { useCategories } from '../../lib/hooks'
import { del, errMsg } from '../../lib/api'
import { Card } from '../../components/ui/Card'
import { Button } from '../../components/ui/Button'
import { Modal } from '../../components/ui/Modal'
import { ConfirmDialog } from '../../components/ui/ConfirmDialog'
import { EmptyState } from '../../components/ui/EmptyState'
import { Badge } from '../../components/ui/Badge'
import { CategoryForm } from '../../components/content/CategoryForm'

export function Categories() {
  const qc = useQueryClient()
  const { data: categories, isLoading } = useCategories()
  const [open, setOpen] = useState(false)
  const [editItem, setEditItem] = useState(undefined)
  const [deleteItem, setDeleteItem] = useState(null)

  const deleteMutation = useMutation({
    mutationFn: async (c) => del(`/categories/${c.id}`),
    onSuccess: () => {
      toast.success('Category deleted')
      qc.invalidateQueries({ queryKey: ['categories'] })
      setDeleteItem(null)
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to delete category')),
  })

  const openCreate = () => {
    setEditItem(undefined)
    setOpen(true)
  }
  const openEdit = (c) => {
    setEditItem(c)
    setOpen(true)
  }

  return (
    <div className="space-y-4">
      <div className="flex items-end justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Categories</h2>
          <p className="text-sm text-text-secondary">
            Organize content into discoverable categories · {categories?.length ?? 0} total
          </p>
        </div>
        <Button leftIcon={<Plus className="h-4 w-4" />} onClick={openCreate}>
          Add Category
        </Button>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="skeleton h-44 rounded-lg" />
          ))}
        </div>
      ) : (categories?.length ?? 0) === 0 ? (
        <Card padding="lg">
          <EmptyState
            icon={FolderTree}
            title="No categories yet"
            description="Create your first category to organize your content."
            action={
              <Button leftIcon={<Plus className="h-4 w-4" />} onClick={openCreate}>
                Add Category
              </Button>
            }
          />
        </Card>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {(categories ?? []).map((c) => (
            <Card key={c.id} padding="md" hover className="group flex flex-col">
              <div className="flex items-start gap-3">
                <div className="h-12 w-12 flex-shrink-0 overflow-hidden rounded-md border border-border bg-surface-2">
                  {c.icon_url ? (
                    <img src={c.icon_url} alt="" className="h-full w-full object-cover" />
                  ) : (
                    <div className="flex h-full w-full items-center justify-center text-text-muted">
                      <FolderTree className="h-5 w-5" />
                    </div>
                  )}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <h3 className="truncate text-sm font-semibold text-text-primary">{c.name}</h3>
                    {c.is_active ? <Badge tone="success">Active</Badge> : <Badge tone="neutral">Hidden</Badge>}
                  </div>
                  <p className="mt-0.5 flex items-center gap-1 text-[10px] text-text-muted">
                    <GripVertical className="h-3 w-3" />
                    Order: {c.sort_order} · {c.series_count ?? 0} series
                  </p>
                </div>
              </div>
              {c.description && (
                <p className="mt-3 line-clamp-2 flex-1 text-xs text-text-secondary">{c.description}</p>
              )}
              <div className="mt-4 flex items-center justify-end gap-1 border-t border-border pt-3">
                <Button
                  variant="ghost"
                  size="sm"
                  leftIcon={<Pencil className="h-3.5 w-3.5" />}
                  onClick={() => openEdit(c)}
                >
                  Edit
                </Button>
                <Button
                  variant="ghost"
                  size="icon"
                  title="Delete"
                  onClick={() => setDeleteItem(c)}
                >
                  <Trash2 className="h-4 w-4 text-danger" />
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}

      <Modal
        open={open}
        onClose={() => setOpen(false)}
        title={editItem ? 'Edit Category' : 'Add Category'}
        size="lg"
      >
        <CategoryForm
          initial={editItem}
          onCancel={() => setOpen(false)}
          onSaved={() => setOpen(false)}
        />
      </Modal>

      <ConfirmDialog
        open={!!deleteItem}
        title="Delete Category?"
        description={`"${deleteItem?.name}" will be removed. Series assigned to it may need re-categorization.`}
        confirmLabel="Delete"
        onConfirm={() => deleteItem && deleteMutation.mutate(deleteItem)}
        onCancel={() => setDeleteItem(null)}
        loading={deleteMutation.isPending}
      />
    </div>
  )
}
