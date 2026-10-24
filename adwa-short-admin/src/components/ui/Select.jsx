import { forwardRef } from 'react'
import { ChevronDown } from 'lucide-react'
import { cn } from '../../lib/cn'

export const Select = forwardRef(
  ({ label, hint, error, options, className, containerClassName, id, children, ...props }, ref) => {
    const selectId = id || props.name
    return (
      <div className={cn('w-full', containerClassName)}>
        {label && (
          <label htmlFor={selectId} className="mb-1.5 block text-xs font-medium uppercase tracking-wide text-text-secondary">
            {label}
          </label>
        )}
        <div className="relative">
          <select
            ref={ref}
            id={selectId}
            className={cn(
              'input-base appearance-none pr-9 cursor-pointer',
              error && 'border-danger',
              className,
            )}
            {...props}
          >
            {children}
            {options?.map((opt) => (
              <option key={opt.value} value={opt.value} className="bg-surface text-text-primary">
                {opt.label}
              </option>
            ))}
          </select>
          <ChevronDown className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
        </div>
        {error ? (
          <p className="mt-1 text-xs text-danger">{error}</p>
        ) : hint ? (
          <p className="mt-1 text-xs text-text-muted">{hint}</p>
        ) : null}
      </div>
    )
  },
)

Select.displayName = 'Select'
