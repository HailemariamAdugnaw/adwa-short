import { Navigate } from 'react-router-dom'
import { useAuthStore } from '../../lib/store'
import { isCreator, isSuperAdmin } from '../../lib/rbac'
import toast from 'react-hot-toast'
import { useEffect } from 'react'

export function CreatorRoute({ children }) {
  const user = useAuthStore((s) => s.user)
  const creator = isCreator(user)
  const isSuper = isSuperAdmin(user)

  // Allow creator, or allow super_admin previewing creator portal
  const allowed = creator || isSuper

  useEffect(() => {
    if (user && !allowed) {
      toast.error('Restricted section: Creator access required')
    }
  }, [user, allowed])

  if (!user) {
    return <Navigate to="/login" replace />
  }

  if (!allowed) {
    return <Navigate to="/content/series" replace />
  }

  return <>{children}</>
}
