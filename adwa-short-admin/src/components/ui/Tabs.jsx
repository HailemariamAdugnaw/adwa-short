import { useState } from 'react'
import { cn } from '../../lib/cn'

export function Tabs({ items, defaultId, value, onChange, className }) {
  const itemsArr = Array.isArray(items) ? items : []
  const [internal, setInternal] = useState(defaultId ?? itemsArr[0]?.id)
  const active = value ?? internal

  const setActive = (id) => {
    if (onChange) onChange(id)
    else setInternal(id)
  }

  return (
    <div className={className}>
      <div className="flex items-center gap-1 border-b border-border overflow-x-auto">
        {itemsArr.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActive(tab.id)}
            className={cn(
              'relative flex items-center gap-2 whitespace-nowrap px-4 py-2.5 text-sm font-medium transition-colors',
              active === tab.id
                ? 'text-text-primary'
                : 'text-text-secondary hover:text-text-primary',
            )}
          >
            {tab.icon}
            {tab.label}
            {tab.badge}
            {active === tab.id && (
              <span className="absolute inset-x-0 -bottom-px h-0.5 bg-accent" />
            )}
          </button>
        ))}
      </div>
      <div className="pt-4">
        {itemsArr.find((t) => t.id === active)?.content}
      </div>
    </div>
  )
}
