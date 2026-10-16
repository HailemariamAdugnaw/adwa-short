import { ArrowDownRight, ArrowUpRight, Minus } from 'lucide-react'
import { Card } from './Card'
import { cn } from '../../lib/cn'

export function StatCard({
  label,
  value,
  icon,
  delta,
  deltaSuffix = '%',
  hint,
  accent,
  loading,
}) {
  const isUp = typeof delta === 'number' && delta > 0
  const isDown = typeof delta === 'number' && delta < 0
  const isFlat = typeof delta === 'number' && delta === 0

  return (
    <Card padding="md" className={cn('relative overflow-hidden', accent && 'border-accent-border')}>
      {accent && (
        <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-accent to-transparent" />
      )}
      <div className="flex items-start justify-between">
        <div className="min-w-0">
          <p className="text-[11px] font-semibold uppercase tracking-wider text-text-secondary">
            {label}
          </p>
          {loading ? (
            <div className="skeleton mt-2 h-7 w-28 rounded" />
          ) : (
            <p className={cn('mt-1 text-2xl font-bold text-text-primary tabular-nums')}>{value}</p>
          )}
          {(typeof delta === 'number' || hint) && (
            <div className="mt-2 flex items-center gap-1.5 text-xs">
              {typeof delta === 'number' && (
                <span
                  className={cn(
                    'inline-flex items-center gap-0.5 rounded-full px-1.5 py-0.5 font-medium',
                    isUp && 'bg-success-soft text-success',
                    isDown && 'bg-danger-soft text-danger',
                    isFlat && 'bg-surface-2 text-text-muted',
                  )}
                >
                  {isUp && <ArrowUpRight className="h-3 w-3" />}
                  {isDown && <ArrowDownRight className="h-3 w-3" />}
                  {isFlat && <Minus className="h-3 w-3" />}
                  {Math.abs(delta)}
                  {deltaSuffix}
                </span>
              )}
              {hint && <span className="text-text-muted">{hint}</span>}
            </div>
          )}
        </div>
        {icon && (
          <div className={cn('rounded-md border p-2', accent ? 'bg-accent-soft border-accent-border text-accent' : 'bg-surface-2 border-border text-text-secondary')}>
            {icon}
          </div>
        )}
      </div>
    </Card>
  )
}
