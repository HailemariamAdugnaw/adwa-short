import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useState } from 'react'
import { Sidebar } from './Sidebar'
import { Topbar } from './Topbar'
import { useAuthStore } from '../../lib/store'

export function AdminLayout() {
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated)
  const location = useLocation()
  const [mobileNav, setMobileNav] = useState(false)

  if (!isAuthenticated) {
    return <Navigate to="/login" replace state={{ from: location }} />
  }

  return (
    <div className="flex h-screen overflow-hidden bg-base">
      <div className="hidden lg:block">
        <Sidebar />
      </div>

      {mobileNav && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <div className="absolute inset-0 bg-black/70" onClick={() => setMobileNav(false)} />
          <div className="absolute left-0 top-0 h-full animate-fade-in">
            <Sidebar onNavigate={() => setMobileNav(false)} />
          </div>
        </div>
      )}

      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar onMenu={() => setMobileNav(true)} />
        <main className="flex-1 overflow-y-auto">
          <div className="mx-auto max-w-[1600px] px-4 py-6 lg:px-8 lg:py-8">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  )
}
