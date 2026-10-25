import { Navigate } from 'react-router-dom'
import { useAuthStore } from '../../lib/store'
import { isSuperAdmin, isCreator } from '../../lib/rbac'
import toast from 'react-hot-toast'
import { useEffect } from 'react'

export function SuperAdminRoute({ children }) {
  const user = useAuthStore((s) => s.user)
  const isSuper = isSuperAdmin(user)
  const creator = isCreator(user)

  useEffect(() => {
    if (user && !isSuper) {
      toast.error('Restricted section: Super Admin privileges required')
    }
  }, [user, isSuper])

  if (!isSuper) {
    if (creator) {
      return <Navigate to="/creator/dashboard" replace />
    }
    return <Navigate to="/content/series" replace />
  }

  return <>{children}</>
}
