import { forwardRef } from 'react'
import { cn } from '../../lib/cn'

export const Textarea = forwardRef(
  ({ label, hint, error, className, containerClassName, id, ...props }, ref) => {
    const textareaId = id || props.name
    return (
      <div className={cn('w-full', containerClassName)}>
        {label && (
          <label htmlFor={textareaId} className="mb-1.5 block text-xs font-medium uppercase tracking-wide text-text-secondary">
            {label}
          </label>
        )}
        <textarea
          ref={ref}
          id={textareaId}
          className={cn('input-base min-h-[96px] resize-y', error && 'border-danger', className)}
          {...props}
        />
        {error ? (
          <p className="mt-1 text-xs text-danger">{error}</p>
        ) : hint ? (
          <p className="mt-1 text-xs text-text-muted">{hint}</p>
        ) : null}
      </div>
    )
  },
)

Textarea.displayName = 'Textarea'
