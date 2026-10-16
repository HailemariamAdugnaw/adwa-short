import { forwardRef } from 'react'
import { Loader2 } from 'lucide-react'
import { cn } from '../../lib/cn'

const VARIANTS = {
  primary:
    'bg-accent text-white hover:bg-accent-hover border border-transparent shadow-[0_0_0_1px_rgba(200,16,46,0.4)] hover:shadow-[0_0_18px_-4px_rgba(200,16,46,0.6)]',
  secondary:
    'bg-surface-2 text-text-primary hover:bg-surface-3 border border-border hover:border-border-strong',
  outline:
    'bg-transparent text-text-primary hover:bg-surface-2 border border-border hover:border-border-strong',
  ghost:
    'bg-transparent text-text-secondary hover:text-text-primary hover:bg-surface-2 border border-transparent',
  danger:
    'bg-danger/90 text-white hover:bg-danger border border-transparent',
  success:
    'bg-success text-white hover:bg-success/90 border border-transparent',
}

const SIZES = {
  sm: 'h-8 px-3 text-xs gap-1.5',
  md: 'h-9 px-4 text-sm gap-2',
  lg: 'h-11 px-6 text-base gap-2',
  icon: 'h-9 w-9 p-0',
}

export const Button = forwardRef(
  (
    {
      className,
      variant = 'primary',
      size = 'md',
      loading,
      leftIcon,
      rightIcon,
      fullWidth,
      disabled,
      children,
      ...props
    },
    ref,
  ) => {
    return (
      <button
        ref={ref}
        disabled={disabled || loading}
        className={cn(
          'inline-flex items-center justify-center rounded-md font-medium transition-all',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/60 focus-visible:ring-offset-1 focus-visible:ring-offset-base',
          'disabled:opacity-50 disabled:pointer-events-none active:scale-[0.98]',
          VARIANTS[variant],
          SIZES[size],
          fullWidth && 'w-full',
          className,
        )}
        {...props}
      >
        {loading ? (
          <Loader2 className="h-4 w-4 animate-spin" />
        ) : (
          leftIcon
        )}
        {children}
        {!loading && rightIcon}
      </button>
    )
  },
)

Button.displayName = 'Button'
