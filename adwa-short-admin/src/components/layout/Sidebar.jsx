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
} from 'lucide-react'
import { cn } from '../../lib/cn'

const NAV = [
  {
    label: 'Dashboard',
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
    items: [{ to: '/creators', label: 'Creators List', icon: UserCircle }],
  },
  {
    label: 'Monetization',
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
    items: [
      { to: '/revenue', label: 'Overview', icon: TrendingUp, end: true },
      { to: '/revenue/by-creator', label: 'By Creator', icon: Users },
      { to: '/revenue/by-content', label: 'By Content', icon: BarChart3 },
      { to: '/revenue/transactions', label: 'Transactions', icon: Receipt },
    ],
  },
  {
    label: 'Users',
    items: [
      { to: '/users', label: 'User List', icon: Users },
      { to: '/walkin/manual-deposit', label: 'Walk-in Deposit', icon: HandCoins },
    ],
  },
  {
    label: 'Reviews',
    items: [{ to: '/reviews', label: 'Reviews', icon: MessageSquare }],
  },
  {
    label: 'Analytics',
    items: [{ to: '/analytics/content', label: 'Content Performance', icon: BarChart3 }],
  },
  {
    label: 'System',
    items: [{ to: '/settings', label: 'Settings', icon: Settings }],
  },
]

export function Sidebar({ onNavigate }) {
  return (
    <aside className="flex h-full w-64 flex-col border-r border-border bg-surface">
      <div className="flex h-16 items-center gap-2.5 border-b border-border px-5">
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

      <nav className="flex-1 overflow-y-auto px-3 py-4">
        {NAV.map((group) => (
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
        <p className="text-[10px] text-text-muted">
          v1.0.0 · ADWA SHORT Ops
          <br />
          <span className="text-text-secondary">© 2025 Adwa Studios</span>
        </p>
      </div>
    </aside>
  )
}
