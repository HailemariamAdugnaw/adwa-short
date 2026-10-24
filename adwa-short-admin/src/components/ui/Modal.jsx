import { useEffect } from 'react'
import { createPortal } from 'react-dom'
import { X } from 'lucide-react'
import { cn } from '../../lib/cn'

const SIZES = {
  sm: 'max-w-md',
  md: 'max-w-lg',
  lg: 'max-w-2xl',
  xl: 'max-w-4xl',
}

export function Modal({
  open,
  onClose,
  title,
  description,
  children,
  footer,
  size = 'md',
  closeOnBackdrop = true,
}) {
  useEffect(() => {
    if (!open) return
    const onEsc = (e) => {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', onEsc)
    document.body.style.overflow = 'hidden'
    return () => {
      document.removeEventListener('keydown', onEsc)
      document.body.style.overflow = ''
    }
  }, [open, onClose])

  if (!open) return null

  return createPortal(
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fade-in"
      onMouseDown={(e) => closeOnBackdrop && e.target === e.currentTarget && onClose()}
    >
      <div className="absolute inset-0 bg-black/75 backdrop-blur-sm" />
      <div
        role="dialog"
        aria-modal="true"
        className={cn(
          'relative z-10 w-full card-surface flex flex-col max-h-[90vh] overflow-hidden shadow-2xl',
          SIZES[size],
        )}
      >
        <header className="flex items-start justify-between gap-4 border-b border-border px-5 py-4">
          <div>
            {title && <h2 className="text-base font-semibold text-text-primary">{title}</h2>}
            {description && <p className="mt-0.5 text-xs text-text-secondary">{description}</p>}
          </div>
          <button
            onClick={onClose}
            className="rounded-md p-1 text-text-muted hover:bg-surface-2 hover:text-text-primary transition-colors"
            aria-label="Close"
          >
            <X className="h-5 w-5" />
          </button>
        </header>

        <div className="flex-1 overflow-y-auto px-5 py-4">{children}</div>

        {footer && (
          <footer className="flex items-center justify-end gap-2 border-t border-border bg-surface-2/30 px-5 py-3">
            {footer}
          </footer>
        )}
      </div>
    </div>,
    document.body,
  )
}
