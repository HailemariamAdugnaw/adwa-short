import { Navigate } from 'react-router-dom'
import { useAuthStore } from '../../lib/store'
import { isSuperAdmin } from '../../lib/rbac'
import toast from 'react-hot-toast'
import { useEffect } from 'react'

export function SuperAdminRoute({ children }) {
  const user = useAuthStore((s) => s.user)
  const isSuper = isSuperAdmin(user)

  useEffect(() => {
    if (user && !isSuper) {
      toast.error('Restricted section: Super Admin privileges required')
    }
  }, [user, isSuper])

  if (!isSuper) {
    return <Navigate to="/content/series" replace />
  }

  return <>{children}</>
}
