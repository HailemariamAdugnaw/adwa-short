import { useState } from 'react'
import { AlertTriangle } from 'lucide-react'
import { Modal } from './Modal'
import { Button } from './Button'

export function ConfirmDialog({
  open,
  title,
  description,
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  variant = 'danger',
  onConfirm,
  onCancel,
  loading,
}) {
  const [busy, setBusy] = useState(false)
  const handleConfirm = async () => {
    try {
      setBusy(true)
      await onConfirm()
    } finally {
      setBusy(false)
    }
  }
  return (
    <Modal
      open={open}
      onClose={onCancel}
      title={title}
      size="sm"
      footer={
        <>
          <Button variant="ghost" onClick={onCancel} disabled={busy || loading}>
            {cancelLabel}
          </Button>
          <Button
            variant={variant === 'danger' ? 'danger' : variant === 'warning' ? 'primary' : 'primary'}
            onClick={handleConfirm}
            loading={busy || loading}
          >
            {confirmLabel}
          </Button>
        </>
      }
    >
      <div className="flex items-start gap-3">
        <div className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full bg-danger-soft text-danger">
          <AlertTriangle className="h-5 w-5" />
        </div>
        {description && <p className="text-sm text-text-secondary">{description}</p>}
      </div>
    </Modal>
  )
}
