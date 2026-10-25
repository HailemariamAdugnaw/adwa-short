import { cn } from '../../lib/cn'

export function Table({ children, className, containerClassName }) {
  return (
    <div className={cn('w-full overflow-x-auto scrollbar-thin scrollbar-thumb-border/60', containerClassName)}>
      <table className={cn('w-full border-collapse text-left text-sm', className)}>{children}</table>
    </div>
  )
}

export function THead({ children, className }) {
  return (
    <thead className={cn('border-b border-border/80 bg-surface-2/60 text-text-secondary backdrop-blur-sm', className)}>
      {children}
    </thead>
  )
}

export function TBody({ children, className }) {
  return <tbody className={cn('divide-y divide-border/40', className)}>{children}</tbody>
}

export function TH({ children, className, align = 'left', ...props }) {
  const alignClass =
    align === 'right' ? 'text-right' : align === 'center' ? 'text-center' : 'text-left'
  return (
    <th
      className={cn(
        'px-4 py-3.5 text-[11px] font-semibold uppercase tracking-wider text-text-secondary whitespace-nowrap select-none',
        alignClass,
        className,
      )}
      {...props}
    >
      {children}
    </th>
  )
}

export function TR({ children, className, ...props }) {
  return (
    <tr
      className={cn(
        'border-b border-border/40 transition-colors hover:bg-surface-2/40 group last:border-b-0',
        className,
      )}
      {...props}
    >
      {children}
    </tr>
  )
}

export function TD({ children, className, align = 'left', ...props }) {
  const alignClass =
    align === 'right' ? 'text-right' : align === 'center' ? 'text-center' : 'text-left'
  return (
    <td
      className={cn(
        'px-4 py-3.5 align-middle text-text-primary transition-colors',
        alignClass,
        className,
      )}
      {...props}
    >
      {children}
    </td>
  )
}

export function EmptyRow({ colSpan, children }) {
  return (
    <tr>
      <td colSpan={colSpan} className="px-4 py-12 text-center">
        {children}
      </td>
    </tr>
  )
}

export function SkeletonRow({ colSpan, rows = 5 }) {
  return (
    <>
      {Array.from({ length: rows }).map((_, i) => (
        <tr key={i} className="border-b border-border/40">
          <td colSpan={colSpan} className="px-4 py-3.5">
            <div className="skeleton h-6 w-full rounded" />
          </td>
        </tr>
      ))}
    </>
  )
}
