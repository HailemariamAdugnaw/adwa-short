import { cn } from '../../lib/cn'

export function Table({ children, className }) {
  return (
    <div className={cn('w-full overflow-x-auto', className)}>
      <table className="w-full border-collapse text-sm">{children}</table>
    </div>
  )
}

export function THead({ children }) {
  return (
    <thead className="border-b border-border">
      <tr className="bg-surface-2/40">{children}</tr>
    </thead>
  )
}

export function TBody({ children }) {
  return <tbody className="divide-y divide-border">{children}</tbody>
}

export function TH({ children, className, ...props }) {
  return (
    <th
      className={cn(
        'px-4 py-3 text-left text-[11px] font-semibold uppercase tracking-wider text-text-secondary whitespace-nowrap',
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
      className={cn('transition-colors hover:bg-surface-2/30 group', className)}
      {...props}
    >
      {children}
    </tr>
  )
}

export function TD({ children, className, ...props }) {
  return (
    <td className={cn('px-4 py-3 align-middle text-text-primary', className)} {...props}>
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
        <tr key={i} className="border-b border-border">
          <td colSpan={colSpan} className="px-4 py-3">
            <div className="skeleton h-6 w-full rounded" />
          </td>
        </tr>
      ))}
    </>
  )
}
