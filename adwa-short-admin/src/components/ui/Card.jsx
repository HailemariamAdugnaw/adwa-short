import { cn } from '../../lib/cn'

const PADDING = {
  none: '',
  sm: 'p-3',
  md: 'p-5',
  lg: 'p-6',
}

export function Card({ children, className, hover, padding = 'md', ...props }) {
  return (
    <div
      className={cn(
        'card-surface transition-colors',
        hover && 'hover:border-border-strong',
        PADDING[padding],
        className,
      )}
      {...props}
    >
      {children}
    </div>
  )
}

export function CardHeader({ children, className }) {
  return (
    <div className={cn('mb-4 flex items-center justify-between gap-3', className)}>{children}</div>
  )
}

export function CardTitle({ children, className }) {
  return (
    <h3 className={cn('text-sm font-semibold uppercase tracking-wide text-text-secondary', className)}>
      {children}
    </h3>
  )
}

export function CardSection({ children, className }) {
  return <div className={cn('space-y-3', className)}>{children}</div>
}
