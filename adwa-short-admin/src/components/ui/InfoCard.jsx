import { useState } from 'react'
import { Info, ChevronDown, ChevronUp } from 'lucide-react'
import { cn } from '../../lib/cn'

export function InfoCard({
  title,
  items = [],
  icon: Icon = Info,
  className,
  collapsible = true,
  defaultExpanded = false,
  previewCount = 1,
}) {
  const [expanded, setExpanded] = useState(defaultExpanded)
  const hasItems = Array.isArray(items) && items.length > 0
  const canCollapse = collapsible && hasItems && items.length > previewCount

  const visibleItems = canCollapse && !expanded ? items.slice(0, previewCount) : (items ?? [])

  return (
    <div
      className={cn(
        'rounded-lg border border-accent/30 bg-surface p-4 sm:p-5',
        'shadow-[0_0_24px_-12px_rgba(200,16,46,0.35)] transition-all',
        className,
      )}
    >
      <div className="flex items-center justify-between gap-3 border-b border-accent/20 pb-3">
        <div className="flex items-center gap-2">
          <span className="flex h-7 w-7 items-center justify-center rounded-md bg-accent-soft text-accent">
            <Icon className="h-4 w-4" />
          </span>
          <h3 className="text-sm font-semibold uppercase tracking-wide text-text-primary">
            {title}
          </h3>
        </div>

        {canCollapse && (
          <button
            type="button"
            onClick={() => setExpanded((prev) => !prev)}
            aria-expanded={expanded}
            className="flex items-center gap-1.5 rounded-md border border-accent/30 bg-accent/10 px-2.5 py-1 text-xs font-semibold text-accent hover:bg-accent hover:text-white transition-colors cursor-pointer"
          >
            <span>{expanded ? 'Read Less' : 'Read More'}</span>
            {expanded ? (
              <ChevronUp className="h-3.5 w-3.5" />
            ) : (
              <ChevronDown className="h-3.5 w-3.5" />
            )}
          </button>
        )}
      </div>

      <ul className="mt-3 space-y-2">
        {visibleItems.map((text, i) => (
          <li key={i} className="flex items-start gap-2 text-xs leading-relaxed text-text-secondary">
            <span className="mt-1.5 h-1 w-1 shrink-0 rounded-full bg-accent" />
            <span>{text}</span>
          </li>
        ))}
      </ul>

      {canCollapse && !expanded && (
        <div className="mt-3 flex items-center justify-between border-t border-accent/10 pt-2.5">
          <span className="text-[11px] text-text-muted">
            +{items.length - previewCount} more platform rules & guidelines
          </span>
          <button
            type="button"
            onClick={() => setExpanded(true)}
            className="text-xs font-semibold text-accent hover:text-accent-hover transition-colors cursor-pointer"
          >
            Read More →
          </button>
        </div>
      )}
    </div>
  )
}
