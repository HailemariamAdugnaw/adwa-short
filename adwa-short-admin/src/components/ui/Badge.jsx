import { cn } from '../../lib/cn'

const TONES = {
  neutral: 'bg-surface-2 text-text-secondary border-border',
  accent: 'bg-accent-soft text-accent border-accent-border',
  success: 'bg-success-soft text-success border-success/40',
  warning: 'bg-warning-soft text-warning border-warning/40',
  danger: 'bg-danger-soft text-danger border-danger/40',
  info: 'bg-surface-2 text-text-primary border-border-strong',
  vip: 'bg-accent-soft text-accent border-accent-border font-semibold',
  exclusive: 'bg-warning-soft text-warning border-warning/40 font-semibold',
}

export function Badge({ tone = 'neutral', children, className, icon }) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wider',
        TONES[tone],
        className,
      )}
    >
      {icon}
      {children}
    </span>
  )
}

export const VIPBadge = ({ className }) => (
  <Badge tone="vip" className={className}>VIP</Badge>
)
export const ExclusiveBadge = ({ className }) => (
  <Badge tone="exclusive" className={className}>Exclusive</Badge>
)
export const PublishedBadge = ({ className }) => (
  <Badge tone="success" className={className}>Published</Badge>
)
export const PendingBadge = ({ className }) => (
  <Badge tone="warning" className={className}>Pending</Badge>
)
export const HotBadge = ({ className }) => (
  <Badge tone="accent" className={className}>Hot</Badge>
)
export const NewBadge = ({ className }) => (
  <Badge tone="info" className={className}>New</Badge>
)
