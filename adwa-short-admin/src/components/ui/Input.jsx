import { forwardRef } from 'react'
import { cn } from '../../lib/cn'

export const Input = forwardRef(
  ({ label, hint, error, leftIcon, rightIcon, className, containerClassName, id, ...props }, ref) => {
    const inputId = id || props.name
    return (
      <div className={cn('w-full', containerClassName)}>
        {label && (
          <label htmlFor={inputId} className="mb-1.5 block text-xs font-medium uppercase tracking-wide text-text-secondary">
            {label}
          </label>
        )}
        <div className="relative">
          {leftIcon && (
            <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-text-muted">
              {leftIcon}
            </span>
          )}
          <input
            ref={ref}
            id={inputId}
            className={cn(
              'input-base',
              leftIcon && 'pl-9',
              rightIcon && 'pr-9',
              error && 'border-danger focus:border-danger focus:shadow-[0_0_0_3px_rgba(220,38,38,0.18)]',
              className,
            )}
            {...props}
          />
          {rightIcon && (
            <span className="absolute right-3 top-1/2 -translate-y-1/2 text-text-muted">{rightIcon}</span>
          )}
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

Input.displayName = 'Input'
