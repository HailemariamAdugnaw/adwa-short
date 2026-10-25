import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useState, useEffect } from 'react'
import { Sidebar } from './Sidebar'
import { CreatorSidebar } from './CreatorSidebar'
import { Topbar } from './Topbar'
import { useAuthStore } from '../../lib/store'
import { useMe } from '../../lib/hooks'
import { isCreator } from '../../lib/rbac'

export function AdminLayout() {
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated)
  const user = useAuthStore((s) => s.user)
  const setUser = useAuthStore((s) => s.setUser)
  const location = useLocation()
  const [mobileNav, setMobileNav] = useState(false)
  const { data: me } = useMe()

  useEffect(() => {
    if (me) {
      setUser({
        ...me,
        admin_role: me.admin_role || (me.role === 'admin' ? 'super_admin' : me.role),
      })
    }
  }, [me, setUser])

  if (!isAuthenticated) {
    return <Navigate to="/login" replace state={{ from: location }} />
  }

  const creatorMode = isCreator(user)
  const ActiveSidebar = creatorMode ? CreatorSidebar : Sidebar

  return (
    <div className="flex h-screen overflow-hidden bg-base">
      <div className="hidden lg:block">
        <ActiveSidebar />
      </div>

      {mobileNav && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <div className="absolute inset-0 bg-black/70" onClick={() => setMobileNav(false)} />
          <div className="absolute left-0 top-0 h-full animate-fade-in">
            <ActiveSidebar onNavigate={() => setMobileNav(false)} />
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
