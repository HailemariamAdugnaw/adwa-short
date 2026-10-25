import { useState } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import {
  Search,
  Bell,
  Menu,
  LogOut,
  ChevronDown,
  User as UserIcon,
  Settings as SettingsIcon,
  ShieldCheck,
} from 'lucide-react'
import { useAuthStore } from '../../lib/store'
import { isSuperAdmin as checkSuperAdmin } from '../../lib/rbac'
import { initials } from '../../lib/format'
import { cn } from '../../lib/cn'

const PAGE_TITLES = {
  '/': 'Dashboard',
  '/content/series': 'Content · Series',
  '/content/episodes': 'Content · Episodes',
  '/categories': 'Categories',
  '/monetization/coins': 'Monetization · Coins',
  '/monetization/passes': 'Monetization · Time Passes',
  '/monetization/subscriptions': 'Monetization · Subscriptions',
  '/monetization/ad-unlock': 'Monetization · Ad-Unlock',
  '/monetization/loyalty': 'Monetization · Loyalty',
  '/users': 'Users',
  '/walkin/manual-deposit': 'Walk-in Center · Manual Deposit',
  '/analytics/content': 'Analytics · Content',
  '/staff': 'Administration · Staff Management',
  '/staff/activity': 'Administration · Staff Activity Log',
  '/creator/dashboard': 'Creator Studio · Overview',
  '/creator/content': 'Creator Studio · My Content & Analytics',
  '/creator/reviews': 'Creator Studio · Audience Reviews',
  '/creator/financials': 'Creator Studio · Financials & Payouts',
  '/creator/profile': 'Creator Studio · Profile & Contract',
  '/settings': 'Settings',
}

export function Topbar({ onMenu }) {
  const { user, logout } = useAuthStore()
  const navigate = useNavigate()
  const location = useLocation()
  const [menuOpen, setMenuOpen] = useState(false)

  const isSuperAdmin = checkSuperAdmin(user)
  const displayName = user?.display_name || user?.name || (isSuperAdmin ? 'Super Admin' : 'Staff Member')

  const matched = Object.entries(PAGE_TITLES).find(([path]) =>
    path === '/' ? location.pathname === '/' : location.pathname.startsWith(path),
  )
  const title = matched?.[1] ?? 'Admin'

  const handleLogout = () => {
    logout()
    navigate('/login')
  }

  return (
    <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-border bg-base/95 px-4 backdrop-blur supports-[backdrop-filter]:bg-base/80 lg:px-6">
      <button
        onClick={onMenu}
        className="rounded-md p-2 text-text-secondary hover:bg-surface-2 hover:text-text-primary lg:hidden"
      >
        <Menu className="h-5 w-5" />
      </button>

      <div className="min-w-0 flex-1">
        <h1 className="truncate text-sm font-semibold text-text-primary">{title}</h1>
        <p className="hidden text-[11px] text-text-muted sm:block">
          Operations console · {new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' })}
        </p>
      </div>

      <div className="relative hidden md:block">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
        <input
          placeholder="Search users, series…"
          className="input-base w-72 pl-9 pr-3 h-9 text-sm"
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              const q = e.target.value.trim()
              if (q) navigate(`/users?q=${encodeURIComponent(q)}`)
            }
          }}
        />
      </div>

      <button className="relative rounded-md p-2 text-text-secondary hover:bg-surface-2 hover:text-text-primary">
        <Bell className="h-5 w-5" />
        <span className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full bg-accent ring-2 ring-base" />
      </button>

      <div className="relative">
        <button
          onClick={() => setMenuOpen((s) => !s)}
          onBlur={() => setTimeout(() => setMenuOpen(false), 150)}
          className="flex items-center gap-2 rounded-md border border-border bg-surface-2 py-1 pl-1 pr-2 hover:bg-surface-3 transition-colors"
        >
          <div className="flex h-7 w-7 items-center justify-center rounded-md bg-accent text-xs font-bold text-white">
            {initials(displayName, user?.phone || user?.email)}
          </div>
          <div className="hidden text-left leading-tight sm:block">
            <p className="text-xs font-semibold text-text-primary">{displayName}</p>
            <p className="text-[10px] uppercase tracking-wider text-text-muted">{isSuperAdmin ? 'Super Admin' : 'Staff'}</p>
          </div>
          <ChevronDown className={cn('h-4 w-4 text-text-muted transition-transform', menuOpen && 'rotate-180')} />
        </button>

        {menuOpen && (
          <div className="absolute right-0 top-12 w-56 card-surface overflow-hidden p-1 shadow-2xl animate-fade-in">
            <div className="border-b border-border px-3 py-2">
              <p className="text-xs font-semibold text-text-primary">{displayName}</p>
              <p className="truncate text-[11px] text-text-secondary">{user?.email || user?.phone}</p>
              <span className="mt-1 inline-block rounded bg-surface-2 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider text-accent">
                {isSuperAdmin ? 'Super Admin' : 'Staff Member'}
              </span>
            </div>
            {isSuperAdmin && (
              <button
                onMouseDown={() => navigate('/staff')}
                className="flex w-full items-center gap-2 rounded-md px-3 py-2 text-sm text-text-secondary hover:bg-surface-2 hover:text-text-primary"
              >
                <ShieldCheck className="h-4 w-4 text-accent" />
                Staff Management
              </button>
            )}
            {isSuperAdmin && (
              <button
                onMouseDown={() => navigate('/settings')}
                className="flex w-full items-center gap-2 rounded-md px-3 py-2 text-sm text-text-secondary hover:bg-surface-2 hover:text-text-primary"
              >
                <SettingsIcon className="h-4 w-4" />
                Settings
              </button>
            )}
            <button
              onMouseDown={() => navigate('/content/series')}
              className="flex w-full items-center gap-2 rounded-md px-3 py-2 text-sm text-text-secondary hover:bg-surface-2 hover:text-text-primary"
            >
              <UserIcon className="h-4 w-4" />
              Content Console
            </button>
            <div className="my-1 border-t border-border" />
            <button
              onMouseDown={handleLogout}
              className="flex w-full items-center gap-2 rounded-md px-3 py-2 text-sm text-danger hover:bg-danger-soft"
            >
              <LogOut className="h-4 w-4" />
              Sign Out
            </button>
          </div>
        )}
      </div>
    </header>
  )
}
