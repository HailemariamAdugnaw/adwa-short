import { ChevronLeft, ChevronRight } from 'lucide-react'
import { Button } from './Button'
import { cn } from '../../lib/cn'

export function Pagination({ page, pages, total, pageSize, onChange, className }) {
  if (pages <= 1 && !total) return null

  const from = total ? (page - 1) * (pageSize ?? 0) + 1 : 0
  const to = total ? Math.min(page * (pageSize ?? 0), total) : 0

  return (
    <div className={cn('flex items-center justify-between gap-4 px-1 py-3', className)}>
      <p className="text-xs text-text-secondary">
        {total ? (
          <>
            Showing <span className="text-text-primary">{from}</span>–
            <span className="text-text-primary">{to}</span> of{' '}
            <span className="text-text-primary">{total}</span>
          </>
        ) : (
          <>
            Page <span className="text-text-primary">{page}</span> of{' '}
            <span className="text-text-primary">{pages}</span>
          </>
        )}
      </p>
      <div className="flex items-center gap-1">
        <Button
          variant="outline"
          size="sm"
          disabled={page <= 1}
          onClick={() => onChange(page - 1)}
          leftIcon={<ChevronLeft className="h-4 w-4" />}
        >
          Prev
        </Button>
        <div className="flex items-center gap-1">
          {buildPageList(page, pages).map((p, i) =>
            p === '...' ? (
              <span key={`gap-${i}`} className="px-2 text-text-muted">
                …
              </span>
            ) : (
              <button
                key={p}
                onClick={() => onChange(p)}
                className={cn(
                  'h-8 min-w-8 rounded-md px-2 text-xs font-medium transition-colors',
                  p === page
                    ? 'bg-accent text-white'
                    : 'bg-surface-2 text-text-secondary hover:bg-surface-3 hover:text-text-primary',
                )}
              >
                {p}
              </button>
            ),
          )}
        </div>
        <Button
          variant="outline"
          size="sm"
          disabled={page >= pages}
          onClick={() => onChange(page + 1)}
          rightIcon={<ChevronRight className="h-4 w-4" />}
        >
          Next
        </Button>
      </div>
    </div>
  )
}

function buildPageList(current, total) {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1)
  const out = [1]
  if (current > 3) out.push('...')
  for (let p = Math.max(2, current - 1); p <= Math.min(total - 1, current + 1); p++) {
    out.push(p)
  }
  if (current < total - 2) out.push('...')
  out.push(total)
  return out
}
