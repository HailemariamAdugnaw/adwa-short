import { NavLink } from 'react-router-dom'
import {
  LayoutDashboard,
  Film,
  ListVideo,
  FolderTree,
  Coins,
  Clock,
  CreditCard,
  Megaphone,
  Award,
  Users,
  HandCoins,
  BarChart3,
  Settings,
  Clapperboard,
  UserCircle,
  TrendingUp,
  Receipt,
  MessageSquare,
  ShieldCheck,
  History,
  X,
} from 'lucide-react'
import { cn } from '../../lib/cn'
import { useAuthStore } from '../../lib/store'
import { isSuperAdmin as checkSuperAdmin } from '../../lib/rbac'
import { Badge } from '../ui/Badge'

const NAV = [
  {
    label: 'Dashboard',
    superAdminOnly: true,
    items: [{ to: '/', label: 'Overview', icon: LayoutDashboard, end: true }],
  },
  {
    label: 'Content',
    items: [
      { to: '/content/series', label: 'Series', icon: Film },
      { to: '/content/episodes', label: 'Episodes', icon: ListVideo },
      { to: '/categories', label: 'Categories', icon: FolderTree },
    ],
  },
  {
    label: 'Creators',
    superAdminOnly: true,
    items: [{ to: '/creators', label: 'Creators List', icon: UserCircle }],
  },
  {
    label: 'Monetization',
    superAdminOnly: true,
    items: [
      { to: '/monetization/coins', label: 'Coin Packages', icon: Coins },
      { to: '/monetization/passes', label: 'Time Passes', icon: Clock },
      { to: '/monetization/subscriptions', label: 'Subscriptions', icon: CreditCard },
      { to: '/monetization/ad-unlock', label: 'Ad-Unlock Rule', icon: Megaphone },
      { to: '/monetization/loyalty', label: 'Loyalty Config', icon: Award },
    ],
  },
  {
    label: 'Revenue',
    superAdminOnly: true,
    items: [
      { to: '/revenue', label: 'Overview', icon: TrendingUp, end: true },
      { to: '/revenue/by-creator', label: 'By Creator', icon: Users },
      { to: '/revenue/by-content', label: 'By Content', icon: BarChart3 },
      { to: '/revenue/transactions', label: 'Transactions', icon: Receipt },
    ],
  },
  {
    label: 'Users',
    superAdminOnly: true,
    items: [
      { to: '/users', label: 'User List', icon: Users },
      { to: '/walkin/manual-deposit', label: 'Walk-in Deposit', icon: HandCoins, superAdminOnly: true },
    ],
  },
  {
    label: 'Reviews',
    superAdminOnly: true,
    items: [{ to: '/reviews', label: 'Reviews', icon: MessageSquare }],
  },
  {
    label: 'Analytics',
    superAdminOnly: true,
    items: [{ to: '/analytics/content', label: 'Content Performance', icon: BarChart3 }],
  },
  {
    label: 'Administration',
    superAdminOnly: true,
    items: [
      { to: '/staff', label: 'Staff Management', icon: ShieldCheck, superAdminOnly: true },
      { to: '/staff/activity', label: 'Staff Activity Log', icon: History, superAdminOnly: true },
    ],
  },
  {
    label: 'System',
    superAdminOnly: true,
    items: [{ to: '/settings', label: 'Settings', icon: Settings, superAdminOnly: true }],
  },
]

export function Sidebar({ onNavigate, onClose }) {
  const user = useAuthStore((s) => s.user)
  const isSuperAdmin = checkSuperAdmin(user)

  const filteredNav = NAV.map((group) => {
    if (group.superAdminOnly && !isSuperAdmin) return null
    const visibleItems = group.items.filter((item) => !item.superAdminOnly || isSuperAdmin)
    if (visibleItems.length === 0) return null
    return { ...group, items: visibleItems }
  }).filter(Boolean)
  return (
    <aside className="flex h-full w-full lg:w-64 flex-col border-r border-border bg-[#0e0e12]">
      <div className="flex h-16 items-center justify-between border-b border-border px-5">
        <div className="flex items-center gap-2.5">
          <div className="flex h-9 w-9 items-center justify-center rounded-md bg-accent shadow-[0_0_18px_-4px_rgba(200,16,46,0.8)]">
            <Clapperboard className="h-5 w-5 text-white" />
          </div>
          <div className="leading-tight">
            <p className="text-sm font-extrabold tracking-wider text-text-primary">
              ADWA <span className="text-accent">SHORT</span>
            </p>
            <p className="text-[10px] uppercase tracking-widest text-text-muted">Admin Console</p>
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

      <nav className="flex-1 overflow-y-auto px-3 py-4">
        {filteredNav.map((group) => (
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
                        ? 'bg-accent-soft text-text-primary border border-accent-border'
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

      <div className="border-t border-border px-5 py-3">
        <div className="mb-1.5 flex items-center justify-between">
          <span className="text-[10px] text-text-muted font-medium">Console Access</span>
          <Badge tone={isSuperAdmin ? 'accent' : 'neutral'}>
            {isSuperAdmin ? 'Super Admin' : 'Staff'}
          </Badge>
        </div>
        <p className="text-[10px] text-text-muted">
          v1.0.0 · ADWA SHORT Ops
          <br />
          <span className="text-text-secondary">© 2025 Adwa Studios</span>
        </p>
      </div>
    </aside>
  )
}
