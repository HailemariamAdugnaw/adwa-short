import { Info } from 'lucide-react'
import { cn } from '../../lib/cn'

export function InfoCard({ title, items, icon: Icon = Info, className }) {
  return (
    <div
      className={cn(
        'rounded-lg border border-accent/30 bg-surface p-5',
        'shadow-[0_0_24px_-12px_rgba(200,16,46,0.35)]',
        className,
      )}
    >
      <div className="flex items-center gap-2 border-b border-accent/20 pb-3">
        <span className="flex h-7 w-7 items-center justify-center rounded-md bg-accent-soft text-accent">
          <Icon className="h-4 w-4" />
        </span>
        <h3 className="text-sm font-semibold uppercase tracking-wide text-text-primary">
          {title}
        </h3>
      </div>
      <ul className="mt-3 space-y-2">
        {(items ?? []).map((text, i) => (
          <li key={i} className="flex items-start gap-2 text-xs leading-relaxed text-text-secondary">
            <span className="mt-1.5 h-1 w-1 shrink-0 rounded-full bg-accent" />
            <span>{text}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}
