import { NavLink } from 'react-router-dom'
import {
  LayoutDashboard,
  Film,
  MessageSquare,
  Wallet,
  UserCircle,
  Clapperboard,
  Sparkles,
  LogOut,
  ExternalLink,
  X,
} from 'lucide-react'
import { cn } from '../../lib/cn'
import { useAuthStore } from '../../lib/store'
import { Badge } from '../ui/Badge'
import { useCreatorPortalProfile } from '../../lib/hooks'

const CREATOR_NAV = [
  {
    label: 'Overview',
    items: [
      { to: '/creator/dashboard', label: 'Creator Studio', icon: LayoutDashboard, end: true },
    ],
  },
  {
    label: 'Content & Audience',
    items: [
      { to: '/creator/content', label: 'My Content & Analytics', icon: Film },
      { to: '/creator/reviews', label: 'Audience Reviews', icon: MessageSquare },
    ],
  },
  {
    label: 'Finances',
    items: [
      { to: '/creator/financials', label: 'Earnings & Payouts', icon: Wallet },
    ],
  },
  {
    label: 'Account & Contract',
    items: [
      { to: '/creator/profile', label: 'Profile & Contract', icon: UserCircle },
    ],
  },
]

export function CreatorSidebar({ onNavigate, onClose }) {
  const user = useAuthStore((s) => s.user)
  const logout = useAuthStore((s) => s.logout)
  const { data: profile } = useCreatorPortalProfile()

  const splitPct = profile?.default_revenue_split_pct ?? 50.0

  const handleLogout = () => {
    logout()
    window.location.href = '/login'
  }

  return (
    <aside className="flex h-full w-full lg:w-64 flex-col border-r border-border bg-[#0e0e12]">
      <div className="flex h-16 items-center justify-between border-b border-border px-5">
        <div className="flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-md bg-accent shadow-[0_0_24px_-4px_rgba(200,16,46,0.7)]">
            <Clapperboard className="h-5 w-5 text-white" />
          </div>
          <div className="leading-tight">
            <p className="text-sm font-extrabold tracking-wider text-white">
              ADWA <span className="text-accent">SHORT</span>
            </p>
            <div className="flex items-center gap-1.5 mt-0.5">
              <span className="text-[9px] uppercase tracking-widest font-bold text-amber-400">Creator Studio</span>
              <Sparkles className="h-2.5 w-2.5 text-amber-400" />
            </div>
          </div>
        </div>
        {onClose && (
          <button
            type="button"
            onClick={onClose}
            aria-label="Close navigation"
            className="rounded-lg p-1.5 text-text-muted hover:bg-surface-2 hover:text-text-primary lg:hidden"
          >
            <X className="h-5 w-5" />
          </button>
        )}
      </div>

      <div className="p-3">
        <div className="rounded-lg border border-amber-500/20 bg-amber-500/10 p-2.5 text-[11px] text-amber-200">
          <div className="flex items-center justify-between font-semibold">
            <span>Verified Creator</span>
            <Badge tone="accent">{splitPct}% Net Split</Badge>
          </div>
          <p className="mt-1 text-[10px] text-text-muted">
            {profile?.display_name || user?.display_name || 'Creator Account'}
          </p>
        </div>
      </div>

      <nav className="flex-1 overflow-y-auto px-3 py-2">
        {CREATOR_NAV.map((group) => (
          <div key={group.label} className="mb-5">
            <p className="mb-1.5 px-3 text-[10px] font-semibold uppercase tracking-widest text-text-muted">
              {group.label}
            </p>
            <div className="space-y-0.5">
              {group.items.map((item) => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  end={item.end}
                  onClick={onNavigate}
                  className={({ isActive }) =>
                    cn(
                      'group flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-all',
                      isActive
                        ? 'bg-accent-soft text-text-primary border border-accent-border font-semibold shadow-sm'
                        : 'text-text-secondary hover:bg-surface-2 hover:text-text-primary border border-transparent',
                    )
                  }
                >
                  {({ isActive }) => (
                    <>
                      <item.icon
                        className={cn(
                          'h-4 w-4 transition-colors',
                          isActive ? 'text-accent' : 'text-text-muted group-hover:text-text-secondary',
                        )}
                      />
                      <span className="flex-1">{item.label}</span>
                      {isActive && <span className="h-1.5 w-1.5 rounded-full bg-accent" />}
                    </>
                  )}
                </NavLink>
              ))}
            </div>
          </div>
        ))}
      </nav>

      <div className="border-t border-border px-4 py-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2.5 overflow-hidden">
            <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-surface-2 text-xs font-bold text-accent border border-border">
              {(profile?.display_name || user?.display_name || 'C')[0].toUpperCase()}
            </div>
            <div className="min-w-0">
              <p className="truncate text-xs font-semibold text-text-primary">
                {profile?.display_name || user?.display_name || 'Creator'}
              </p>
              <p className="truncate text-[10px] text-text-muted">
                {profile?.email || user?.email || 'creator@adwashort.com'}
              </p>
            </div>
          </div>
          <button
            onClick={handleLogout}
            title="Sign Out"
            className="flex h-7 w-7 items-center justify-center rounded-md text-text-muted hover:bg-surface-2 hover:text-accent transition-colors"
          >
            <LogOut className="h-3.5 w-3.5" />
          </button>
        </div>
      </div>
    </aside>
  )
}
